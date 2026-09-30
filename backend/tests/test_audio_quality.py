import io
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.audio_quality import (  # noqa: E402
    SAMPLE_RATE,
    StreamingQualityTracker,
    assess,
    assess_audio,
    enhance,
)


def _tone(seconds=2.0, amplitude=0.12, frequency=220.0):
    t = np.arange(int(seconds * SAMPLE_RATE)) / SAMPLE_RATE
    # Modulation gives the energy estimator speech-like quiet/loud frames.
    envelope = 0.35 + 0.65 * (np.sin(2 * np.pi * 2.3 * t) ** 2)
    return (amplitude * envelope * np.sin(2 * np.pi * frequency * t)).astype(np.float32)


def _wav(samples):
    buf = io.BytesIO()
    sf.write(buf, samples, SAMPLE_RATE, format="WAV", subtype="PCM_16")
    return buf.getvalue()


def test_silence_is_rejected_instead_of_becoming_pronunciation_feedback():
    report = assess(np.zeros(2 * SAMPLE_RATE, dtype=np.float32))
    assert report.status == "unusable"
    assert "no_audible_speech" in report.reasons


def test_severe_clipping_is_rejected():
    samples = np.ones(2 * SAMPLE_RATE, dtype=np.float32)
    samples[::2] = -1
    report = assess(samples)
    assert report.status == "unusable"
    assert "severe_clipping" in report.reasons


def test_ordinary_speech_like_audio_is_usable():
    report = assess(_tone())
    assert report.usable
    assert report.peak_dbfs < 0
    assert report.duration_sec == 2.0


def test_wav_decode_and_report_are_serializable():
    _samples, report = assess_audio(_wav(_tone()))
    data = report.to_dict()
    assert data["status"] in {"good", "degraded"}
    assert isinstance(data["reasons"], list)
    assert data["version"]


def test_enhancement_removes_dc_and_keeps_length_and_finite_samples():
    samples = _tone() + 0.08
    cleaned = enhance(samples)
    assert cleaned.shape == samples.shape
    assert np.all(np.isfinite(cleaned))
    assert abs(float(np.mean(cleaned))) < abs(float(np.mean(samples))) * 0.1


def test_streaming_tracker_matches_the_same_audio_as_one_piece():
    samples = _tone()
    tracker = StreamingQualityTracker()
    for start in range(0, samples.size, 731):
        tracker.add(samples[start:start + 731])
    streamed = tracker.report()
    whole = assess(samples)
    assert streamed.status == whole.status
    assert abs(streamed.rms_dbfs - whole.rms_dbfs) < 0.01
