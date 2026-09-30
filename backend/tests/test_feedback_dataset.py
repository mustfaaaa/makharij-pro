import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "ml" / "verifier"))

from build_feedback_dataset import rows_from_sessions  # noqa: E402


def test_feedback_is_joined_to_word_and_anonymised():
    sessions = [{
        "session_id": "s1",
        "uid": "real-user-id",
        "surahNumber": 1,
        "analysisVersion": "v1",
        "modelId": "m1",
        "audioQuality": {"status": "degraded", "estimated_snr_db": 6.0},
        "words": [{
            "ayahNumber": 2, "wordIndex": 3, "expected": "aaaa", "predicted": "a",
            "distance": 3, "confidence": 0.25, "errorType": "madd",
            "reviewStatus": "needs_review",
            "durationEvidence": {"expectedCount": 4, "heardCount": 1, "segmentMs": 80},
        }],
        "wordFeedback": [{"ayahNumber": 2, "wordIndex": 3, "agreed": False}],
    }]

    rows = rows_from_sessions(sessions, salt="test")
    assert len(rows) == 1
    row = rows[0]
    assert row["group_id"] != "real-user-id"
    assert row["target_model_flag_correct"] == 0
    assert row["distance_ratio"] == 0.75
    assert row["audio_quality_status"] == "degraded"
    assert row["duration_expected_count"] == 4
    assert row["verified"] is False


def test_snapshot_survives_when_session_word_list_changes():
    snapshot = {
        "ayahNumber": 1, "wordIndex": 0, "expected": "nnn", "predicted": "n",
        "distance": 2, "confidence": 0.4, "errorType": "ghunnah",
    }
    sessions = [{
        "session_id": "s2", "surahNumber": 1, "words": [],
        "wordFeedback": [{
            "ayahNumber": 1, "wordIndex": 0, "agreed": True,
            "verified": True, "source": "teacher_review", "wordSnapshot": snapshot,
        }],
    }]
    row = rows_from_sessions(sessions)[0]
    assert row["target_model_flag_correct"] == 1
    assert row["source"] == "teacher_review"
    assert row["verified"] is True
