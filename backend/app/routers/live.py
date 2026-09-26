"""Live recitation streaming: tells the client which word the reciter is on,
while they are still reciting -- and, when they stop, judges the whole
recitation from the same stream.

The Quran-Lab model is an *online* (streaming) zipformer, so this needs no
second model and no extra training -- the same recognizer that produces the
final per-word verdicts can be fed incrementally and queried mid-utterance.

Three different jobs, on different kinds of evidence:

  - the *cursor* answers "how far has the reciter got". It runs on a partial
    decode of a word still being spoken, so it is allowed to be approximate and
    is never allowed to call anything a mistake: half a word matches half its
    phonemes, and flagging that would accuse the reciter of an error they are
    still in the middle of not making.

  - an *ayah_result* carries verdicts for words whose audio has fully arrived,
    with a little to spare. Those are re-analysed by the same call the results
    screen uses, so they may report mistakes. That margin is what makes them
    trustworthy -- see SETTLE_MARGIN_SEC for how much is enough.

  - the *result*, when the client ends with "finish": the authoritative
    analysis of the whole recording, the same one POST
    /sessions/analyze_word_level runs on an upload, and stored the same way.
    It runs on this socket's own stream, which by then has decoded everything
    the reciter said: finished, that stream gives exactly the tokens and
    timestamps decoding the uploaded recording would (see
    PhonemeAnalysisService.analyze_decoded_span). So the recording is neither
    uploaded nor decoded a second time, and the wait is only the alignment.

Each ayah_result carries only the words that have just settled, so a client
merges them into whatever it already holds for that ayah rather than replacing
it. Where an ayah_result and the final result disagree, the final one stands.

A recitation can run on from the surah it began in into the next ones, as far
as the handshake's end_surah/to_ayah allow: the cursor follows it across the
boundary, and every progress and ayah_result names the surah it is about.

Protocol (client -> server):
  1. text frame: {"token": "<firebase id token>", "surah_number": 1,
                  "from_ayah": 1, "end_surah": 1, "to_ayah": null, "qari_id": "..."}
     (end_surah defaults to surah_number, to_ayah to the end of end_surah)
  2. binary frames: raw PCM, 16-bit signed little-endian, mono, 16 kHz
  3. text frame: {"type": "finish"} -- judge the recording and return it, or
     {"type": "stop"} (or just close the socket) -- discard it

Server -> client:
  {"type": "ready",    "surah_number": 1, "total_words": 29, "finish": true}
  {"type": "progress", "surah": 1, "ayah": 1, "word_index": 2, "global_index": 2}
  {"type": "ayah_result", "surah": 1, "ayah": 1, "words": [...]}   # words that have settled
  {"type": "analysis_progress", "fraction": 0.42}                  # after "finish"
  {"type": "result", ...}          # after "finish": the analyze_word_level response
  {"type": "error",    "detail": "..."}
"""
import asyncio
import io
import json
import logging
from collections import deque

import numpy as np
import soundfile as sf
from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from ..firebase_admin_setup import verify_id_token
from ..phoneme_analysis_service import SpanWords
from .sessions import record_session

router = APIRouter()
logger = logging.getLogger(__name__)

SAMPLE_RATE = 16000
DEFAULT_QARI_ID = "abdurrahmaan_as_sudais"

# Re-running the alignment on every arriving chunk would burn CPU for no visible
# benefit, but this was throttled harder than it needed to be: at 0.35s it added
# up to a third of a second to a cursor already sitting a measured 0.66s behind
# the voice. live_advance only aligns a short window, so it is cheap; the costly
# per-word analysis is throttled separately by SETTLE_MARGIN_SEC and its own
# one-at-a-time guard.
MIN_SECONDS_BETWEEN_UPDATES = 0.15

