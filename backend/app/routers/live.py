"""Live recitation streaming: tells the client which word the reciter is on,
while they are still reciting.

The Quran-Lab model is an *online* (streaming) zipformer, so this needs no
second model and no extra training -- the same recognizer that produces the
final per-word verdicts can be fed incrementally and queried mid-utterance.

Deliberate split of responsibility:
  - this endpoint answers only "how far has the reciter got", which is what
    live highlighting needs, and it is allowed to be approximate;
  - the authoritative per-word correct/incorrect verdicts still come from
    POST /sessions/analyze_word_level once the complete recording is uploaded.
A partially-decoded word must never be shown to the user as a mistake, so no
mistake is ever reported from here.

Protocol (client -> server):
  1. text frame: {"token": "<firebase id token>", "surah_number": 1, "from_ayah": 1}
  2. binary frames: raw PCM, 16-bit signed little-endian, mono, 16 kHz
  3. text frame: {"type": "stop"}  (or just close the socket)

Server -> client:
  {"type": "ready",    "surah_number": 1, "total_words": 29}
  {"type": "progress", "ayah": 1, "word_index": 2, "global_index": 2}
  {"type": "error",    "detail": "..."}
"""
import json
import logging

import numpy as np
from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from ..firebase_admin_setup import verify_id_token

router = APIRouter()
logger = logging.getLogger(__name__)

SAMPLE_RATE = 16000

# Re-running the alignment on every arriving chunk would burn CPU for no visible
# benefit -- the highlight only has to keep up with human recitation speed.
# Recompute at most this often, and only when the recognizer actually emitted
# new phonemes since last time.
MIN_SECONDS_BETWEEN_UPDATES = 0.35

# The cursor only ever moves forward, and PhonemeAnalysisService.live_advance
# only looks a few words ahead of it, so a partial transcript cannot jump to
# identical text elsewhere in the surah -- see that method's docstring for the
# measured failure this replaced.

# Close codes. 1008 = policy violation, used here for a failed/absent token.
WS_UNAUTHORIZED = 1008
WS_UNAVAILABLE = 1011


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
        verify_id_token(hello["token"])  # raises on invalid/expired
        surah = int(hello["surah_number"])
        from_ayah = int(hello.get("from_ayah", 1))
    except Exception as exc:
        logger.info(f"Live stream handshake rejected: {exc}")
        await websocket.send_text(json.dumps({"type": "error", "detail": "Not authorized"}))
        await websocket.close(code=WS_UNAUTHORIZED)
        return

    total_words = len(service._range_words(surah, from_ayah, service.ayah_count(surah)))
    if total_words == 0:
        await websocket.send_text(json.dumps({
            "type": "error", "detail": f"No phoneme reference for surah {surah}",
        }))
        await websocket.close(code=WS_UNAVAILABLE)
        return

    await websocket.send_text(json.dumps({
        "type": "ready", "surah_number": surah, "total_words": total_words,
    }))

    # --- streaming decode ------------------------------------------------
    stream = service.recognizer.create_stream()
    samples_seen = 0
    next_update_at = 0.0
    last_token_count = 0
    word_cursor = 0        # next word we expect to hear
    chars_consumed = 0     # phonemes already attributed to confirmed words

    try:
        while True:
            message = await websocket.receive()

            if message.get("type") == "websocket.disconnect":
                break

            text = message.get("text")
            if text is not None:
                # Only "stop" is expected here; anything else ends the session too.
                break

            chunk = message.get("bytes")
            if not chunk:
                continue

            samples = _pcm16_to_float32(chunk)
            if samples.size == 0:
                continue
            samples_seen += samples.size
            stream.accept_waveform(SAMPLE_RATE, samples)
            while service.recognizer.is_ready(stream):
                service.recognizer.decode_stream(stream)

            elapsed = samples_seen / SAMPLE_RATE
            if elapsed < next_update_at:
                continue
            next_update_at = elapsed + MIN_SECONDS_BETWEEN_UPDATES

            tokens = service.recognizer.tokens(stream)
            if len(tokens) == last_token_count:
                continue  # nothing new was recognized -- silence, or still mid-phoneme
            last_token_count = len(tokens)

            pred_chars = [c for t in tokens for c in t]
            step = service.live_advance(pred_chars[chars_consumed:], surah, word_cursor, from_ayah)
            if step is None:
                continue
            ayah, word_index, global_index, consumed = step

            # Advance the cursor past the word we just confirmed, so the next
            # update aligns only the phonemes recognized after it.
            chars_consumed += consumed
            word_cursor = global_index + 1

            await websocket.send_text(json.dumps({
                "type": "progress",
                "ayah": ayah,
                "word_index": word_index,
                "global_index": global_index,
            }))

    except WebSocketDisconnect:
        return
    except Exception:
        logger.exception("Live recitation stream failed")

    try:
        await websocket.close()
    except RuntimeError:
        pass  # already closed by the client
