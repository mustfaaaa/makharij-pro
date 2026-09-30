import sys
from dataclasses import dataclass
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.analysis_metadata import ANALYSIS_VERSION, PHONEME_MODEL_ID  # noqa: E402
from app.routers.sessions import record_session  # noqa: E402
from app import firestore_service  # noqa: E402


@dataclass
class Result:
    ayah_number: int = 1
    word_index: int = 0
    display_word: str = "word"
    predicted_phonemes: str = "a"
    expected_phonemes: str = "a"
    start_sec: float = 0.0
    end_sec: float = 0.2
    correct: bool = True
    recited: bool = True
    edit_distance: int = 0
    confidence: float = 1.0
    error_type: str | None = None
    explanation: str | None = None
    surah_number: int = 1
    review_status: str | None = None
    duration_evidence: dict | None = None
    evidence_count: int = 0


def test_session_and_response_identify_the_whole_analysis_pipeline():
    captured = {}

    def save(**kwargs):
        captured.update(kwargs)
        return "session-1"

    quality = {"status": "good", "version": "q1"}
    with patch.object(firestore_service, "save_session", side_effect=save):
        response = record_session(
            "uid", [Result()], surah_number=1, from_ayah=1, qari_id="qari",
            audio_quality=quality, enhancement={"used": False},
        )

    assert captured["model_id"] == PHONEME_MODEL_ID
    assert captured["analysis_version"] == ANALYSIS_VERSION
    assert captured["audio_quality"] == quality
    assert response["model_id"] == PHONEME_MODEL_ID
    assert response["analysis_version"] == ANALYSIS_VERSION
    assert response["audio_quality"] == quality
