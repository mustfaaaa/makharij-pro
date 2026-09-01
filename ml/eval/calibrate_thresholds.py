"""Fits the detector's decision thresholds to real learner recordings.

The tolerances in backend/app/tajweed_diff.py were chosen by watching what the
recognizer does to *professional Qari* audio -- the only recordings available at
the time. They were never fitted to the people the app is actually for, and
run_evaluation.py shows the cost: a false-positive rate an order of magnitude
worse on learner voices than on Qaris.

This does not retrain anything. The recogniser stays exactly as it is; what
gets fitted is where the line sits between "the recogniser heard something
different" and "the reciter made a mistake" -- which is a decision threshold,
and the one part of this system that labelled data can honestly set.

Method:
  - re-scores the cached per-word phonemes from run_evaluation.py, so the
    recogniser never runs again and every candidate sees identical inputs;
  - fits on clips whose reciter is known, split by *speaker*, so no reciter
    appears in both the fitting and validation halves;
  - reports the chosen setting on a held-out pool that took no part in fitting.

Selection rule, fixed before looking at results: maximise detection subject to
a clip-level false-positive rate at or below FP_BUDGET. Cheaper to miss a
mistake than to invent one -- an invented mistake costs the user's trust in
every other verdict on the screen.

    python ml/eval/calibrate_thresholds.py
"""
import argparse
import json
import random
import sys
from collections import defaultdict
from itertools import product
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT / "backend"))

from app import tajweed_diff  # noqa: E402

RESULTS = ROOT / "ml" / "eval" / "results"

# Share of correctly-recited clips allowed to be wrongly flagged. Inherited
# from the Track A calibration's own 10% target (ml/README.md, Phase 13) so the
# two rounds of threshold work are judged by the same bar.
FP_BUDGET = 0.10

# Every combination is scored; the grid is small because each knob has a
# meaning and a plausible range, not because the search is cheap.
GRID = {
    "MADD_COUNT_TOLERANCE": [2, 3, 4],
    "GHUNNAH_COUNT_TOLERANCE": [2, 3, 4],
    "MAKHRAJ_MIN_FINDINGS": [1, 2, 3],
    "MADD_DROPPED_MAX": [0, 1],
}

SPLIT_SEED = 42
FIT_SPEAKER_SHARE = 0.7


def load(path: Path):
    with open(path, encoding="utf-8") as f:
        return [json.loads(line) for line in f if line.strip()]


def apply_settings(settings: dict):
    for name, value in settings.items():
        setattr(tajweed_diff, name, value)


def clip_flagged(record) -> bool:
    """Re-decide, under the currently applied settings, whether this recitation
    would be accused of anything."""
    for word in record["words"]:
        if not word["recited"]:
            continue
        findings = tajweed_diff.classify(word["display"], word["expected"], word["predicted"])
        if tajweed_diff.summarize(word["display"], findings) is not None:
            return True
    return False


def score(records) -> dict:
    correct = [r for r in records if r["recited_correctly"] == 1]
    incorrect = [r for r in records if r["recited_correctly"] == 0]
    fp = sum(clip_flagged(r) for r in correct)
    tp = sum(clip_flagged(r) for r in incorrect)

    fp_rate = fp / len(correct) if correct else 0.0
    detection = tp / len(incorrect) if incorrect else 0.0
    return {
        "false_positive_rate": fp_rate,
        "detection_rate": detection,
        "balanced_accuracy": ((1 - fp_rate) + detection) / 2,
        "n_correct": len(correct),
        "n_incorrect": len(incorrect),
    }


