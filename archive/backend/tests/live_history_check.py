"""Live check that a recitation's per-word verdicts actually survive the
session -- the thing the whole progress side of the app is built on.

Before word-level results were stored, a session kept only the whole-clip rule
classifier's three verdicts. That had visible consequences: the stored accuracy
could only be 0/33/67/100 while the results screen showed the real per-word
score, history claimed "no errors detected" for every past session, and the
practice plan ranked rules the per-word analysis never fed.

This analyses a real recitation, then reads it back through the same endpoints
the app uses and asserts the numbers agree.

Run with the backend up:  python tests/live_history_check.py
"""
import io
import re
import sys
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

SURAH = 1
FROM_AYAH, TO_AYAH = 2, 4   # a deliberate mid-surah range, not the whole surah


def get_id_token() -> str:
    if not firebase_admin._apps:
        firebase_admin.initialize_app(credentials.Certificate(str(BACKEND_DIR / "serviceAccountKey.json")))
    users = list(fb_auth.list_users().iterate_all())
    user = next((u for u in users if u.email and "mustafa" in u.email.lower()), users[0])
    api_key = re.search(
        r"apiKey:\s*'([^']+)'",
        (FRONTEND_DIR / "lib" / "firebase_options.dart").read_text(encoding="utf-8"),
    ).group(1)
    resp = httpx.post(
        f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key={api_key}",
        json={"token": fb_auth.create_custom_token(user.uid).decode(), "returnSecureToken": True},
        timeout=30,
    )
    resp.raise_for_status()
    return resp.json()["idToken"]


def build_clip() -> bytes:
    chunks = []
    for ayah in range(FROM_AYAH, TO_AYAH + 1):
        y, _ = librosa.load(str(RECIT_DIR / f"{SURAH:03d}{ayah:03d}.mp3"), sr=16000, mono=True)
        chunks += [y, np.zeros(int(0.3 * 16000), dtype=np.float32)]
    buf = io.BytesIO()
    sf.write(buf, np.concatenate(chunks), 16000, format="WAV")
    return buf.getvalue()


def main() -> int:
    token = get_id_token()
    auth = {"Authorization": f"Bearer {token}"}
    ok = True

    print(f"analysing surah {SURAH} ayahs {FROM_AYAH}-{TO_AYAH} (a range, not the whole surah)\n")
    r = httpx.post(
        f"{BASE_URL}/api/v1/sessions/analyze_word_level",
        headers=auth,
        files={"audio": ("recitation.wav", build_clip(), "audio/wav")},
        data={"surah_number": SURAH, "from_ayah": FROM_AYAH, "to_ayah": TO_AYAH},
        timeout=180,
    )
    r.raise_for_status()
    analysis = r.json()
    print(f"  session_id     = {analysis['session_id']}")
    print(f"  accuracy_score = {analysis['accuracy_score']:.1%}")
    print(f"  words          = {analysis['words_correct']}/{analysis['words_recited']} correct, "
          f"{analysis['total_words']} in range")
    print(f"  mistake_counts = { {k: v for k, v in analysis['mistake_counts'].items() if v} or 'none'}")

    if analysis.get("session_id") is None:
        print("  FAIL: the analysis did not create a session")
        return 1
    # Only the requested range should be scored at all.
    ayahs_seen = {w["ayah_number"] for w in analysis["words"]}
    if not ayahs_seen <= set(range(FROM_AYAH, TO_AYAH + 1)):
        print(f"  FAIL: range ignored, saw ayahs {sorted(ayahs_seen)}")
        ok = False

    print("\nreading it back from history (GET /sessions)")
    r = httpx.get(f"{BASE_URL}/api/v1/sessions", headers=auth, timeout=60)
    r.raise_for_status()
    stored = next(
        (s for s in r.json()["sessions"] if s["session_id"] == analysis["session_id"]), None
    )
    if stored is None:
        print("  FAIL: session not found in history")
        return 1

    print(f"  accuracyScore  = {stored['accuracyScore']:.1%}")
    print(f"  wordsRecited   = {stored['wordsRecited']} / totalWords {stored['totalWords']}")
    print(f"  mistakes kept  = {len(stored['mistakes'])}")
    print(f"  createdAt      = {stored['createdAt']}")

    # The number shown on the results screen and the number stored in history
    # used to be two different measurements entirely.
    if abs(stored["accuracyScore"] - analysis["accuracy_score"]) > 1e-6:
        print("  FAIL: stored accuracy differs from the analysed accuracy")
        ok = False
    if len(stored["mistakes"]) != analysis["words_recited"] - analysis["words_correct"]:
        print("  FAIL: stored mistake count doesn't match the analysis")
        ok = False
    if not isinstance(stored["createdAt"], str):
        print("  FAIL: createdAt is not a parseable string")
        ok = False

    print("\nderived views")
    r = httpx.get(f"{BASE_URL}/api/v1/progress", headers=auth, timeout=60)
    r.raise_for_status()
    mastery = r.json()["rule_mastery"]
    print(f"  rule_mastery   = {mastery}")
    if mastery and not any("Madd" in k or "Ghunnah" in k or "Makhraj" in k or "Shaddah" in k
                           for k in mastery):
        print("  FAIL: mastery still reported against the old QDAT rule names")
        ok = False

    r = httpx.get(f"{BASE_URL}/api/v1/practice-plan", headers=auth, timeout=60)
    r.raise_for_status()
    plan = r.json()
    print(f"  plan_type      = {plan['plan_type']}")
    for rec in plan["recommendations"][:3]:
        words = ", ".join(e["word"] for e in rec.get("examples", []))
        print(f"    {rec['tajweed_rule']}: {rec['reason']}" + (f"  [{words}]" if words else ""))

    print("\nPASS" if ok else "\nFAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
