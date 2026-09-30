import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "ml" / "verifier"))

from train_verifier import FEATURE_NAMES, featurise, group_split, train  # noqa: E402


def _row(group, label, i=0):
    return {
        "group_id": group,
        "target_model_flag_correct": label,
        "rule": "madd" if i % 2 else "makhraj",
        "audio_quality_status": "good",
        "confidence": 0.8 if label else 0.3,
        "distance_ratio": 0.1 if label else 0.5,
        "length_ratio": 1.0,
        "expected_length": 8,
    }


def test_feature_contract_has_a_stable_name_for_every_value():
    assert len(featurise(_row("a", 1))) == len(FEATURE_NAMES)


def test_group_split_never_leaks_a_learner():
    rows = [_row(f"g{i}", j % 2, j) for i in range(10) for j in range(4)]
    training, validation = group_split(rows)
    assert {r["group_id"] for r in training}.isdisjoint({r["group_id"] for r in validation})


def test_trainer_refuses_a_tiny_dataset():
    with pytest.raises(ValueError, match="verified word labels"):
        train([_row("a", 0), _row("b", 1)])
