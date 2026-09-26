"""A recitation begins at an ayah and runs on -- through the rest of its surah,
into the next ones, and for as long as the reciter keeps going.

What these pin, on real Qari audio (consecutive per-ayah clips joined by the
pause a reciter takes between ayahs, so where the recording stops is known):

  - A recording short enough for one alignment gets exactly the answer
    analyze_range always gave. Everything measured on the single-surah
    analyser still holds.
  - A recording longer than one alignment can see is aligned in windows, and
    reaches as far as the audio goes. It used to stop being able to see the
    text after about seven minutes: 18 minutes of 2:57-2:110 came back as 166
    of 1,196 words, "reached" 2:62.
  - Crossing into the next surah, that surah's Basmala is optional exactly as
    it is at the start of a recitation, At-Tawbah has none, and every word
    says which surah it is in.
  - A recording that stops before a surah boundary lists nothing from the
    surah after it.
  - The live socket's stream, fed in chunks and finished, decodes to exactly
    what the uploaded recording would -- the premise of judging the recitation
    from the socket instead of an upload.
"""
import dataclasses
import io
import sys
from pathlib import Path

import librosa
import numpy as np
import pytest
import soundfile as sf

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import app.phoneme_analysis_service as pas  # noqa: E402
from app.phoneme_analysis_service import PhonemeAnalysisService, SpanWords  # noqa: E402

RECITATIONS = Path(__file__).resolve().parent.parent / "app" / "static" / "recitations"
QARI = "abdurrahmaan_as_sudais"
SR = 16000
GAP = np.zeros(int(0.35 * SR), dtype=np.float32)
BASMALA = (1, 1)   # Al-Fatihah 1:1 is the Basmala, recited on its own


def _clip(surah, ayah):
    path = RECITATIONS / QARI / f"{surah:03d}{ayah:03d}.mp3"
    if not path.is_file():
        pytest.skip(f"no reference audio for {surah}:{ayah}")
    return librosa.load(str(path), sr=SR, mono=True)[0]


def _samples(ayahs):
    parts = []
    for surah, ayah in ayahs:
        parts += [_clip(surah, ayah), GAP]
    return np.concatenate(parts[:-1])


def _wav(samples):
    buffer = io.BytesIO()
    sf.write(buffer, samples, SR, format="WAV", subtype="PCM_16")
    return buffer.getvalue()


def _seq(surah, first, last):
    return [(surah, a) for a in range(first, last + 1)]


def _recited_ayahs(results):
    return {(r.surah_number, r.ayah_number) for r in results if r.recited}


@pytest.fixture(scope="module")
def service():
    return PhonemeAnalysisService()


def test_a_short_recording_in_one_surah_gets_exactly_what_analyze_range_gave(service):
    audio = _wav(_samples(_seq(67, 1, 4)))
    ranged = service.analyze_range(audio, 67, 1, None)
    spanned = service.analyze_span(audio, 67, 1)
    assert [dataclasses.asdict(r) for r in spanned] == [dataclasses.asdict(r) for r in ranged]
    assert {r.surah_number for r in spanned} == {67}


def test_crossing_into_the_next_surah_without_its_basmala(service):
    ayahs = _seq(2, 285, 286) + _seq(3, 1, 3)
    results = service.analyze_span(_wav(_samples(ayahs)), 2, 285, 3, None)

    assert _recited_ayahs(results) == set(ayahs)
    basmala = [r for r in results if (r.surah_number, r.ayah_number) == (3, 1)][:4]
    assert [r.display_word for r in basmala][0].startswith("بِسْمِ")
    assert not any(r.recited for r in basmala), "a Basmala nobody said is not recited"
    # Every word is in exactly one place.
    keys = [(r.surah_number, r.ayah_number, r.word_index) for r in results]
    assert len(keys) == len(set(keys))


def test_crossing_into_the_next_surah_with_its_basmala(service):
    ayahs = _seq(2, 285, 286) + [BASMALA] + _seq(3, 1, 3)
    results = service.analyze_span(_wav(_samples(ayahs)), 2, 285, 3, None)

    basmala = [r for r in results if (r.surah_number, r.ayah_number) == (3, 1)][:4]
    assert all(r.recited for r in basmala), "a Basmala the reciter said is recited"
    assert _recited_ayahs(results) == set(_seq(2, 285, 286) + _seq(3, 1, 3))


def test_at_tawbah_has_no_basmala_to_look_for(service):
    ayahs = _seq(8, 74, 75) + _seq(9, 1, 2)
    results = service.analyze_span(_wav(_samples(ayahs)), 8, 74, 114, None)

    assert _recited_ayahs(results) == set(ayahs)
    # 9:1's words are its own, with no Basmala in front, and its first is heard.
    tawbah_1 = [r for r in results if (r.surah_number, r.ayah_number) == (9, 1)]
    assert [r.display_word for r in tawbah_1] == [w[2] for w in service._range_words(9, 1, 1)]
    assert service._mapper.basmala_prefix_len(9, 1) == 0
    assert tawbah_1[0].recited


def test_several_short_surahs_in_a_row(service):
    ayahs = _seq(112, 1, 4) + [BASMALA] + _seq(113, 1, 5) + [BASMALA] + _seq(114, 1, 6)
    results = service.analyze_span(_wav(_samples(ayahs)), 112, 1, 114, None)

    assert _recited_ayahs(results) == set(_seq(112, 1, 4) + _seq(113, 1, 5) + _seq(114, 1, 6))
    for surah in (113, 114):
        basmala = [r for r in results if (r.surah_number, r.ayah_number) == (surah, 1)][:4]
        assert all(r.recited for r in basmala), f"the Basmala before surah {surah} was said"


