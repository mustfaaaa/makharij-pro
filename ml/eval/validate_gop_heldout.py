"""Does the GOP suppression rule survive a speaker it was not fitted to?

Why this exists
---------------
measure_confidence_separation.py chose the GOP threshold on the same 773 clips
it then reported against. That is marking your own exam paper, and this project
already has direct evidence of the trap: ml/eval/README.md records that
threshold calibration was fitted properly against this same corpus once before
and did *not* improve on the shipped setting.

So the number "false alarms 53.5% -> 32.0%" is not yet a finding. It is a
hypothesis about a rule, measured where the rule was born.

The split is by *reciter*, never by clip
----------------------------------------
Every real user of the app is a voice the threshold has never heard. If the same
reciter appears on both sides, the threshold can fit that person's voice, mic
and room and still look excellent, while telling us nothing about the case we
actually care about. Splitting on reciter_id is the closest this corpus gets to
"what happens when a stranger recites".

What it reports
---------------
Fit half: pick the threshold. Held-out half: report what that threshold does,
against the baseline (no rule) measured on the same held-out clips. Repeated
over several random speaker splits, because a single split of 88 reciters is
itself a small sample and one lucky partition proves nothing.

Run from the repo root:
    backend/.venv/Scripts/python.exe ml/eval/validate_gop_heldout.py
"""
from __future__ import annotations

import argparse
import json
import random
import statistics
from pathlib import Path

RECORDS = Path(__file__).resolve().parent / "results" / "confidence_records.jsonl"
OUT = Path(__file__).resolve().parent / "results" / "gop_heldout_validation.json"

# The same grid the in-sample sweep used, so the comparison is like for like.
THRESHOLDS = [0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]


def rates(clips: list[dict], threshold: float | None) -> tuple[float, float]:
    """(false alarm %, real mistakes caught %) for one set of clips.

    `threshold` None means the current behaviour: every flag stands. Otherwise a
    flag survives only when the expected phonemes are NOT well supported by the
    audio, i.e. its GOP is at or below the bar.
    """
    correct = [c for c in clips if c["recited_correctly"] == 1]
    incorrect = [c for c in clips if c["recited_correctly"] == 0]

    def flagged(clip) -> bool:
        if threshold is None:
            return bool(clip["flagged_gop"]) or clip["flagged"]
        return any(g <= threshold for g in clip["flagged_gop"])

    fa = 100 * sum(1 for c in correct if flagged(c)) / max(len(correct), 1)
    td = 100 * sum(1 for c in incorrect if flagged(c)) / max(len(incorrect), 1)
    return fa, td


def pick_threshold(fit: list[dict]) -> tuple[float, float]:
    """Choose the bar on the fit half only.

    Criterion: maximise (false alarms removed) - (real mistakes lost), both in
    percentage points. That weighs the two equally, which is deliberately
    conservative -- for a Quran app a false accusation plausibly costs more than
    a missed mistake, so a rule that wins even under equal weighting is winning
    on its own merits rather than on a favourable choice of loss.
    """
    base_fa, base_td = rates(fit, None)
    best, best_gain = None, float("-inf")
    for th in THRESHOLDS:
        fa, td = rates(fit, th)
        gain = (base_fa - fa) - (base_td - td)
        if gain > best_gain:
            best, best_gain = th, gain
    return best, best_gain


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--records", type=Path, default=RECORDS)
    parser.add_argument("--splits", type=int, default=8)
    parser.add_argument("--out", type=Path, default=OUT)
    args = parser.parse_args()

    if not args.records.exists():
        print(f"No records at {args.records} -- run measure_confidence_separation.py first")
        return 1

    clips = [json.loads(line) for line in
             args.records.read_text(encoding="utf-8").splitlines() if line.strip()]
    # Only clips the pipeline actually flagged can be affected by a suppression
    # rule; the rest are untouched either way and would only dilute the rates.
    reciters = sorted({c.get("reciter_id", "") for c in clips})
    print(f"{len(clips)} clips, {len(reciters)} reciters")

    runs = []
    for seed in range(args.splits):
        rng = random.Random(seed)
        shuffled = reciters[:]
        rng.shuffle(shuffled)
        half = set(shuffled[: len(shuffled) // 2])

        fit = [c for c in clips if c.get("reciter_id", "") in half]
        held = [c for c in clips if c.get("reciter_id", "") not in half]
        if not fit or not held:
            continue

        th, _ = pick_threshold(fit)
        fit_fa, fit_td = rates(fit, th)
        base_fa, base_td = rates(held, None)
        out_fa, out_td = rates(held, th)

        runs.append({
            "seed": seed,
            "chosen_threshold": th,
            "fit_clips": len(fit),
            "heldout_clips": len(held),
            "fit": {"false_alarm_pct": round(fit_fa, 1), "caught_pct": round(fit_td, 1)},
            "heldout_baseline": {"false_alarm_pct": round(base_fa, 1),
                                 "caught_pct": round(base_td, 1)},
            "heldout_with_rule": {"false_alarm_pct": round(out_fa, 1),
                                  "caught_pct": round(out_td, 1)},
            "heldout_fa_reduction_pts": round(base_fa - out_fa, 1),
            "heldout_recall_loss_pts": round(base_td - out_td, 1),
            "heldout_net_gain_pts": round((base_fa - out_fa) - (base_td - out_td), 1),
        })

    med = lambda key: round(statistics.median(r[key] for r in runs), 1)  # noqa: E731

    summary = {
        "what": "does the GOP suppression rule hold on reciters it was not fitted to",
        "split": "speaker-disjoint (by reciter_id), half fit / half held out",
        "splits_run": len(runs),
        "thresholds_chosen": sorted({r["chosen_threshold"] for r in runs}),
        "median_heldout_fa_reduction_pts": med("heldout_fa_reduction_pts"),
        "median_heldout_recall_loss_pts": med("heldout_recall_loss_pts"),
        "median_heldout_net_gain_pts": med("heldout_net_gain_pts"),
        "runs": runs,
        "how_to_read": "net gain > 0 means the rule removes more false alarms "
                       "than the real mistakes it costs, on speakers it never saw. "
                       "A gain that appears on the fit half but not held out is "
                       "the rule having memorised those voices.",
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")

    print()
    print("=" * 74)
    print("GOP RULE ON UNSEEN RECITERS (speaker-disjoint held-out)")
    print("=" * 74)
    print(f"  {'seed':>4} {'thr':>5} | {'FIT':>15} | {'HELD-OUT base':>15} "
          f"| {'HELD-OUT rule':>15} | {'net':>5}")
    for r in runs:
        f, b, o = r["fit"], r["heldout_baseline"], r["heldout_with_rule"]
        print(f"  {r['seed']:>4} {r['chosen_threshold']:>5} | "
              f"{f['false_alarm_pct']:>6}% {f['caught_pct']:>7}% | "
              f"{b['false_alarm_pct']:>6}% {b['caught_pct']:>7}% | "
              f"{o['false_alarm_pct']:>6}% {o['caught_pct']:>7}% | "
              f"{r['heldout_net_gain_pts']:>5}")
    print()
    print(f"  median held-out false alarms removed : {med('heldout_fa_reduction_pts')} pts")
    print(f"  median held-out real mistakes lost   : {med('heldout_recall_loss_pts')} pts")
    print(f"  median NET                           : {med('heldout_net_gain_pts')} pts")
    print()
    net = med("heldout_net_gain_pts")
    print("  VERDICT:", "the rule holds on unseen reciters" if net > 0
          else "the rule does NOT survive unseen reciters -- do not ship it")
    print(f"\n  written to {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