# Least audio between one per-word check and the next.
#
# The check no longer blocks the cursor (it runs as its own task), so this is
# not about keeping up -- it is about not keeping a core busy for the whole
# recitation to say the same thing sooner than the reciter can read it.
# Measured on Al-Mulk 1-6 streamed at real-time pace, how long after a word was
# spoken its verdict reached the client: 4.2s at two seconds apart, 3.7s with
# no gap at all, against 7.4s when the check still blocked the cursor.
MIN_SECONDS_BETWEEN_CHECKS = 2.0

# A ceiling on how deep into a long surah live feedback keeps running. Each pass
# is a bounded cost now (see LIVE_CONTEXT_AYAHS), so this is no longer about the
# work growing -- it is a floor under the streaming recogniser's share of the
# CPU on a recitation of Al-Baqarah's length. Past it the preview stops and the
# results screen still judges the whole recording at the end.
MAX_LIVE_ANALYSIS_AYAHS = 30

# How many ayahs before the words being judged the live analysis window opens.
# Enough of a running start for the recogniser, without the cost growing with
# the length of the recitation -- see _settled_word_verdicts.
LIVE_CONTEXT_AYAHS = 2

# ...and a hard ceiling on that window in seconds. Bounding by ayahs alone only
# bounds the work where ayahs are short. Outside Juz 30 a single ayah can run
# past a minute, so "two ayahs back" would quietly become the same unbounded
# cost this was meant to remove.
MAX_LIVE_WINDOW_SEC = 20.0

# How much of the recording the socket keeps. The per-word check never looks
# further back than MAX_LIVE_WINDOW_SEC, and the final analysis runs on the
# decoded stream rather than on audio, so nothing needs more than this. It used
# to keep everything: 45 minutes of a juz is 170 MB of float32 per listener.
KEEP_AUDIO_SEC = MAX_LIVE_WINDOW_SEC + 15.0

# Audio kept before the window's first ayah, since the cursor's boundary is late.
AYAH_LEAD_IN_SEC = 0.3

# How much audio must follow a word before its verdict is worth showing.
#
# This replaced a fixed five-word lag. The word count was a proxy for the thing
# that actually matters -- has this word's audio all arrived? -- and a bad one,
# because a fast reciter covers five words in a second and a slow one takes
# several. The analyser already timestamps every word, so the real quantity is
# available directly.
#
# Measured on reference recitation (ml/eval/crossmodel/measure_live_latency.py),
# how often a live verdict already matches what the complete recording concludes,
# by how much audio had followed the word:
#
#     < 0.5s  -> 94.7%      1-2s -> 93.5%
#     0.5-1s  -> 97.3%      2-3s -> 95.7%
#
# Agreement does not keep improving with more delay -- it peaks just under a
# second. Waiting longer is not more careful, it is only slower, because the
# analysis runs on a bounded window and a word drifting towards that window's
# edge starts losing the context that made its verdict right.
SETTLE_MARGIN_SEC = 0.6

# How many words back to re-examine on each pass. Wide enough that nothing is
# missed when several words settle at once, narrow enough to stay inside the
# analysis window.
SETTLE_LOOKBACK_WORDS = 12

# The cursor only ever moves forward, and PhonemeAnalysisService.live_advance
# only looks a few words ahead of it, so a partial transcript cannot jump to
# identical text elsewhere in the surah -- see that method's docstring for the
# measured failure this replaced.

# Close codes. 1008 = policy violation, used here for a failed/absent token.
WS_UNAUTHORIZED = 1008
WS_UNAVAILABLE = 1011


def _encode_wav(samples: np.ndarray) -> bytes:
    """PCM float32 -> a WAV buffer, which is what analyze_span takes."""
    buffer = io.BytesIO()
    sf.write(buffer, samples, SAMPLE_RATE, format="WAV", subtype="PCM_16")
    return buffer.getvalue()


