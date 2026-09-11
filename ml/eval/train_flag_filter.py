"""Learn which flags to keep, instead of thresholding a single number.

The rule this replaces
----------------------
GOP alone, at a hand-picked bar, removes ~22 points of false alarms for ~14
points of real-mistake detection on reciters it never saw
(ml/eval/results/gop_heldout_validation.json). That is one scalar carrying the
whole decision. At each flagged word the model also knows how sure it was, how
far ahead of its runner-up, how long the word ran, how far the decode drifted,
and which rule was claimed. This fits a small model over all of it.

Deliberately logistic regression, not a forest
----------------------------------------------
A few hundred flagged words, of which only one class is cleanly labelled, is
not enough to feed a gradient-boosted ensemble without it memorising reciters.
Logistic regression on standardised features is the right capacity here, and it
stays inspectable -- the coefficients say which evidence actually mattered,
which is worth more than a point of accuracy from a model nobody can read.

Evaluation is the same speaker-disjoint test the GOP rule had to pass
--------------------------------------------------------------------
Every real user is an unseen voice, so the split is by reciter and the model
never trains on a reciter it is scored against. Results are reported at *clip*
level -- a clip counts as flagged if any of its words survives the filter --
because that is where the corpus labels actually live, and it makes the numbers
directly comparable to the GOP baseline.

Run from the repo root:
    backend/.venv/Scripts/python.exe ml/eval/train_flag_filter.py
"""
from __future__ import annotations

import argparse
import csv
import json
import random
import statistics
from pathlib import Path

import numpy as np

FEATURES = Path(__file__).resolve().parent / "results" / "word_features.jsonl"
MANIFEST = (Path(__file__).resolve().parents[2] / "ml" / "data" /
            "quranic_audio_dataset" / "evalset" / "manifest.csv")
OUT = Path(__file__).resolve().parent / "results" / "flag_filter_validation.json"

RULES = ("madd", "ghunnah", "shaddah", "makhraj", "skipped")

# The GOP bar this has to beat, chosen and validated in validate_gop_heldout.py.
GOP_BASELINE_THRESHOLD = 0.5


def featurise(row: dict) -> list[float]:
    """One flagged word as a feature vector.

    Missing GOP/CTC values become a neutral 0 with a companion "was it
    available" flag, so the model can tell "no evidence could be computed" from
    "the evidence came out at zero" instead of silently confusing the two.
    """
    gop = row.get("gop")
    ctc = row.get("ctc_gop")
    vec = [
        gop if gop is not None else 0.0,
        1.0 if gop is not None else 0.0,
        ctc if ctc is not None else 0.0,
        1.0 if ctc is not None else 0.0,
        row["conf"],
        row["margin"],
        row["distance_ratio"],
        row["len_ratio"],
        float(row["n_expected"]),
        float(row["edit_distance"]),
        row["duration_sec"],
        float(row["frames"]),
    ]
    vec += [1.0 if row.get("error_type") == r else 0.0 for r in RULES]
    return vec


def fit_logistic(X: np.ndarray, y: np.ndarray, l2: float = 1.0,
                 iters: int = 4000, lr: float = 0.1) -> np.ndarray:
    """Plain gradient descent on the regularised log-loss. Returns weights with
    the bias as the final element."""
    Xb = np.hstack([X, np.ones((X.shape[0], 1))])
    w = np.zeros(Xb.shape[1])
    n = max(len(y), 1)
    for _ in range(iters):
        z = np.clip(Xb @ w, -30, 30)
        p = 1.0 / (1.0 + np.exp(-z))
        grad = Xb.T @ (p - y) / n
        grad[:-1] += l2 * w[:-1] / n      # bias is not regularised
        w -= lr * grad
    return w


def predict(X: np.ndarray, w: np.ndarray) -> np.ndarray:
    z = np.clip(np.hstack([X, np.ones((X.shape[0], 1))]) @ w, -30, 30)
    return 1.0 / (1.0 + np.exp(-z))