def test_a_recording_that_stops_before_the_boundary_lists_nothing_after_it(service):
    results = service.analyze_span(_wav(_samples(_seq(2, 284, 285))), 2, 284, 3, None)

    assert {r.surah_number for r in results} == {2}
    assert not any(r.recited for r in results if r.ayah_number == 286)


def test_a_fixed_end_is_respected(service):
    results = service.analyze_span(_wav(_samples(_seq(112, 1, 4))), 112, 1, 112, 2)
    assert {r.ayah_number for r in results} == {1, 2}


def test_windows_follow_a_recording_across_a_surah_boundary(service, monkeypatch):
    """The windowed path, forced onto a short recording with tiny windows so it
    crosses several window edges and the surah boundary inside one."""
    monkeypatch.setattr(pas, "SINGLE_PASS_MAX_CHARS", 300)
    monkeypatch.setattr(pas, "WINDOW_CHARS", 420)
    monkeypatch.setattr(pas, "SETTLE_MARGIN_CHARS", 90)
    ayahs = _seq(2, 284, 286) + _seq(3, 1, 4)
    progress = []
    results = service.analyze_span(_wav(_samples(ayahs)), 2, 284, 3, None, on_progress=progress.append)

    assert _recited_ayahs(results) == set(ayahs)
    recited = [r for r in results if r.recited]
    assert len(recited) >= 0.95 * sum(1 for r in results if (r.surah_number, r.ayah_number) in set(ayahs))
    # Words come back in reading order, each once.
    order = [(r.surah_number, r.ayah_number, r.word_index) for r in results]
    assert order == sorted(order) and len(order) == len(set(order))
    assert len(progress) > 2 and progress == sorted(progress) and progress[-1] == 1.0


def test_a_long_recording_has_no_ceiling(service):
    """6.5 minutes of 2:57-76 -- past the length one alignment handled with its
    usual slack, so it goes through the windowed path with the real constants."""
    ayahs = _seq(2, 57, 76)
    results = service.analyze_span(_wav(_samples(ayahs)), 2, 57)

    recited = [r for r in results if r.recited]
    assert _recited_ayahs(results) == set(ayahs)
    assert (recited[-1].surah_number, recited[-1].ayah_number) == (2, 76)
    in_audio = [r for r in results if r.ayah_number <= 76]
    assert len(recited) >= 0.97 * len(in_audio)


def test_the_live_stream_decodes_to_what_the_upload_would(service):
    """Fed as the socket feeds it -- 200 ms of PCM16 at a time, decoded as it
    arrives -- then finished, the stream gives the same tokens and timestamps
    as decoding the whole recording at once."""
    samples = _samples(_seq(112, 1, 4))
    pcm = (np.clip(samples, -1, 1) * 32767).astype("<i2")
    buffer = io.BytesIO()
    sf.write(buffer, pcm.astype(np.int16), SR, format="WAV", subtype="PCM_16")
    whole = service._decode(buffer.getvalue())

    stream = service.recognizer.create_stream()
    for i in range(0, len(pcm), SR // 5):
        stream.accept_waveform(SR, pcm[i:i + SR // 5].astype(np.float32) / 32768.0)
        while service.recognizer.is_ready(stream):
            service.recognizer.decode_stream(stream)
    streamed = service.finish_stream(stream)

    assert list(streamed[0]) == list(whole[0])
    assert list(streamed[1]) == list(whole[1])


def test_span_words_run_on_into_the_next_surah(service):
    span = SpanWords(service, 2, 286, 3, None)
    last_of_baqarah = len(service._range_words(2, 286, 286))
    around = span.window(last_of_baqarah - 1, 3)
    assert [s for s, _w in around] == [2, 3, 3]
    assert span.starts_segment(0) and span.starts_segment(last_of_baqarah)
    assert not span.starts_segment(1)
    # Nothing past the end asked for.
    closed = SpanWords(service, 112, 4, 112, None)
    assert closed.window(0, 50) == [(112, w) for w in service._range_words(112, 4, 4)]


def test_the_live_cursor_follows_the_reciter_into_the_next_surah(service):
    """The cursor loop as the socket runs it, on 2:286 then 3:1-2."""
    samples = _samples([(2, 286)] + _seq(3, 1, 2))
    span = SpanWords(service, 2, 286, 3, None)
    stream = service.recognizer.create_stream()
    cursor, consumed, reached = 0, 0, None
    for i in range(0, len(samples), SR // 5):
        stream.accept_waveform(SR, samples[i:i + SR // 5])
        while service.recognizer.is_ready(stream):
            service.recognizer.decode_stream(stream)
        pred = [c for t in service.recognizer.tokens(stream) for c in t]
        step = service.live_advance_span(pred[consumed:], span, cursor)
        if step is None:
            continue
        surah, ayah, _word, global_index, used = step
        consumed += used
        cursor = global_index + 1
        reached = (surah, ayah)
    assert reached is not None and reached[0] == 3 and reached[1] == 2


def test_the_single_surah_cursor_is_unchanged(service):
    """live_advance keeps its four-part answer; the eval harnesses read it."""
    samples = _samples([(112, 1)])
    stream = service.recognizer.create_stream()
    stream.accept_waveform(SR, samples)
    tokens, _ = service.finish_stream(stream)
    pred = [c for t in tokens for c in t]
    step = service.live_advance(pred, 112, 0, 1)
    assert step is not None and len(step) == 4 and step[0] == 1


def test_a_span_that_ends_before_it_begins_is_refused(service):
    with pytest.raises(ValueError):
        service.analyze_span(b"", 3, 5, 2, 10)
