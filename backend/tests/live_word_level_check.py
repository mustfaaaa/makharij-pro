"""One-shot live check of POST /api/v1/sessions/analyze_word_level against a
running server, using real auth (Admin SDK custom token -> Identity Toolkit
exchange, no password touched).

Exercises the whole-surah range API the way the app actually calls it: one
continuous recitation that stops partway through the surah. A correct result
must (a) analyze every ayah the recording reached, not just the first one,
(b) report where the recitation stopped, and (c) NOT flag the ayahs after that
as mistakes. Reference-Qari audio is used as the input, so any flagged word is
by definition a false positive.

Run with the backend up:  python tests/live_word_level_check.py
"""
import io
import re
import sys
from collections import defaultdict
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

import firebase_admin
import httpx
import librosa
import numpy as np
import soundfile as sf
from firebase_admin import auth as fb_auth
from firebase_admin import credentials

BASE_URL = "http://127.0.0.1:8000"
BACKEND_DIR = Path(__file__).resolve().parent.parent
FRONTEND_DIR = BACKEND_DIR.parent / "frontend"
RECIT_DIR = BACKEND_DIR / "app" / "static" / "recitations" / "abdurrahmaan_as_sudais"

SURAH = 1          # Al-Fatiha
SURAH_AYAHS = 7
RECITED_UPTO = 5   # stop partway on purpose -- ayahs 6-7 must come back "not recited"


def get_id_token():
    cred_path = BACKEND_DIR / "serviceAccountKey.json"
    if not firebase_admin._apps:
        firebase_admin.initialize_app(credentials.Certificate(str(cred_path)))

    users = list(fb_auth.list_users().iterate_all())
    if not users:
        raise RuntimeError("No Firebase users exist to mint a token for")
    # Prefer a recognizable test account, but any real user works -- the token
    # only needs to be valid, the endpoint doesn't care who it belongs to.
    user = next((u for u in users if u.email and "mustafa" in u.email.lower()), users[0])

    custom_token = fb_auth.create_custom_token(user.uid).decode()
    firebase_options = (FRONTEND_DIR / "lib" / "firebase_options.dart").read_text(encoding="utf-8")
    api_key = re.search(r"apiKey:\s*'([^']+)'", firebase_options).group(1)

    resp = httpx.post(
        f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key={api_key}",
        json={"token": custom_token, "returnSecureToken": True},
        timeout=15,
    )
    resp.raise_for_status()
    return resp.json()["idToken"], user.email


def build_clip(upto_ayah: int) -> tuple[bytes, float]:
    """Splice the reference Qari's per-ayah files into one continuous recitation."""
    chunks = []
    for ayah in range(1, upto_ayah + 1):
        y, _ = librosa.load(str(RECIT_DIR / f"{SURAH:03d}{ayah:03d}.mp3"), sr=16000, mono=True)
        chunks += [y, np.zeros(int(0.3 * 16000), dtype=np.float32)]
    full = np.concatenate(chunks)
    buf = io.BytesIO()
    sf.write(buf, full, 16000, format="WAV")
    return buf.getvalue(), len(full) / 16000


def main():
    r = httpx.get(f"{BASE_URL}/health", timeout=5)
    print(f"/health -> {r.status_code} {r.json()}")

    token, email = get_id_token()
    print(f"Got real Firebase ID token OK (uid of {email})")

    audio, duration = build_clip(RECITED_UPTO)
    print(f"\nUploading {duration:.0f}s of recitation: surah {SURAH} ayahs 1-{RECITED_UPTO} "
          f"(surah has {SURAH_AYAHS}), asking the server to score the WHOLE surah")

    r = httpx.post(
        f"{BASE_URL}/api/v1/sessions/analyze_word_level",
        headers={"Authorization": f"Bearer {token}"},
        files={"audio": ("recitation.wav", audio, "audio/wav")},
        data={"surah_number": SURAH, "from_ayah": 1, "qari_id": "abdurrahmaan_as_sudais"},
        timeout=120,
    )
    print(f"\nPOST /api/v1/sessions/analyze_word_level -> {r.status_code}")
    r.raise_for_status()
    body = r.json()

    print(f"  reached_ayah      = {body['reached_ayah']} (word {body['reached_word_index'] + 1})")
    print(f"  words_recited     = {body['words_recited']} of {len(body['words'])} in the surah")
    print(f"  words_correct     = {body['words_correct']}")
    print(f"  accuracy_score    = {body['accuracy_score']:.1%}")

    per_ayah = defaultdict(lambda: [0, 0, 0])
    for w in body["words"]:
        row = per_ayah[w["ayah_number"]]
        row[0] += 1
        row[1] += 1 if w["recited"] else 0
        row[2] += 1 if w["flagged"] else 0

    print("\n  per ayah:")
    for ayah in sorted(per_ayah):
        total, recited, flagged = per_ayah[ayah]
        state = "not recited" if recited == 0 else f"{recited}/{total} recited, {flagged} flagged"
        print(f"    ayah {ayah}: {state}")

    flagged_words = [w for w in body["words"] if w["flagged"]]
    if flagged_words:
        print("\n  flagged words (all false positives -- this is reference-Qari audio):")
        for w in flagged_words:
            print(f"    {w['ayah_number']}:{w['word_index'] + 1} {w['word']} "
                  f"[{w['error_type']}] {w['explanation']}")
    else:
        print("\n  no words flagged on reference audio (0 false positives)")

    ok = (
        body["reached_ayah"] == RECITED_UPTO
        and all(per_ayah[a][1] == 0 for a in range(RECITED_UPTO + 1, SURAH_AYAHS + 1))
        and body["words_recited"] > 4  # more than just the Basmala
    )
    print(f"\n{'PASS' if ok else 'FAIL'}: whole-surah analysis with a correct stop point")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
