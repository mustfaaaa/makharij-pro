"""The live socket judges the whole recitation itself when the reciter stops.

The socket has decoded everything the reciter said by the time they stop, so
"finish" runs the final analysis on that stream instead of on a second copy of
the recording uploaded afterwards. What that must never do is give a different
answer from the upload: these stream real audio through the socket exactly as
the app does -- PCM16 in 200 ms frames -- and compare.

Also pinned: the cursor follows a recitation into the next surah and says so,
"stop" discards the recitation without the full re-analysis it used to run for
nobody, and a span that ends before it begins is refused.

In-process: token verification and the Firestore write are replaced, so
nothing here touches a real account.
"""
import io
import json
import sys
from pathlib import Path

import librosa
import numpy as np
import pytest
import soundfile as sf
from fastapi import FastAPI
from fastapi.testclient import TestClient
from starlette.websockets import WebSocketDisconnect

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app import firestore_service  # noqa: E402
from app.phoneme_analysis_service import PhonemeAnalysisService  # noqa: E402
from app.routers import live  # noqa: E402
from app.routers.sessions import record_session  # noqa: E402

RECITATIONS = Path(__file__).resolve().parent.parent / "app" / "static" / "recitations"
QARI = "abdurrahmaan_as_sudais"
SR = 16000
GAP = np.zeros(int(0.35 * SR), dtype=np.float32)


def _pcm16(ayahs) -> bytes:
    parts = []
    for surah, ayah in ayahs:
        path = RECITATIONS / QARI / f"{surah:03d}{ayah:03d}.mp3"
        if not path.is_file():
            pytest.skip(f"no reference audio for {surah}:{ayah}")
        parts += [librosa.load(str(path), sr=SR, mono=True)[0], GAP]
    samples = np.concatenate(parts[:-1])
    return (np.clip(samples, -1, 1) * 32767).astype("<i2").tobytes()


def _wav(pcm: bytes) -> bytes:
    buffer = io.BytesIO()
    sf.write(buffer, np.frombuffer(pcm, dtype="<i2"), SR, format="WAV", subtype="PCM_16")
    return buffer.getvalue()


def _frames(pcm: bytes):
    step = (SR // 5) * 2     # 200 ms of 16-bit samples
    for i in range(0, len(pcm), step):
        yield pcm[i:i + step]


@pytest.fixture(scope="module")
def service():
    return PhonemeAnalysisService()


@pytest.fixture
def socket(service, monkeypatch):
    app = FastAPI()
    app.include_router(live.router, prefix="/api/v1")
    app.state.phoneme_analysis_service = service
    monkeypatch.setattr(live, "verify_id_token", lambda token: "uid-1")
    saved = []

    def fake_save(**kwargs):
        saved.append(kwargs)
        return f"session-{len(saved)}"

    monkeypatch.setattr(firestore_service, "save_session", fake_save)
    with TestClient(app) as client:
        yield client, saved


def _hello(ws, **span):
    ws.send_text(json.dumps({"token": "t", **span}))
    ready = json.loads(ws.receive_text())
    assert ready["type"] == "ready"
    return ready


def test_finish_judges_the_recitation_as_the_upload_would(service, socket):
    client, saved = socket
    pcm = _pcm16([(2, 286), (3, 1), (3, 2)])

    with client.websocket_connect("/api/v1/sessions/stream") as ws:
        ready = _hello(ws, surah_number=2, from_ayah=286, end_surah=3)
        assert ready["finish"] is True
        for frame in _frames(pcm):
            ws.send_bytes(frame)
        ws.send_text(json.dumps({"type": "finish"}))
        messages = []
        while True:
            message = json.loads(ws.receive_text())
            messages.append(message)
            if message["type"] in ("result", "error"):
                break

    result = messages[-1]
    assert result["type"] == "result", result
    assert len(saved) == 1 and saved[0]["uid"] == "uid-1" and saved[0]["end_surah"] == 3

    # The cursor followed the reciter across the boundary, and said which surah.
    positions = [(m["surah"], m["ayah"]) for m in messages if m["type"] == "progress"]
    assert positions and positions[-1][0] == 3 and positions == sorted(positions)
    fractions = [m["fraction"] for m in messages if m["type"] == "analysis_progress"]
    assert fractions and fractions == sorted(fractions) and fractions[-1] == 1.0

    # Exactly what analysing the uploaded recording gives.
    uploaded = record_session("uid-1", service.analyze_span(_wav(pcm), 2, 286, 3, None),
                              surah_number=2, from_ayah=286, qari_id=QARI)
    for field in ("words", "reached_surah", "reached_ayah", "reached_word_index",
                  "end_surah", "to_ayah", "words_recited", "words_correct", "total_words"):
        assert result[field] == uploaded[field], field
    assert result["reached_surah"] == 3


def test_stop_discards_the_recitation(socket):
    client, saved = socket
    pcm = _pcm16([(112, 1), (112, 2)])

    with client.websocket_connect("/api/v1/sessions/stream") as ws:
        _hello(ws, surah_number=112, from_ayah=1)
        for frame in _frames(pcm):
            ws.send_bytes(frame)
        ws.send_text(json.dumps({"type": "stop"}))
        after_stop = []
        with pytest.raises(WebSocketDisconnect):
            while True:
                after_stop.append(json.loads(ws.receive_text()))

    assert not any(m["type"] in ("result", "analysis_progress") for m in after_stop)
    assert saved == []


def test_a_span_that_ends_before_it_begins_is_refused(socket):
    client, _saved = socket
    with client.websocket_connect("/api/v1/sessions/stream") as ws:
        ws.send_text(json.dumps({"token": "t", "surah_number": 3, "from_ayah": 5, "end_surah": 2}))
        message = json.loads(ws.receive_text())
        assert message["type"] == "error"
