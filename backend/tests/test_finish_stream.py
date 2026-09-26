"""How a recording is ended before its final tokens are read out.

finish_stream follows the last real audio with 1.5 s of padding so the
streaming recognizer emits the recording's closing tokens. That padding is
quiet noise at about -60 dBFS, never digital silence: exact zeros are a
signal no microphone produces, and ending on them lost the soft closing madd a
learner trails off on (ٱلرَّحِيمِ read back as ررَحِ, reported as a dropped
madd). See END_PADDING for the measurement.

Pinned here:
  - the padding is quiet, the same every time, and not silence
  - endings of every kind still decode: a normal one, a final madd, a final
    non-madd letter, silence left in the recording after the last word, and a
    recording too short to hold a word
  - the live socket's chunk-by-chunk stream and the uploaded recording still
    decode identically
  - real learner recordings whose closing madd digital silence used to lose
    now keep it (needs the local evaluation set; skipped without it)

Only the recognizer's input is affected. The recording itself -- what is
stored, uploaded or replayed -- is never touched.
"""
import io
import sys
from pathlib import Path

import librosa
import numpy as np
import pytest
import soundfile as sf

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import app.phoneme_analysis_service as pas  # noqa: E402
from app.phoneme_analysis_service import PhonemeAnalysisService  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
RECITATIONS = ROOT / "backend" / "app" / "static" / "recitations"
EVALSET = ROOT / "ml" / "data" / "quranic_audio_dataset" / "evalset"
QARI = "abdurrahmaan_as_sudais"
SR = pas.SAMPLE_RATE

# Correctly recited learner clips (all annotators agreed) whose closing madd
# was read back as missing when the recording ended in digital silence.
SOFT_ENDINGS = [
    ("9f41f41c-b8d8-4ba4-87f3-2ad5b0570c31", 1, 1),   # ٱلرَّحِيمِ   came back ررَحِ
    ("40ee8b37-69c8-4035-a227-e286124d52e0", 1, 2),   # ٱلْعَٰلَمِينَ came back لعَاالَمِ
    ("79ab4b58-115b-4ce1-9a99-a0257a36acc0", 1, 6),   # ٱلْمُسْتَقِيمَ came back لمُستَقِۦۦ
]


@pytest.fixture(scope="module")
def service():
    if not (pas.MODEL_DIR / "tokens.txt").is_file():
        pytest.skip("phoneme model not present")
    return PhonemeAnalysisService()


def _qari(surah, ayah):
    path = RECITATIONS / QARI / f"{surah:03d}{ayah:03d}.mp3"
    if not path.is_file():
        pytest.skip(f"no reference audio for {surah}:{ayah}")
    return librosa.load(str(path), sr=SR, mono=True)[0].astype(np.float32)


def _wav(samples) -> bytes:
    buffer = io.BytesIO()
    sf.write(buffer, samples, SR, format="WAV", subtype="PCM_16")
    return buffer.getvalue()


def _last_word(service, samples, surah, ayah):
    return service.analyze_range(_wav(samples), surah, ayah, ayah)[-1]


def _finish_with(service, samples, padding):
    """finish_stream as it was, or with any other padding -- for comparison."""
    stream = service.recognizer.create_stream()
    stream.accept_waveform(SR, samples)
    stream.accept_waveform(SR, padding)
    stream.input_finished()
    while service.recognizer.is_ready(stream):
        service.recognizer.decode_stream(stream)
    return service.recognizer.tokens(stream), service.recognizer.timestamps(stream)


# ── the padding itself ────────────────────────────────────────────────────────

def test_the_padding_is_quiet_noise_not_silence():
    pad = pas.END_PADDING
    assert pad.dtype == np.float32
    assert len(pad) == int(1.5 * SR)
    rms_db = 20 * np.log10(np.sqrt(np.mean(pad.astype(np.float64) ** 2)))
    assert -61.0 < rms_db < -59.0
    assert np.count_nonzero(pad) == len(pad)
    assert np.max(np.abs(pad)) < 0.01           # far below anything spoken


def test_the_padding_is_the_same_every_time():
    again = (np.random.default_rng(0).standard_normal(int(1.5 * SR))
             * 10 ** (-60 / 20)).astype(np.float32)
    assert np.array_equal(pas.END_PADDING, again)