class _RecentAudio:
    """The last KEEP_AUDIO_SEC of the recording, addressed by absolute sample
    index so positions noted earlier in the recitation still find their place
    in it."""

    def __init__(self, keep_samples: int):
        self._keep = keep_samples
        self._chunks: deque[np.ndarray] = deque()
        self._held = 0
        self.start = 0          # absolute index of the first sample still held

    def append(self, samples: np.ndarray) -> None:
        self._chunks.append(samples)
        self._held += samples.size
        while self._chunks and self._held - self._chunks[0].size >= self._keep:
            dropped = self._chunks.popleft()
            self._held -= dropped.size
            self.start += dropped.size

    def snapshot(self) -> tuple[np.ndarray, int]:
        """(the samples held, absolute index of the first of them)."""
        if not self._chunks:
            return np.zeros(0, dtype=np.float32), self.start
        return np.concatenate(self._chunks), self.start


def _ayahs_before(service, position: tuple[int, int], count: int,
                  floor: tuple[int, int]) -> tuple[int, int]:
    """The ayah [count] ayahs before [position] -- back into the previous surah
    if need be -- but never before [floor], where the recitation began."""
    surah, ayah = position
    for _ in range(count):
        if (surah, ayah) <= floor:
            break
        if ayah > 1:
            ayah -= 1
        else:
            surah -= 1
            ayah = service.ayah_count(surah)
    return max((surah, ayah), floor)


async def _settled_word_verdicts(service, recent: tuple[np.ndarray, int], span: SpanWords,
                                 span_start: tuple[int, int], through: tuple[int, int],
                                 first_global: int, last_global: int,
                                 ayah_first_sample: dict[tuple[int, int], int]) -> list[dict]:
    """Verdicts for the recitation's words [first_global, last_global], grouped
    by (surah, ayah).

    Analysed over a *window* of the recording, not all of it
    ------------------------------------------------------
    Re-analysing from the first sample every time made the cost grow with the
    recitation, and past about half a minute it stopped keeping up. Measured on
    Al-Fatihah:

        5s of audio -> 0.45s     20s -> 1.60s     40s -> 3.79s

    Settled words arrive every second or two, so by forty seconds in each pass
    took longer than the gap between passes; they queued, feedback fell further
    and further behind the voice, and whatever was still queued when the reciter
    stopped never arrived at all. That is both halves of "it is slow and it
    misses errors".

    So the window starts a couple of ayahs before the words being judged. That
    is ample left context -- what the recogniser needs is a running start, not
    the whole history -- and it makes each pass a constant cost instead of a
    growing one. The window's own opening words are not reported, only used as
    context, so the cursor's boundaries being a little late does not matter here
    the way it did when the slice had to contain the judged words exactly.

    Runs off the event loop -- a decode takes long enough that doing it inline
    would stall the socket and drop incoming audio.
    """
    held, held_from = recent
    if held.size == 0 or last_global < first_global:
        return []

    # Which (surah, ayah, word) triples were asked for. Addressing them this
    # way rather than by position keeps the answer independent of where the
    # window starts.
    targets = {(surah, w[0], w[1])
               for surah, w in span.window(first_global, last_global - first_global + 1)}
    if not targets:
        return []

    earliest = min((surah, ayah) for surah, ayah, _ in targets)
    window_from = _ayahs_before(service, earliest, LIVE_CONTEXT_AYAHS, span_start)
    received = held_from + held.size
    start = max(ayah_first_sample.get(window_from, held_from) - int(AYAH_LEAD_IN_SEC * SAMPLE_RATE), 0)

    # Clamp the window to a fixed span of audio, then move `window_from` up to
    # whichever ayah that lands in, so the expected text still lines up with
    # what is actually being fed in.
    floor = received - int(MAX_LIVE_WINDOW_SEC * SAMPLE_RATE)
    if start < floor:
        start = max(floor, 0)
        later = [pos for pos, sample in sorted(ayah_first_sample.items()) if sample <= start]
        if later:
            window_from = max(window_from, later[-1])
            start = min(start, ayah_first_sample[window_from])
    audio = held[max(start, held_from) - held_from:]
    if audio.size < SAMPLE_RATE // 4:
        return []

    try:
        results = await asyncio.to_thread(
            service.analyze_span, _encode_wav(audio), window_from[0], window_from[1],
            through[0], through[1])
    except Exception:
        # Live feedback is a bonus, never the authoritative verdict. If this
        # fails the recitation carries on and the results screen still judges
        # the whole recording at the end.
        logger.exception("Live word analysis failed at %s", through)
        return []

    # A word is ready when its own audio finished comfortably before the end of
    # the window -- everything here is in the window's own time frame.
    window_end = audio.size / SAMPLE_RATE

    by_ayah: dict[tuple[int, int], list[dict]] = {}
    for r in results:
        if (r.surah_number, r.ayah_number, r.word_index) not in targets or not r.recited:
            continue
        if window_end - r.end_sec < SETTLE_MARGIN_SEC:
            continue          # still too close to the live edge to trust
        by_ayah.setdefault((r.surah_number, r.ayah_number), []).append({
            "word_index": r.word_index,
            "word": r.display_word,
            "recited": r.recited,
            "correct": r.correct,
            "error_type": r.error_type,
            "explanation": r.explanation,
        })

    return [{"type": "ayah_result", "surah": surah, "ayah": ayah, "words": words}
            for (surah, ayah), words in sorted(by_ayah.items())]


