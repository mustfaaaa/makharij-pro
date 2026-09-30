"""Conservative recording-quality checks and optional speech enhancement.

This module deliberately does not claim to repair overlapping speech or a
clipped microphone.  It separates three cases instead:

* ``good``: analyse the original recording once;
* ``degraded``: keep the original as authoritative, but run an enhanced copy
  as a second opinion before confirming a flag;
* ``unusable``: do not turn broken evidence into pronunciation feedback.

The thresholds are intentionally cautious.  Only near-silence and severe
clipping are hard failures; estimated SNR is used for the second-pass path,
not to reject a learner.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass
import io
import math

import librosa
import numpy as np
import soundfile as sf
from scipy.signal import butter, sosfiltfilt

from .analysis_metadata import AUDIO_QUALITY_VERSION, ENHANCEMENT_VERSION

SAMPLE_RATE = 16_000
FRAME_MS = 20


class UnusableAudioError(ValueError):
    """The file decoded, but does not contain reliable pronunciation evidence."""


def _db(value: float, floor: float = -100.0) -> float:
    if value <= 1e-12:
        return floor
    return max(20.0 * math.log10(value), floor)


@dataclass(frozen=True)
class AudioQualityReport:
    status: str
    duration_sec: float
    rms_dbfs: float
    peak_dbfs: float
    clipping_ratio: float
    dc_offset: float
    noise_floor_dbfs: float
    speech_level_dbfs: float
    estimated_snr_db: float
    speech_ratio: float
    reasons: tuple[str, ...]
    version: str = AUDIO_QUALITY_VERSION

    @property
    def usable(self) -> bool:
        return self.status != "unusable"

    @property
    def needs_second_pass(self) -> bool:
        return self.status == "degraded"

    def to_dict(self) -> dict:
        data = asdict(self)
        data["reasons"] = list(self.reasons)
        return data


def decode_audio(audio_bytes: bytes) -> np.ndarray:
    """Decode arbitrary supported audio to the recogniser's 16 kHz mono."""
    samples, _ = librosa.load(io.BytesIO(audio_bytes), sr=SAMPLE_RATE, mono=True)
    samples = np.nan_to_num(samples, nan=0.0, posinf=1.0, neginf=-1.0)
    return np.clip(samples, -1.0, 1.0).astype(np.float32, copy=False)