def clip_rates(rows: list[dict], keep: list[bool],
               universe: dict[str, int]) -> tuple[float, float]:
    """(false alarm %, real mistakes caught %) at clip level.

    A clip is flagged if ANY of its words survives the filter -- exactly how the
    app behaves, since one surviving flag is one accusation on screen.

    `universe` is EVERY clip in the corpus with its label, not just the clips
    that happened to be flagged. That distinction is the whole measurement: 53.5%
    of correctly-recited clips are flagged but 72.9% of incorrect ones are, so
    scoring only within flagged clips silently uses two different denominators
    and inflates whatever the filter does. Clips with no flags at all are
    unflagged under every rule and belong in the denominator unchanged.
    """
    flagged: dict[str, bool] = {}
    for row, k in zip(rows, keep):
        flagged[row["clip_id"]] = flagged.get(row["clip_id"], False) or k

    correct = [cid for cid, lab in universe.items() if lab == 1]
    wrong = [cid for cid, lab in universe.items() if lab == 0]
    fa = 100 * sum(1 for c in correct if flagged.get(c, False)) / max(len(correct), 1)
    td = 100 * sum(1 for c in wrong if flagged.get(c, False)) / max(len(wrong), 1)
    return fa, td


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--features", type=Path, default=FEATURES)
    parser.add_argument("--splits", type=int, default=20)
    parser.add_argument("--out", type=Path, default=OUT)
    args = parser.parse_args()

    if not args.features.exists():
        print(f"No features at {args.features} -- run extract_word_features.py first")
        return 1

    rows = [json.loads(line) for line in
            args.features.read_text(encoding="utf-8").splitlines() if line.strip()]

    # Every clip in the corpus, with its label and reciter -- including the ones
    # that were never flagged, which still count in the denominator.
    with open(MANIFEST, encoding="utf-8") as f:
        manifest = {m["clip_id"]: (int(m["recited_correctly"]), m["reciter_id"])
                    for m in csv.DictReader(f)}
    reciters = sorted({rid for _, rid in manifest.values()})
    X_all = np.array([featurise(r) for r in rows], dtype=float)
    # Target: 1 = keep this flag (the clip really does contain a mistake),
    # 0 = suppress it (the clip was recited correctly, so this is a false alarm).
    y_all = np.array([0.0 if r["clip_correct"] == 1 else 1.0 for r in rows])

    print(f"{len(rows)} flagged words, {len(reciters)} reciters, "
          f"{int((y_all == 0).sum())} clean false alarms")

    runs = []
    for seed in range(args.splits):
        rng = random.Random(seed)
        shuffled = reciters[:]
        rng.shuffle(shuffled)
        train_ids = set(shuffled[: len(shuffled) // 2])

        tr = [i for i, r in enumerate(rows) if r["reciter_id"] in train_ids]
        te = [i for i, r in enumerate(rows) if r["reciter_id"] not in train_ids]
        if not tr or not te:
            continue
        uni_tr = {cid: lab for cid, (lab, rid) in manifest.items() if rid in train_ids}
        uni_te = {cid: lab for cid, (lab, rid) in manifest.items() if rid not in train_ids}

        mu, sd = X_all[tr].mean(axis=0), X_all[tr].std(axis=0)
        sd[sd == 0] = 1.0
        w = fit_logistic((X_all[tr] - mu) / sd, y_all[tr])
        scores = predict((X_all[te] - mu) / sd, w)

        test_rows = [rows[i] for i in te]
        base_fa, base_td = clip_rates(test_rows, [True] * len(te), uni_te)
        gop_keep = [
            (r["gop"] is None) or (r["gop"] <= GOP_BASELINE_THRESHOLD) for r in test_rows]
        gop_fa, gop_td = clip_rates(test_rows, gop_keep, uni_te)

        # Operating point picked on the TRAINING half only, never the test half.
        tr_scores = predict((X_all[tr] - mu) / sd, w)
        train_rows = [rows[i] for i in tr]
        best_cut, best_gain = 0.5, float("-inf")
        tb_fa, tb_td = clip_rates(train_rows, [True] * len(tr), uni_tr)
        for cut in np.arange(0.05, 0.96, 0.05):
            f, t = clip_rates(train_rows, list(tr_scores >= cut), uni_tr)
            gain = (tb_fa - f) - (tb_td - t)
            if gain > best_gain:
                best_cut, best_gain = float(cut), gain

        mdl_fa, mdl_td = clip_rates(test_rows, list(scores >= best_cut), uni_te)
        runs.append({
            "seed": seed,
            "cut": round(best_cut, 2),
            "baseline": {"fa": round(base_fa, 1), "caught": round(base_td, 1)},
            "gop": {"fa": round(gop_fa, 1), "caught": round(gop_td, 1),
                    "net": round((base_fa - gop_fa) - (base_td - gop_td), 1)},
            "model": {"fa": round(mdl_fa, 1), "caught": round(mdl_td, 1),
                      "net": round((base_fa - mdl_fa) - (base_td - mdl_td), 1)},
        })

    med = lambda path: round(statistics.median(  # noqa: E731
        r[path[0]][path[1]] for r in runs), 1)

    summary = {
        "what": "a learned filter over flagged words vs the single-feature GOP bar",
        "split": "speaker-disjoint by reciter_id, half train / half held out",
        "splits": len(runs),
        "flagged_words": len(rows),
        "median_baseline": {"fa": med(("baseline", "fa")), "caught": med(("baseline", "caught"))},
        "median_gop": {"fa": med(("gop", "fa")), "caught": med(("gop", "caught")),
                       "net": med(("gop", "net"))},
        "median_model": {"fa": med(("model", "fa")), "caught": med(("model", "caught")),
                         "net": med(("model", "net"))},
        "model_net_worst_split": min(r["model"]["net"] for r in runs),
        "gop_net_worst_split": min(r["gop"]["net"] for r in runs),
        "runs": runs,
        "label_caveat": "negatives (false alarms) are clean; positives are clip-level "
                        "and so contaminated by false alarms sitting beside a real "
                        "mistake. This caps how good any model fitted here can look.",
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")

    print()
    print("=" * 70)
    print("LEARNED FLAG FILTER vs GOP, on reciters never trained on")
    print("=" * 70)
    print(f"  {'':22} {'false alarm':>12} {'caught':>9} {'net':>7}")
    print(f"  {'now (every flag)':22} {med(('baseline','fa')):>11}% "
          f"{med(('baseline','caught')):>8}% {'--':>7}")
    print(f"  {'GOP bar @0.5':22} {med(('gop','fa')):>11}% "
          f"{med(('gop','caught')):>8}% {med(('gop','net')):>+7}")
    print(f"  {'learned filter':22} {med(('model','fa')):>11}% "
          f"{med(('model','caught')):>8}% {med(('model','net')):>+7}")
    print()
    print(f"  worst split  GOP {summary['gop_net_worst_split']:+.1f}   "
          f"model {summary['model_net_worst_split']:+.1f}")
    better = sum(1 for r in runs if r["model"]["net"] > r["gop"]["net"])
    print(f"  model beats GOP on {better}/{len(runs)} splits")
    print(f"\n  written to {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