async def _send_verdicts(websocket, payloads: list[dict], sent_words: set) -> None:
    """Send only the words not reported before.

    The lookback deliberately overlaps what was already reported, so a word
    held back last time for being too near the live edge is picked up as soon
    as it is ready -- without re-sending the ones already on screen.
    """
    for payload in payloads:
        fresh = [w for w in payload["words"]
                 if (payload["surah"], payload["ayah"], w["word_index"]) not in sent_words]
        if not fresh:
            continue
        for w in fresh:
            sent_words.add((payload["surah"], payload["ayah"], w["word_index"]))
        await websocket.send_text(json.dumps(
            {**payload, "words": fresh}, ensure_ascii=False))


async def _finished_check(task) -> list[dict]:
    """The verdicts a background check produced, or none if it failed."""
    try:
        return await task
    except asyncio.CancelledError:
        raise
    except Exception:
        # Live feedback is a bonus; the results screen still judges the whole
        # recording at the end.
        logger.exception("Live word check failed")
        return []


async def _finish(websocket, service, stream, uid: str, span: tuple, qari_id: str) -> None:
    """Judge the whole recitation from this socket's own stream, store it, and
    send it back -- the "finish" the client asks for when recording stops.

    There used to be a flush here instead: one more full-recording analysis
    whose verdicts went out as ayah_results after "stop". The client had
    already closed the socket by then, so they were never read -- while the
    analysis held the recogniser ahead of the upload the results screen was
    actually waiting for, adding its whole duration to that wait.
    """
    loop = asyncio.get_running_loop()
    progress: asyncio.Queue = asyncio.Queue()

    def report(fraction: float) -> None:          # from the analysing thread
        loop.call_soon_threadsafe(progress.put_nowait, fraction)

    def judge():
        tokens, timestamps = service.finish_stream(stream)
        return service.analyze_decoded_span(tokens, timestamps, *span, on_progress=report)

    task = asyncio.ensure_future(asyncio.to_thread(judge))
    sent = -1.0
    while not task.done():
        try:
            fraction = await asyncio.wait_for(progress.get(), timeout=0.5)
        except asyncio.TimeoutError:
            continue
        if fraction - sent >= 0.01:
            sent = fraction
            await websocket.send_text(json.dumps({"type": "analysis_progress", "fraction": round(fraction, 3)}))
    try:
        results = await task
    except Exception as exc:
        logger.exception("Final analysis of a live recitation failed")
        await websocket.send_text(json.dumps({"type": "error", "detail": f"Could not analyze audio: {exc}"}))
        return

    # Is anyone still waiting? A client that gave up has sent the recording the
    # other way, and storing this one as well would put one recitation in the
    # history twice.
    try:
        await websocket.send_text(json.dumps({"type": "analysis_progress", "fraction": 1.0}))
    except Exception:
        return
    try:
        response = await asyncio.to_thread(
            record_session, uid, results, surah_number=span[0], from_ayah=span[1], qari_id=qari_id)
    except Exception as exc:
        logger.exception("Storing a live recitation failed")
        await websocket.send_text(json.dumps({"type": "error", "detail": f"Could not store the recitation: {exc}"}))
        return
    await websocket.send_text(json.dumps({"type": "result", **response}, ensure_ascii=False))