def assess(samples: np.ndarray, sample_rate: int = SAMPLE_RATE) -> AudioQualityReport:
    samples = np.asarray(samples, dtype=np.float32).reshape(-1)
    duration = samples.size / sample_rate if sample_rate else 0.0
    if samples.size == 0:
        return AudioQualityReport(
            status="unusable", duration_sec=0.0, rms_dbfs=-100.0,
            peak_dbfs=-100.0, clipping_ratio=0.0, dc_offset=0.0,
            noise_floor_dbfs=-100.0, speech_level_dbfs=-100.0,
            estimated_snr_db=0.0, speech_ratio=0.0,
            reasons=("empty_audio",),
        )

    absolute = np.abs(samples)
    rms = float(np.sqrt(np.mean(samples.astype(np.float64) ** 2)))
    peak = float(np.max(absolute))
    clipping = float(np.mean(absolute >= 0.995))
    dc_offset = float(abs(np.mean(samples, dtype=np.float64)))

    frame = max(1, int(sample_rate * FRAME_MS / 1000))
    usable = samples[: (samples.size // frame) * frame]
    if usable.size:
        framed = usable.reshape(-1, frame).astype(np.float64)
        frame_rms = np.sqrt(np.mean(framed * framed, axis=1))
        frame_db = np.array([_db(float(v)) for v in frame_rms])
    else:
        frame_db = np.array([_db(rms)])

    noise = float(np.percentile(frame_db, 20))
    speech = float(np.percentile(frame_db, 90))
    snr = max(0.0, speech - noise)
    speech_threshold = max(noise + 8.0, -42.0)
    speech_ratio = float(np.mean(frame_db >= speech_threshold))

    hard: list[str] = []
    degraded: list[str] = []
    rms_db = _db(rms)
    peak_db = _db(peak)

    # Hard failures are deliberately limited to evidence the recogniser cannot
    # recover.  Low estimated SNR alone never rejects a learner.
    if duration < 0.40:
        hard.append("too_short")
    if peak_db < -45.0 or rms_db < -52.0:
        hard.append("no_audible_speech")
    if clipping >= 0.10:
        hard.append("severe_clipping")

    if clipping >= 0.01:
        degraded.append("clipping")
    # Learner phones often record around -35 dBFS without harming recognition
    # (median -34 in the 773-clip corpus).  Only the quietest ~8% need a second
    # opinion; treating every below-median phone as degraded doubled latency on
    # 45% of real clips without identifying noise.
    if rms_db < -42.0:
        degraded.append("very_quiet")
    if dc_offset >= 0.05:
        degraded.append("dc_offset")
    if snr < 8.0:
        degraded.append("low_estimated_snr")
    if speech_ratio < 0.08 and rms_db < -25.0:
        degraded.append("little_clear_speech")

    reasons = tuple(dict.fromkeys(hard + degraded))
    status = "unusable" if hard else ("degraded" if degraded else "good")
    return AudioQualityReport(
        status=status,
        duration_sec=round(duration, 3),
        rms_dbfs=round(rms_db, 2),
        peak_dbfs=round(peak_db, 2),
        clipping_ratio=round(clipping, 6),
        dc_offset=round(dc_offset, 6),
        noise_floor_dbfs=round(noise, 2),
        speech_level_dbfs=round(speech, 2),
        estimated_snr_db=round(snr, 2),
        speech_ratio=round(speech_ratio, 4),
        reasons=reasons,
    )


def assess_audio(audio_bytes: bytes) -> tuple[np.ndarray, AudioQualityReport]:
    samples = decode_audio(audio_bytes)
    return samples, assess(samples)


def enhance(samples: np.ndarray, sample_rate: int = SAMPLE_RATE) -> np.ndarray:
    """Return a restrained high-pass + spectral-floor comparison signal.

    The enhanced signal is never substituted blindly for the recording.  Its
    decode is only a second opinion, which makes modest noise suppression safe
    for held vowels and nasalisation: disagreement lowers certainty instead of
    manufacturing a pronunciation error.
    """
    y = np.asarray(samples, dtype=np.float32).reshape(-1)
    if y.size < 32:
        return y.copy()

    y = y - np.mean(y, dtype=np.float64)
    sos = butter(2, 70.0, btype="highpass", fs=sample_rate, output="sos")
    try:
        filtered = sosfiltfilt(sos, y).astype(np.float32)
    except ValueError:
        filtered = y.astype(np.float32)

    n_fft = 512
    hop = 160
    spectrum = librosa.stft(filtered, n_fft=n_fft, hop_length=hop, win_length=400)
    magnitude = np.abs(spectrum)
    phase = np.exp(1j * np.angle(spectrum))
    noise_profile = np.percentile(magnitude, 20, axis=1, keepdims=True)

    # Never attenuate a bin by more than 9 dB.  This is intentionally gentler
    # than a typical noise gate because Madd/Ghunnah are sustained energy, not
    # disposable background texture.
    cleaned_mag = np.maximum(magnitude - 0.85 * noise_profile, magnitude * 0.35)
    cleaned = librosa.istft(cleaned_mag * phase, hop_length=hop, win_length=400, length=y.size)
    peak = float(np.max(np.abs(cleaned))) if cleaned.size else 0.0
    if peak > 1.0:
        cleaned = cleaned / peak
    return np.asarray(cleaned, dtype=np.float32)


def wav_bytes(samples: np.ndarray, sample_rate: int = SAMPLE_RATE) -> bytes:
    buffer = io.BytesIO()
    sf.write(buffer, np.clip(samples, -1.0, 1.0), sample_rate, format="WAV", subtype="PCM_16")
    return buffer.getvalue()


def enhancement_metadata() -> dict:
    return {"version": ENHANCEMENT_VERSION, "used": True}


def retry_message(report: AudioQualityReport) -> str:
    """Short, actionable copy safe to surface through the existing error UI."""
    if "severe_clipping" in report.reasons:
        return "The recording was distorted. Move the phone a little farther away and try again."
    if "no_audible_speech" in report.reasons:
        return "The recording was too quiet to assess. Move closer to the microphone and try again."
    if "too_short" in report.reasons:
        return "The recording was too short to assess. Recite a little more and try again."
    return "The recording quality was not clear enough to assess reliably. Please try again in a quieter place."


class StreamingQualityTracker:
    """Bounded-memory quality metrics for the live PCM socket."""

    def __init__(self, sample_rate: int = SAMPLE_RATE):
        self.sample_rate = sample_rate
        self._chunks: list[np.ndarray] = []
        self._samples = 0
        # Quality only needs a representative window.  Ninety seconds bounds
        # memory to ~5.5 MB while covering far more than a usual practice take.
        self._limit = 90 * sample_rate

    def add(self, samples: np.ndarray) -> None:
        if self._samples >= self._limit:
            return
        remaining = self._limit - self._samples
        part = np.asarray(samples[:remaining], dtype=np.float32).copy()
        if part.size:
            self._chunks.append(part)
            self._samples += part.size

    def report(self) -> AudioQualityReport:
        samples = np.concatenate(self._chunks) if self._chunks else np.zeros(0, dtype=np.float32)
        return assess(samples, self.sample_rate)
