"""Live check of the recitation streaming socket against a running server,
using real Firebase auth and real audio -- the same handshake, PCM format and
chunk size the Flutter recorder uses.

What it proves: as audio arrives, the server reports the reciter's position
word by word, in order, and never runs past where they actually stopped. That
is what drives the reading page's word highlighting.

Run with the backend up:  python tests/live_stream_check.py
"""
import asyncio
import json
import re
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

import firebase_admin
import httpx
import librosa
import numpy as np
import websockets
from firebase_admin import auth as fb_auth
from firebase_admin import credentials

WS_URL = "ws://127.0.0.1:8000/api/v1/sessions/stream"
BACKEND_DIR = Path(__file__).resolve().parent.parent
FRONTEND_DIR = BACKEND_DIR.parent / "frontend"
RECIT_DIR = BACKEND_DIR / "app" / "static" / "recitations" / "abdurrahmaan_as_sudais"

SURAH = 1
RECITED_UPTO = 4      # surah 1 has 7 ayahs; stop early on purpose
CHUNK_MS = 100        # matches the recorder's stream chunk size


def get_id_token() -> str:
    if not firebase_admin._apps:
        firebase_admin.initialize_app(credentials.Certificate(str(BACKEND_DIR / "serviceAccountKey.json")))
    users = list(fb_auth.list_users().iterate_all())
    if not users:
        raise RuntimeError("No Firebase users exist to mint a token for")
    user = next((u for u in users if u.email and "mustafa" in u.email.lower()), users[0])
    custom_token = fb_auth.create_custom_token(user.uid).decode()
    api_key = re.search(
        r"apiKey:\s*'([^']+)'",
        (FRONTEND_DIR / "lib" / "firebase_options.dart").read_text(encoding="utf-8"),
    ).group(1)
    resp = httpx.post(
        f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key={api_key}",
        json={"token": custom_token, "returnSecureToken": True},
        timeout=15,
    )
    resp.raise_for_status()
    return resp.json()["idToken"]


def build_pcm16() -> tuple[bytes, float]:
    chunks = []
    for ayah in range(1, RECITED_UPTO + 1):
        y, _ = librosa.load(str(RECIT_DIR / f"{SURAH:03d}{ayah:03d}.mp3"), sr=16000, mono=True)
        chunks += [y, np.zeros(int(0.3 * 16000), dtype=np.float32)]
    y = np.concatenate(chunks)
    return (np.clip(y, -1, 1) * 32767).astype("<i2").tobytes(), len(y) / 16000


async def main() -> int:
    token = get_id_token()
    pcm, duration = build_pcm16()
    print(f"streaming {duration:.1f}s of surah {SURAH} ayahs 1-{RECITED_UPTO} "
          f"in {CHUNK_MS}ms chunks\n")

    updates = []
    async with websockets.connect(WS_URL, max_size=None) as ws:
        await ws.send(json.dumps({"token": token, "surah_number": SURAH, "from_ayah": 1}))
        ready = json.loads(await ws.recv())
        if ready.get("type") != "ready":
            print(f"FAIL: handshake rejected -> {ready}")
            return 1
        print(f"ready: surah has {ready['total_words']} words\n")

        async def receive():
            try:
                async for raw in ws:
                    msg = json.loads(raw)
                    if msg.get("type") != "progress":
                        continue
                    updates.append(msg)
                    print(f"  -> ayah {msg['ayah']}, word {msg['word_index'] + 1} "
                          f"(word #{msg['global_index'] + 1} of the surah)")
            except websockets.ConnectionClosed:
                pass

        reader = asyncio.create_task(receive())
        per_chunk = int(16000 * CHUNK_MS / 1000) * 2
        for off in range(0, len(pcm), per_chunk):
            await ws.send(pcm[off:off + per_chunk])
            await asyncio.sleep(0)  # let the reader drain
        await ws.send(json.dumps({"type": "stop"}))
        await asyncio.wait_for(reader, timeout=20)

    if not updates:
        print("\nFAIL: no live positions were reported")
        return 1

    last = updates[-1]
    monotonic = all(
        updates[i]["global_index"] > updates[i - 1]["global_index"]
        for i in range(1, len(updates))
    )
    reached_expected_ayah = last["ayah"] == RECITED_UPTO
    print(f"\n{len(updates)} live positions over {duration:.1f}s of audio")
    print(f"  strictly forward-moving : {monotonic}")
    print(f"  finished on ayah        : {last['ayah']} (recited up to {RECITED_UPTO})")

    ok = monotonic and reached_expected_ayah
    print("\nPASS: the highlight tracks the recitation word by word" if ok else "\nFAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