def _pcm16_to_float32(data: bytes) -> np.ndarray:
    """Client sends 16-bit signed PCM; sherpa wants float32 in [-1, 1]."""
    if len(data) % 2:
        data = data[:-1]  # drop a trailing half-sample rather than misreading the buffer
    return np.frombuffer(data, dtype="<i2").astype(np.float32) / 32768.0


@router.websocket("/sessions/stream")
async def stream_recitation(websocket: WebSocket):
    await websocket.accept()

    service = websocket.app.state.phoneme_analysis_service
    if service is None:
        await websocket.send_text(json.dumps({
            "type": "error",
            "detail": "Live analysis isn't available on this server (phoneme model not loaded).",
        }))
        await websocket.close(code=WS_UNAVAILABLE)
        return

    # --- handshake -------------------------------------------------------
    try:
        hello = json.loads(await websocket.receive_text())
        uid = verify_id_token(hello["token"])  # raises on invalid/expired
        surah = int(hello["surah_number"])
        from_ayah = int(hello.get("from_ayah", 1))
        end_surah = int(hello["end_surah"]) if hello.get("end_surah") is not None else surah
        to_ayah = int(hello["to_ayah"]) if hello.get("to_ayah") is not None else None
        qari_id = str(hello.get("qari_id") or DEFAULT_QARI_ID)
    except Exception as exc:
        logger.info(f"Live stream handshake rejected: {exc}")
        await websocket.send_text(json.dumps({"type": "error", "detail": "Not authorized"}))
        await websocket.close(code=WS_UNAUTHORIZED)
        return

    try:
        span_args = service._check_span(surah, from_ayah, end_surah, to_ayah)
    except ValueError:
        await websocket.send_text(json.dumps({
            "type": "error", "detail": f"No phoneme reference for surah {surah}",
        }))
        await websocket.close(code=WS_UNAVAILABLE)
        return
    span = SpanWords(service, *span_args)
    span_start = (surah, from_ayah)

    await websocket.send_text(json.dumps({
        "type": "ready", "surah_number": surah, "total_words": span.first_segment_length(),
        # This server can judge the recording itself when told to "finish".
        "finish": True,
    }))

    # --- streaming decode ------------------------------------------------
    stream = service.recognizer.create_stream()
    samples_seen = 0
    next_update_at = 0.0
    last_token_count = 0
    word_cursor = 0        # next word we expect to hear
    chars_consumed = 0     # phonemes already attributed to confirmed words

    # Kept so settled words can be re-analysed in full. The streaming
    # recognizer's own state cannot be rewound, and a per-word verdict needs the
    # complete audio of a word rather than the partial decode the cursor runs
    # on -- which is exactly why the cursor is not allowed to report mistakes.
    recent = _RecentAudio(int(KEEP_AUDIO_SEC * SAMPLE_RATE))
    # (surah, ayah, word_index) already sent, so an overlapping lookback does
    # not repeat itself.
    sent_words: set[tuple[int, int, int]] = set()
    # Absolute sample where the cursor first reported each (surah, ayah). Late
    # by the cursor's own lag, which is fine: it only ever picks a window start
    # a couple of ayahs earlier, never a boundary that has to be exact.
    ayah_first_sample: dict[tuple[int, int], int] = {}
    # The per-word check, running beside this loop. One at a time: a second one
    # started while the first is still going would only queue behind it on the
    # same recognizer, and the backlog would never drain while the reciter
    # keeps going.
    checking: asyncio.Task | None = None
    next_check_at = 0            # in samples of audio received

    try:
        while True:
            message = await websocket.receive()

            if message.get("type") == "websocket.disconnect":
                break

            text = message.get("text")
            if text is not None:
                try:
                    kind = json.loads(text).get("type")
                except (ValueError, AttributeError):
                    kind = None
                if kind == "finish":
                    # The live check shares the recogniser lock with the final
                    # analysis and its verdicts are no longer wanted: the
                    # client is waiting for the whole recitation's.
                    if checking is not None:
                        checking.cancel()
                        checking = None
                    await _finish(websocket, service, stream, uid, span_args, qari_id)
                # "stop", or anything else: the recitation is discarded.
                break

            chunk = message.get("bytes")
            if not chunk:
                continue

            samples = _pcm16_to_float32(chunk)
            if samples.size == 0:
                continue
            samples_seen += samples.size
            recent.append(samples)
            stream.accept_waveform(SAMPLE_RATE, samples)
            while service.recognizer.is_ready(stream):
                service.recognizer.decode_stream(stream)

            # A finished check's verdicts go out as soon as they are ready,
            # rather than waiting for the cursor to move again -- a reciter
            # pausing for breath should still see the words behind them settle.
            if checking is not None and checking.done():
                payloads = await _finished_check(checking)
                checking = None
                await _send_verdicts(websocket, payloads, sent_words)

            elapsed = samples_seen / SAMPLE_RATE
            if elapsed < next_update_at:
                continue
            next_update_at = elapsed + MIN_SECONDS_BETWEEN_UPDATES

            tokens = service.recognizer.tokens(stream)
            if len(tokens) == last_token_count:
                continue  # nothing new was recognized -- silence, or still mid-phoneme
            last_token_count = len(tokens)

            pred_chars = [c for t in tokens for c in t]
            step = service.live_advance_span(pred_chars[chars_consumed:], span, word_cursor)
            if step is None:
                continue
            at_surah, ayah, word_index, global_index, consumed = step

            # Advance the cursor past the word we just confirmed, so the next
            # update aligns only the phonemes recognized after it.
            chars_consumed += consumed
            word_cursor = global_index + 1

            await websocket.send_text(json.dumps({
                "type": "progress",
                "surah": at_surah,
                "ayah": ayah,
                "word_index": word_index,
                "global_index": global_index,
            }))

            ayah_first_sample.setdefault((at_surah, ayah), samples_seen)

            # Judge the words just behind the cursor, off to one side: this loop
            # goes straight back to reading audio while the check runs. Waiting
            # for it here is what left the cursor a measured 15 words behind the
            # voice on Al-Mulk, with 15 of its 72 words never lit at all -- the
            # audio kept arriving, but nothing was reading it.
            #
            # Which words are ready is decided by how much audio has followed
            # each one, not by counting words back -- see SETTLE_MARGIN_SEC.
            if (checking is None and samples_seen >= next_check_at
                    and len(ayah_first_sample) - 1 <= MAX_LIVE_ANALYSIS_AYAHS):
                next_check_at = samples_seen + int(MIN_SECONDS_BETWEEN_CHECKS * SAMPLE_RATE)
                # Snapshots: the check reads these while the loop keeps adding
                # to the live ones.
                checking = asyncio.create_task(_settled_word_verdicts(
                    service, recent.snapshot(), span, span_start, (at_surah, ayah),
                    max(0, global_index - SETTLE_LOOKBACK_WORDS), global_index,
                    dict(ayah_first_sample)))

    except WebSocketDisconnect:
        return
    except Exception:
        logger.exception("Live recitation stream failed")
    finally:
        # Nothing is listening for it any more.
        if checking is not None and not checking.done():
            checking.cancel()

    try:
        await websocket.close()
    except RuntimeError:
        pass  # already closed by the client
