"""Real verification of the live-streaming word-tracking endpoint
(app/routers/live.py) -- feeds real recorded audio through the exact
WebSocket protocol the Flutter app's live mic capture uses, in small
time-sliced chunks to genuinely simulate streaming rather than sending
the whole clip as one frame. This cannot use a real live microphone
(no audio hardware access here), but streaming real, known-content audio
through the real protocol in real time-order is the closest honest
substitute -- it exercises the actual server-side incremental-decode and
cursor-advance logic exactly as a live recording would.
"""
import asyncio
import io
import json
import sys

import firebase_admin
import librosa
import numpy as np
import websockets
from firebase_admin import auth as fb_auth
from firebase_admin import credentials

sys.stdout.reconfigure(encoding="utf-8")

SAMPLE_RATE = 16000
CHUNK_MS = 200  # roughly what a live recorder would flush per callback


def get_id_token() -> str:
    import re
    from pathlib import Path

    if not firebase_admin._apps:
        cred = credentials.Certificate("serviceAccountKey.json")
        firebase_admin.initialize_app(cred)
    uid = None
    for u in fb_auth.list_users().iterate_all():
        if u.email and "mustafa" in u.email.lower():
            uid = u.uid
            break
    custom_token = fb_auth.create_custom_token(uid).decode()

    import httpx

    opts = Path("../frontend/lib/firebase_options.dart").read_text(encoding="utf-8")
    api_key = re.search(r"apiKey:\s*'([^']+)'", opts).group(1)
    r = httpx.post(
        f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key={api_key}",
        json={"token": custom_token, "returnSecureToken": True}, timeout=15,
    )
    return r.json()["idToken"]


async def stream_clip(path: str, surah: int, from_ayah: int, token: str):
    y, _ = librosa.load(path, sr=SAMPLE_RATE, mono=True)
    pcm16 = (np.clip(y, -1.0, 1.0) * 32767.0).astype("<i2").tobytes()
    chunk_size = int(SAMPLE_RATE * (CHUNK_MS / 1000.0)) * 2  # 2 bytes/sample

    events = []
    async with websockets.connect("ws://127.0.0.1:8000/api/v1/sessions/stream", max_size=None) as ws:
        await ws.send(json.dumps({"token": token, "surah_number": surah, "from_ayah": from_ayah}))
        hello = json.loads(await ws.recv())
        events.append(("hello", hello))
        if hello.get("type") != "ready":
            return events

        for i in range(0, len(pcm16), chunk_size):
            await ws.send(pcm16[i:i + chunk_size])
            await asyncio.sleep(CHUNK_MS / 1000.0 * 0.3)  # don't actually wait full real-time, just enough to let the server keep up
            try:
                while True:
                    msg = await asyncio.wait_for(ws.recv(), timeout=0.01)
                    events.append(("progress", json.loads(msg)))
            except asyncio.TimeoutError:
                pass

        # Drain any trailing messages after all audio is sent.
        await ws.send(json.dumps({"type": "stop"}))
        try:
            while True:
                msg = await asyncio.wait_for(ws.recv(), timeout=2.0)
                events.append(("progress", json.loads(msg)))
        except (asyncio.TimeoutError, websockets.exceptions.ConnectionClosed):
            pass

    return events


async def main():
    token = get_id_token()
    results = {}

    # Case 1: Bismillah alone, whole-surah range -- the exact scenario that
    # exposed the batch-endpoint bug. The live cursor's design should never
    # let this jump to ayah 3's identical "الرحمن الرحيم" the way the old
    # batch window did.
    events = await stream_clip(
        "app/static/recitations/abdurrahmaan_as_sudais/001001.mp3", surah=1, from_ayah=1, token=token,
    )
    results["fatihah_ayah1_only_whole_surah_range"] = events

    with open("tests/live_stream_result.json", "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)
    print("done")


if __name__ == "__main__":
    asyncio.run(main())