def speaker_split(records):
    """Fit/validation halves that share no reciter.

    Only clips with a known reciter can be grouped. Clips whose reciter is
    'Unknown' are held out wholesale instead: they cannot be proven disjoint
    from anyone, so they are never fitted on, and they make a second, larger
    check on a different slice of the corpus.
    """
    known = [r for r in records if r["reciter_id"] != "Unknown"]
    unknown = [r for r in records if r["reciter_id"] == "Unknown"]

    speakers = sorted({r["reciter_id"] for r in known})
    random.Random(SPLIT_SEED).shuffle(speakers)
    cut = int(len(speakers) * FIT_SPEAKER_SHARE)
    fit_speakers = set(speakers[:cut])

    fit = [r for r in known if r["reciter_id"] in fit_speakers]
    validation = [r for r in known if r["reciter_id"] not in fit_speakers]
    assert not ({r["reciter_id"] for r in fit} & {r["reciter_id"] for r in validation})
    return fit, validation, unknown


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--detail", type=Path, default=RESULTS / "word_level.jsonl")
    parser.add_argument("--out", type=Path, default=RESULTS / "calibration.json")
    args = parser.parse_args()

    if not args.detail.exists():
        print(f"No cached analysis at {args.detail} -- run ml/eval/run_evaluation.py first")
        return 1

    records = [r for r in load(args.detail) if r.get("words")]
    fit, validation, held_out = speaker_split(records)
    print(f"clips: {len(records)}")
    print(f"  fit        : {len(fit):4}  ({len({r['reciter_id'] for r in fit})} reciters)")
    print(f"  validation : {len(validation):4}  "
          f"({len({r['reciter_id'] for r in validation})} reciters, none shared)")
    print(f"  held out   : {len(held_out):4}  (reciter unknown, never fitted on)")

    baseline_settings = {k: getattr(tajweed_diff, k) for k in GRID}
    apply_settings(baseline_settings)
    baseline = {name: score(part) for name, part in
                (("fit", fit), ("validation", validation), ("held_out", held_out))}

    print(f"\nsearching {len(list(product(*GRID.values())))} settings on the fit split...")
    candidates = []
    for values in product(*GRID.values()):
        settings = dict(zip(GRID, values))
        apply_settings(settings)
        candidates.append((settings, score(fit)))

    within_budget = [c for c in candidates if c[1]["false_positive_rate"] <= FP_BUDGET]
    if within_budget:
        chosen, _ = max(within_budget, key=lambda c: c[1]["detection_rate"])
        rule = f"best detection with false positives <= {FP_BUDGET:.0%}"
    else:
        # The budget was set in advance and is reported as missed rather than
        # quietly relaxed. Falling back to "lowest false-positive rate" would
        # ignore detection entirely and pick the most timid setting on the
        # grid -- measured, that halved false positives and halved detection
        # with it, for *worse* balanced accuracy than doing nothing. So the
        # fallback optimises the balance instead.
        chosen, _ = max(candidates, key=lambda c: c[1]["balanced_accuracy"])
        rule = (f"no setting reached the {FP_BUDGET:.0%} false-positive budget; "
                f"fell back to best balanced accuracy on the fit split")

    apply_settings(chosen)
    final = {name: score(part) for name, part in
             (("fit", fit), ("validation", validation), ("held_out", held_out))}

    def line(tag, before, after):
        print(f"  {tag:11}  false positives {before['false_positive_rate']:6.1%} -> "
              f"{after['false_positive_rate']:6.1%}   "
              f"detection {before['detection_rate']:6.1%} -> {after['detection_rate']:6.1%}   "
              f"balanced {before['balanced_accuracy']:6.1%} -> {after['balanced_accuracy']:6.1%}")

    print(f"\nselection rule: {rule}")
    print(f"chosen: {chosen}")
    print(f"was   : {baseline_settings}")
    print("\n--- before -> after ---")
    for part in ("fit", "validation", "held_out"):
        line(part, baseline[part], final[part])

    print("\nThe validation and held-out columns are the ones that count: the fit "
          "split chose these numbers, so its own improvement is not evidence.")

    improved = (
        final["validation"]["balanced_accuracy"] > baseline["validation"]["balanced_accuracy"]
        and final["held_out"]["balanced_accuracy"] > baseline["held_out"]["balanced_accuracy"]
    )
    print("\nVERDICT: " + (
        "the fitted setting beats the shipped one on both unseen splits -- adopt it."
        if improved else
        "no setting on this grid beats the shipped one on both unseen splits.\n"
        "         Threshold placement is not the limit here -- see ml/eval/README.md."))

    # The whole trade-off, so the decision isn't taken on a single number.
    print("\n--- what the grid can buy (fit split, Pareto front) ---")
    front = []
    for settings, m in sorted(candidates, key=lambda c: c[1]["false_positive_rate"]):
        if not front or m["detection_rate"] > front[-1][1]["detection_rate"]:
            front.append((settings, m))
    for settings, m in front:
        knobs = " ".join(f"{k.split('_')[0].lower()}={v}" for k, v in settings.items())
        print(f"  fp {m['false_positive_rate']:5.1%}   detection {m['detection_rate']:5.1%}   "
              f"balanced {m['balanced_accuracy']:5.1%}   {knobs}")

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps({
        "selection_rule": rule,
        "fp_budget": FP_BUDGET,
        "grid": GRID,
        "split": {"seed": SPLIT_SEED, "fit_speaker_share": FIT_SPEAKER_SHARE,
                  "fit": len(fit), "validation": len(validation), "held_out": len(held_out)},
        "baseline_settings": baseline_settings,
        "baseline_scores": baseline,
        "chosen_settings": chosen,
        "chosen_scores": final,
        "all_candidates": [{"settings": s, "fit": m} for s, m in candidates],
    }, indent=2), encoding="utf-8")
    print(f"\nwritten to {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
