"""Verify the Al-'Asr (surah 103) word-truncation fix through the real
production HTTP endpoint, matching the rigor already applied to the 113/114
over-extension check. Ayah 1's actual word was a perfect, exact-match
recitation that the length-budget trim was discarding before comparison --
see the EXPECTED_LENGTH_FLOOR fix in phoneme_analysis_service.py.
"""
import re
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

import firebase_admin
import httpx
from firebase_admin import auth as fb_auth
from firebase_admin import credentials

BACKEND_DIR = Path(__file__).resolve().parent.parent
FRONTEND_DIR = BACKEND_DIR.parent / "frontend"

if not firebase_admin._apps:
    firebase_admin.initialize_app(credentials.Certificate(str(BACKEND_DIR / "serviceAccountKey.json")))
user = next(u for u in fb_auth.list_users().iterate_all() if u.email and "mustafa" in u.email.lower())
custom_token = fb_auth.create_custom_token(user.uid).decode()
api_key = re.search(
    r"apiKey:\s*'([^']+)'", (FRONTEND_DIR / "lib" / "firebase_options.dart").read_text(encoding="utf-8")
).group(1)
token = httpx.post(
    f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key={api_key}",
    json={"token": custom_token, "returnSecureToken": True}, timeout=15,
).json()["idToken"]

audio_path = BACKEND_DIR / "app" / "static" / "recitations" / "abdurrahmaan_as_sudais" / "103001.mp3"
r = httpx.post(
    "http://127.0.0.1:8000/api/v1/sessions/analyze_word_level",
    headers={"Authorization": f"Bearer {token}"},
    files={"audio": ("r.mp3", audio_path.read_bytes(), "audio/mpeg")},
    data={"surah_number": 103, "from_ayah": 1, "qari_id": "abdurrahmaan_as_sudais"},
    timeout=120,
)
print(r.status_code)
body = r.json()
print("reached_ayah", body["reached_ayah"], "words_recited", body["words_recited"], "words_correct", body["words_correct"])
for w in body["words"][:6]:
    print(w["ayah_number"], w["word_index"], w["word"], "recited=", w["recited"], "flagged=", w["flagged"])
