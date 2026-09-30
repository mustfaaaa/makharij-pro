"""Train MakharijPro's lightweight real-error verifier.

This model does not replace Quran phoneme recognition.  It learns the narrower
decision the app actually needs: whether a recogniser flag is supported well
enough to count as a confirmed learner error.  Input comes from
``build_feedback_dataset.py``.

Safety defaults:

* teacher-verified labels only;
* group-disjoint validation (a learner never appears on both sides);
* refuses tiny or single-class data instead of exporting a misleading model;
* threshold selected on validation with false-confirmation cost weighted more
  heavily than a missed flag.
"""

from __future__ import annotations

import argparse
import json
import random
from datetime import datetime, timezone
from pathlib import Path

import numpy as np

RULES = ("madd", "ghunnah", "shaddah", "makhraj", "skipped")
QUALITY = ("good", "degraded", "unusable")
NUMERIC = (
    "confidence", "distance_ratio", "length_ratio", "expected_length",
    "estimated_snr_db", "clipping_ratio", "speech_ratio",
    "duration_expected_count", "duration_heard_count",
    "duration_segment_ms", "duration_acoustic_units",
)
FEATURE_NAMES = (
    list(NUMERIC)
    + [f"{name}_available" for name in NUMERIC]
    + [f"rule_{name}" for name in RULES]
    + [f"quality_{name}" for name in QUALITY]
)


def featurise(row: dict) -> list[float]:
    values = []
    available = []
    for name in NUMERIC:
        value = row.get(name)
        available.append(0.0 if value is None else 1.0)
        values.append(float(value) if value is not None else 0.0)
    values += available
    values += [1.0 if row.get("rule") == rule else 0.0 for rule in RULES]
    values += [1.0 if row.get("audio_quality_status") == q else 0.0 for q in QUALITY]
    return values


def group_split(rows: list[dict], *, seed: int = 17, validation_fraction: float = 0.2):
    groups = sorted({str(row["group_id"]) for row in rows})
    rng = random.Random(seed)
    rng.shuffle(groups)
    n_val = max(1, round(len(groups) * validation_fraction))
    val_groups = set(groups[:n_val])
    train = [row for row in rows if str(row["group_id"]) not in val_groups]
    val = [row for row in rows if str(row["group_id"]) in val_groups]
    return train, val


def _fit(X: np.ndarray, y: np.ndarray, *, l2: float = 2.0,
         iterations: int = 5000, learning_rate: float = 0.05) -> np.ndarray:
    xb = np.hstack([X, np.ones((X.shape[0], 1))])
    weights = np.zeros(xb.shape[1], dtype=np.float64)
    for _ in range(iterations):
        scores = np.clip(xb @ weights, -30, 30)
        probabilities = 1.0 / (1.0 + np.exp(-scores))
        gradient = xb.T @ (probabilities - y) / len(y)
        gradient[:-1] += l2 * weights[:-1] / len(y)
        weights -= learning_rate * gradient
    return weights


def _predict(X: np.ndarray, weights: np.ndarray) -> np.ndarray:
    xb = np.hstack([X, np.ones((X.shape[0], 1))])
    return 1.0 / (1.0 + np.exp(-np.clip(xb @ weights, -30, 30)))


def _rates(y: np.ndarray, scores: np.ndarray, threshold: float) -> dict:
    predicted = scores >= threshold
    negatives = y == 0  # learner/teacher says the app's flag was false
    positives = y == 1  # reviewer agrees the flag was a real error
    false_confirm = float(np.mean(predicted[negatives])) if negatives.any() else 0.0
    recall = float(np.mean(predicted[positives])) if positives.any() else 0.0
    balanced = ((1.0 - false_confirm) + recall) / 2.0
    return {
        "false_confirmation_rate": round(false_confirm, 4),
        "real_error_recall": round(recall, 4),
        "balanced_accuracy": round(balanced, 4),
    }


def train(rows: list[dict], *, seed: int = 17, min_rows: int = 200,
          min_groups: int = 20) -> dict:
    if len(rows) < min_rows:
        raise ValueError(f"Need at least {min_rows} verified word labels; found {len(rows)}")
    groups = {str(row.get("group_id")) for row in rows}
    if len(groups) < min_groups:
        raise ValueError(f"Need at least {min_groups} learner groups; found {len(groups)}")
    labels = {int(row["target_model_flag_correct"]) for row in rows}
    if labels != {0, 1}:
        raise ValueError("Training labels must contain both false and confirmed flags")

    train_rows, val_rows = group_split(rows, seed=seed)
    if not train_rows or not val_rows:
        raise ValueError("Group-disjoint split produced an empty partition")
    if {int(r["target_model_flag_correct"]) for r in train_rows} != {0, 1}:
        raise ValueError("Training partition does not contain both classes")
    if {int(r["target_model_flag_correct"]) for r in val_rows} != {0, 1}:
        raise ValueError("Validation partition does not contain both classes")

    X_train = np.asarray([featurise(row) for row in train_rows], dtype=np.float64)
    y_train = np.asarray([row["target_model_flag_correct"] for row in train_rows], dtype=np.float64)
    X_val = np.asarray([featurise(row) for row in val_rows], dtype=np.float64)
    y_val = np.asarray([row["target_model_flag_correct"] for row in val_rows], dtype=np.float64)

    mean = X_train.mean(axis=0)
    scale = X_train.std(axis=0)
    scale[scale == 0] = 1.0
    weights = _fit((X_train - mean) / scale, y_train)
    scores = _predict((X_val - mean) / scale, weights)

    # False confirmation is twice as costly: a wrong correction damages trust
    # and can teach the learner to change a pronunciation that was already OK.
    candidates = []
    for threshold in np.arange(0.20, 0.91, 0.02):
        metrics = _rates(y_val, scores, float(threshold))
        utility = metrics["real_error_recall"] - 2.0 * metrics["false_confirmation_rate"]
        candidates.append((utility, metrics["balanced_accuracy"], float(threshold), metrics))
    _utility, _balanced, threshold, metrics = max(candidates)

    train_groups = {row["group_id"] for row in train_rows}
    val_groups = {row["group_id"] for row in val_rows}
    assert train_groups.isdisjoint(val_groups)
    return {
        "schema_version": 1,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "model_type": "regularized_logistic_flag_verifier",
        "target": "probability that a detector flag is a real learner error",
        "feature_names": FEATURE_NAMES,
        "mean": mean.tolist(),
        "scale": scale.tolist(),
        "weights": weights[:-1].tolist(),
        "bias": float(weights[-1]),
        "threshold": round(threshold, 4),
        "validation": metrics,
        "training_rows": len(train_rows),
        "validation_rows": len(val_rows),
        "training_groups": len(train_groups),
        "validation_groups": len(val_groups),
        "split_seed": seed,
        "label_policy": "teacher_verified_only",
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("dataset", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--include-self-reports", action="store_true",
                        help="Allow unverified learner feedback (exploratory only)")
    parser.add_argument("--min-rows", type=int, default=200)
    parser.add_argument("--min-groups", type=int, default=20)
    args = parser.parse_args()

    rows = [json.loads(line) for line in args.dataset.read_text(encoding="utf-8").splitlines() if line.strip()]
    if not args.include_self_reports:
        rows = [row for row in rows if row.get("verified")]
    artifact = train(rows, min_rows=args.min_rows, min_groups=args.min_groups)
    if args.include_self_reports:
        artifact["label_policy"] = "includes_unverified_self_reports_exploratory_only"
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(artifact, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"wrote verifier artifact to {args.output}")
    print(json.dumps(artifact["validation"], indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
