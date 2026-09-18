"""Re-verify the previously-documented 113/114 over-extension bug through the
actual production HTTP path (POST /api/v1/sessions/analyze_word_level), the
same endpoint the Flutter app calls -- direct analyze_range calls just came
back clean for both surahs, so this checks whether that holds end-to-end too
before concluding the bug is resolved.
"""
import re
import sys
from collections import defaultdict
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

import firebase_admin
import httpx
from firebase_admin import auth as fb_auth
from firebase_admin import credentials

BASE_URL = "http://127.0.0.1:8000"
BACKEND_DIR = Path(__file__).resolve().parent.parent
FRONTEND_DIR = BACKEND_DIR.parent / "frontend"
RECIT_DIR = BACKEND_DIR / "app" / "static" / "recitations"

CASES = [
    ("yasser_ad_dussary", 114),
    ("alafasy", 113),
]


def get_id_token():
    if not firebase_admin._apps:
        firebase_admin.initialize_app(credentials.Certificate(str(BACKEND_DIR / "serviceAccountKey.json")))
    users = list(fb_auth.list_users().iterate_all())
    user = next((u for u in users if u.email and "mustafa" in u.email.lower()), users[0])
    custom_token = fb_auth.create_custom_token(user.uid).decode()
    firebase_options = (FRONTEND_DIR / "lib" / "firebase_options.dart").read_text(encoding="utf-8")
    api_key = re.search(r"apiKey:\s*'([^']+)'", firebase_options).group(1)
    resp = httpx.post(
        f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key={api_key}",
        json={"token": custom_token, "returnSecureToken": True}, timeout=15,
    )
    resp.raise_for_status()
    return resp.json()["idToken"]


def main():
    token = get_id_token()
    print("Got real Firebase ID token OK\n")

    for qari, surah in CASES:
        audio_path = RECIT_DIR / qari / f"{surah:03d}001.mp3"
        r = httpx.post(
            f"{BASE_URL}/api/v1/sessions/analyze_word_level",
            headers={"Authorization": f"Bearer {token}"},
            files={"audio": ("recitation.mp3", audio_path.read_bytes(), "audio/mpeg")},
            data={"surah_number": surah, "from_ayah": 1, "qari_id": qari},
            timeout=120,
        )
        print(f"=== {qari} surah {surah}, ayah 1 only, whole-surah range requested ===")
        print(f"POST -> {r.status_code}")
        r.raise_for_status()
        body = r.json()
        print(f"  reached_ayah   = {body['reached_ayah']}")
        print(f"  words_recited  = {body['words_recited']}")
        print(f"  words_correct  = {body['words_correct']}")

        per_ayah = defaultdict(lambda: [0, 0])
        for w in body["words"]:
            if w["recited"]:
                per_ayah[w["ayah_number"]][0] += 1
                per_ayah[w["ayah_number"]][1] += 1 if w["flagged"] else 0
        for ayah in sorted(per_ayah):
            total, flagged = per_ayah[ayah]
            print(f"    ayah {ayah}: {total} recited, {flagged} flagged")

        fabricated = sum(v[0] for a, v in per_ayah.items() if a > 1)
        print(f"  fabricated_beyond_ayah1 = {fabricated}")
        print(f"  {'PASS' if body['reached_ayah'] == 1 and fabricated == 0 else 'FAIL'}\n")


if __name__ == "__main__":
    main()
