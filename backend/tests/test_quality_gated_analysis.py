import io
import sys
from dataclasses import dataclass
from pathlib import Path

import numpy as np
import pytest
import soundfile as sf

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app import verdict_policy  # noqa: E402
from app.audio_quality import SAMPLE_RATE  # noqa: E402
from app.routers.sessions import _analyze_with_quality  # noqa: E402


@dataclass
class Result:
    ayah_number: int = 1
    word_index: int = 0
    surah_number: int = 1
    recited: bool = True
    correct: bool = False
    error_type: str | None = "madd"
    review_status: str | None = None


class Service:
    def __init__(self, results):
        self.results = results
        self.calls = 0

    def analyze_span(self, *_args):
        result = self.results[min(self.calls, len(self.results) - 1)]
        self.calls += 1
        return result


def _wav(samples):
    buf = io.BytesIO()
    sf.write(buf, samples, SAMPLE_RATE, format="WAV", subtype="PCM_16")
    return buf.getvalue()


def _speech_with_noise(seconds=2):
    rng = np.random.default_rng(4)
    t = np.arange(seconds * SAMPLE_RATE) / SAMPLE_RATE
    speech = 0.025 * np.sin(2 * np.pi * 190 * t) * (0.3 + 0.7 * np.sin(2 * np.pi * 2 * t) ** 2)
    return (speech + rng.normal(0, 0.018, t.size)).astype(np.float32)


def test_unusable_audio_never_reaches_the_recognizer():
    service = Service([[Result()]])
    with pytest.raises(ValueError, match="too quiet"):
        _analyze_with_quality(service, _wav(np.zeros(2 * SAMPLE_RATE)), 1, 1, 1, 1)
    assert service.calls == 0


def test_degraded_audio_runs_two_decodes_and_requires_agreement():
    first = Result(error_type="madd")
    second = Result(correct=True, error_type=None)
    service = Service([[first], [second]])

    results, quality, enhancement = _analyze_with_quality(
        service, _wav(_speech_with_noise()), 1, 1, 1, 1)

    assert quality["status"] == "degraded"
    assert service.calls == 2
    assert enhancement["used"] is True
    assert results[0].review_status == verdict_policy.NEEDS_REVIEW