def test_a_recording_decodes_the_same_every_time(service):
    samples = _qari(1, 2)
    assert service._decode(_wav(samples)) == service._decode(_wav(samples))


# ── endings ───────────────────────────────────────────────────────────────────

def test_a_normal_ending_keeps_its_closing_madd(service):
    # Al-Fatihah 1:2 ends on the madd of ٱلْعَٰلَمِينَ.
    last = _last_word(service, _qari(1, 2), 1, 2)
    assert last.recited and last.correct, last.predicted_phonemes
    assert "ۦۦ" in last.predicted_phonemes


def test_an_ending_on_a_letter_not_a_madd(service):
    # Al-Ikhlas 1 ends on the qalqalah of أَحَدٌ, no madd.
    last = _last_word(service, _qari(112, 1), 112, 1)
    assert last.recited and last.correct, last.predicted_phonemes


def test_silence_left_after_the_last_word(service):
    # The reciter stopped, then the recording ran on: digital silence inside
    # the recording itself, and then the room.
    speech = _qari(1, 2)
    for tail in (np.zeros(2 * SR, np.float32),
                 (np.random.default_rng(1).standard_normal(2 * SR) * 0.003).astype(np.float32)):
        last = _last_word(service, np.concatenate([speech, tail]), 1, 2)
        assert last.recited and last.correct, last.predicted_phonemes


def test_a_recording_too_short_to_hold_a_word(service):
    tokens, times = service._decode(_wav(_qari(1, 2)[: int(0.3 * SR)]))
    assert len(tokens) == len(times)
    results = service.analyze_range(_wav(_qari(1, 2)[: int(0.3 * SR)]), 1, 2, 2)
    assert len(results) == len(service.expected_words(1, 2))


def test_the_live_stream_and_the_upload_finish_the_same(service):
    """The socket feeds PCM16 in 200 ms frames and finishes with the same
    padding the upload gets, so both give the same tokens and timestamps."""
    samples = np.concatenate([_qari(112, 1), np.zeros(int(0.35 * SR), np.float32), _qari(112, 2)])
    pcm = (np.clip(samples, -1, 1) * 32767).astype("<i2")
    buffer = io.BytesIO()
    sf.write(buffer, pcm.astype(np.int16), SR, format="WAV", subtype="PCM_16")
    upload = service._decode(buffer.getvalue())

    stream = service.recognizer.create_stream()
    for i in range(0, len(pcm), SR // 5):
        stream.accept_waveform(SR, pcm[i:i + SR // 5].astype(np.float32) / 32768.0)
        while service.recognizer.is_ready(stream):
            service.recognizer.decode_stream(stream)
    live = service.finish_stream(stream)
    assert list(live[0]) == list(upload[0])
    assert list(live[1]) == list(upload[1])


# ── real learner endings ──────────────────────────────────────────────────────

@pytest.mark.parametrize("clip,surah,ayah", SOFT_ENDINGS)
def test_a_soft_closing_madd_is_no_longer_lost(service, clip, surah, ayah):
    path = EVALSET / "clips" / f"{clip}.wav"
    if not path.is_file():
        pytest.skip("learner evaluation set not present (ml/eval/README.md)")
    samples = librosa.load(str(path), sr=SR, mono=True)[0].astype(np.float32)
    # What the upload path hands the recognizer: the PCM16 round trip.
    samples = librosa.load(io.BytesIO(_wav(samples)), sr=SR, mono=True)[0].astype(np.float32)

    # Ending on digital silence lost the madd...
    tokens, times = _finish_with(service, samples, np.zeros(int(1.5 * SR), np.float32))
    pred, idx = service._flatten(tokens)
    words = service._range_words(surah, ayah, ayah)
    prefix = service._mapper.basmala_prefix_len(surah, ayah) if ayah == 1 else 0
    before = service._score(pred, idx, times, surah, words, prefix_len=prefix).results[-1]
    assert before.recited and before.error_type == "madd"

    # ...and the production ending keeps it.
    after = _last_word(service, samples, surah, ayah)
    assert after.recited and after.correct, after.predicted_phonemes
