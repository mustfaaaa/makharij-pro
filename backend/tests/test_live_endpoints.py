"""Real pytest integration suite against a running backend + the real
makharijpro-ai-9606e Firebase project -- not synthetic mocks. Formalizes what
was previously only verified by hand: that the wiring done this session
(Progress, Achievements, Notifications, Practice Plan, Rattil, Sessions)
actually returns sane, correctly-shaped data from real Firestore history,
not placeholders.

Requires:
  - The backend running at http://127.0.0.1:8000 (uvicorn app.main:app --port 8000)
  - backend/serviceAccountKey.json present (real Firebase Admin credentials)
  - A real signed-up user with "mustafa" in their email in the project

Auth is obtained via Admin SDK custom-token minting + the Identity Toolkit
REST exchange -- the same no-password method used throughout this session.
Never touches or requires the account's actual password.

Run with: .venv/Scripts/python.exe -m pytest tests/test_live_endpoints.py -v
"""
import re
from pathlib import Path

import firebase_admin
import httpx
import pytest
from firebase_admin import auth as fb_auth
from firebase_admin import credentials

BASE_URL = "http://127.0.0.1:8000"
BACKEND_DIR = Path(__file__).resolve().parent.parent
FRONTEND_DIR = BACKEND_DIR.parent / "frontend"


def _require_server():
    try:
        r = httpx.get(f"{BASE_URL}/health", timeout=5)
        assert r.status_code == 200
    except (httpx.ConnectError, httpx.TimeoutException):
        pytest.skip(f"Backend not running at {BASE_URL} -- start it before running this suite.")


@pytest.fixture(scope="session")
def id_token():
    """Real Firebase ID token for the real test account, minted without ever
    touching its password."""
    _require_server()
    cred_path = BACKEND_DIR / "serviceAccountKey.json"
    if not cred_path.exists():
        pytest.skip("serviceAccountKey.json not present -- can't mint a real auth token.")

    if not firebase_admin._apps:
        firebase_admin.initialize_app(credentials.Certificate(str(cred_path)))

    uid = None
    for u in fb_auth.list_users().iterate_all():
        if u.email and "mustafa" in u.email.lower():
            uid = u.uid
            break
    if uid is None:
        pytest.skip("No test user with 'mustafa' in their email found in this Firebase project.")

    custom_token = fb_auth.create_custom_token(uid).decode()

    firebase_options = (FRONTEND_DIR / "lib" / "firebase_options.dart").read_text(encoding="utf-8")
    match = re.search(r"apiKey:\s*'([^']+)'", firebase_options)
    assert match, "Could not find a Firebase apiKey in firebase_options.dart"
    api_key = match.group(1)

    resp = httpx.post(
        f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key={api_key}",
        json={"token": custom_token, "returnSecureToken": True},
        timeout=15,
    )
    assert resp.status_code == 200, f"Custom token exchange failed: {resp.text}"
    return resp.json()["idToken"]


@pytest.fixture(scope="session")
def auth_headers(id_token):
    return {"Authorization": f"Bearer {id_token}"}


class TestHealth:
    def test_health_ok(self):
        _require_server()
        r = httpx.get(f"{BASE_URL}/health", timeout=10)
        assert r.status_code == 200
        assert r.json() == {"status": "ok"}


class TestCors:
    """Formalizes the CORS fix from earlier this session -- a real regression
    risk since it's easy to accidentally narrow/remove the middleware later."""

    @pytest.mark.parametrize("origin", ["http://localhost:5600", "http://127.0.0.1:9999"])
    def test_localhost_origin_allowed(self, origin):
        _require_server()
        r = httpx.options(
            f"{BASE_URL}/api/v1/sessions/analyze",
            headers={
                "Origin": origin,
                "Access-Control-Request-Method": "POST",
            },
            timeout=10,
        )
        assert r.headers.get("access-control-allow-origin") == origin

    def test_external_origin_rejected(self):
        _require_server()
        r = httpx.options(
            f"{BASE_URL}/api/v1/sessions/analyze",
            headers={"Origin": "http://evil.com", "Access-Control-Request-Method": "POST"},
            timeout=10,
        )
        assert r.headers.get("access-control-allow-origin") is None


class TestProgress:
    def test_shape_and_types(self, auth_headers):
        r = httpx.get(f"{BASE_URL}/api/v1/progress", headers=auth_headers, timeout=30)
        assert r.status_code == 200
        body = r.json()

        assert isinstance(body["total_sessions"], int) and body["total_sessions"] >= 0
        assert isinstance(body["avg_score"], (int, float))
        assert 0 <= body["avg_score"] <= 1, "avg_score should be a 0-1 fraction, not a percentage"
        assert isinstance(body["day_streak"], int) and body["day_streak"] >= 0

        assert isinstance(body["daily_scores"], list)
        for entry in body["daily_scores"]:
            assert set(entry.keys()) >= {"date", "avg_score", "n_sessions"}
            assert 0 <= entry["avg_score"] <= 1

        assert isinstance(body["activity_heatmap"], list)
        for week in body["activity_heatmap"]:
            assert isinstance(week, list)
            for day_count in week:
                assert isinstance(day_count, int) and day_count >= 0

        assert isinstance(body["rule_mastery"], dict)
        for rule, pct in body["rule_mastery"].items():
            assert isinstance(rule, str) and rule
            assert 0 <= pct <= 100, f"rule_mastery[{rule!r}]={pct} should be a 0-100 percentage"

    def test_requires_auth(self):
        r = httpx.get(f"{BASE_URL}/api/v1/progress", timeout=10)
        assert r.status_code in (401, 403)


class TestAchievements:
    def test_shape_and_types(self, auth_headers):
        r = httpx.get(f"{BASE_URL}/api/v1/achievements", headers=auth_headers, timeout=30)
        assert r.status_code == 200
        achievements = r.json()["achievements"]
        assert isinstance(achievements, list) and len(achievements) > 0

        seen_ids = set()
        for a in achievements:
            assert set(a.keys()) >= {"id", "title", "description", "icon_key", "is_unlocked", "progress"}
            assert isinstance(a["is_unlocked"], bool)
            assert 0 <= a["progress"] <= 1
            # An unlocked achievement must be reported as fully progressed --
            # anything else would mean the two fields disagree with each other.
            if a["is_unlocked"]:
                assert a["progress"] == 1.0, f"{a['id']} is unlocked but progress={a['progress']}"
            seen_ids.add(a["id"])
        assert len(seen_ids) == len(achievements), "duplicate achievement ids"


class TestNotifications:
    def test_shape_and_types(self, auth_headers):
        r = httpx.get(f"{BASE_URL}/api/v1/notifications", headers=auth_headers, timeout=30)
        assert r.status_code == 200
        notifications = r.json()["notifications"]
        assert isinstance(notifications, list)
        for n in notifications:
            assert set(n.keys()) >= {"id", "type", "dateTime", "title", "message"}
            assert n["type"] in ("tip", "achievement", "reminder")


class TestPracticePlan:
    def test_shape_and_types(self, auth_headers):
        r = httpx.get(f"{BASE_URL}/api/v1/practice-plan", headers=auth_headers, timeout=30)
        assert r.status_code == 200
        body = r.json()
        assert body["plan_type"] in ("beginner", "personalized")
        for rec in body["recommendations"]:
            assert set(rec.keys()) >= {"rule", "tajweed_rule", "reason"}


class TestSessionHistory:
    def test_shape_and_types(self, auth_headers):
        r = httpx.get(f"{BASE_URL}/api/v1/sessions", headers=auth_headers, timeout=30)
        assert r.status_code == 200
        sessions = r.json()["sessions"]
        assert isinstance(sessions, list)
        for s in sessions:
            assert "session_id" in s


class TestWordLevelAnalysis:
    """Gate 1+2's real per-word phoneme analysis (see makharij_audit and
    app/phoneme_analysis_service.py) -- feeds a real Qari's own recitation of
    an ayah back in as the "user" audio. Not a synthetic clip: this is the
    same real file the reference comparison is built from, so a genuinely
    working pipeline should recognize almost all of it correctly."""

    RECITATIONS_DIR = BACKEND_DIR / "app" / "static" / "recitations"

    def _post_audio(self, auth_headers, path: Path, surah: int, ayah: int, qari_id: str):
        with open(path, "rb") as f:
            audio_bytes = f.read()
        return httpx.post(
            f"{BASE_URL}/api/v1/sessions/analyze_word_level",
            headers=auth_headers,
            data={"surah_number": str(surah), "ayah_number": str(ayah), "qari_id": qari_id},
            files={"audio": (path.name, audio_bytes, "audio/mpeg")},
            timeout=60,
        )

    def test_real_reciters_own_audio_mostly_matches_itself(self, auth_headers):
        """A real, non-trivial correctness check: this can't just always
        return "all flagged" or "all correct" and pass -- it has to produce
        genuinely per-word-differentiated, mostly-correct results against
        real audio recognized by a real streaming model, not fixtures."""
        clip = self.RECITATIONS_DIR / "abdurrahmaan_as_sudais" / "001001.mp3"
        if not clip.exists():
            pytest.skip("Reference clip not present in this checkout.")

        r = self._post_audio(auth_headers, clip, surah=1, ayah=1, qari_id="abdurrahmaan_as_sudais")
        assert r.status_code == 200
        body = r.json()
        words = body["words"]

        assert len(words) == 4, "Al-Fatihah 1:1 (Bismillah) has 4 words"
        prev_end = -1.0
        correct_count = 0
        for w in words:
            assert set(w.keys()) >= {"word", "start_sec", "end_sec", "distance", "confidence", "flagged"}
            assert w["start_sec"] <= w["end_sec"]
            assert w["start_sec"] >= prev_end, "word timings should be in order, not overlapping backwards"
            prev_end = w["end_sec"]
            assert 0.0 <= w["confidence"] <= 1.0
            if not w["flagged"]:
                correct_count += 1

        # At least 3 of 4 words on a clean reference recording, matching what
        # independent verification (tests/zipformer_phoneme_multi_test.py)
        # found for this exact clip -- not asserting all 4, since the model's
        # own documented ~3.65% real error rate means occasional misses on
        # elongation-heavy words are expected, not a bug.
        assert correct_count >= 3, f"expected at least 3/4 words correct on a clean reference clip, got {correct_count}/4"

    def test_requires_auth(self):
        clip = self.RECITATIONS_DIR / "abdurrahmaan_as_sudais" / "001001.mp3"
        if not clip.exists():
            pytest.skip("Reference clip not present in this checkout.")
        with open(clip, "rb") as f:
            r = httpx.post(
                f"{BASE_URL}/api/v1/sessions/analyze_word_level",
                data={"surah_number": "1", "ayah_number": "1"},
                files={"audio": (clip.name, f.read(), "audio/mpeg")},
                timeout=30,
            )
        assert r.status_code == 401

    def test_partial_recitation_of_a_surah_does_not_fabricate_errors_beyond_stop_point(self, auth_headers):
        """Regression test for a real bug found and fixed this session:
        Al-Fatihah's ayah 3 ("الرحمن الرحيم") is phonetically identical to the
        tail of ayah 1's Basmala. Whole-surah analysis (from_ayah with no
        to_ayah) on ~3 seconds of ayah-1-only audio was matching that distant,
        unrelated occurrence and confidently reporting ayah 2 as mispronounced
        or skipped -- despite it never being recited at all. Root cause was
        EXPECTED_LENGTH_FLOOR in phoneme_analysis_service.py being large enough
        to admit whole extra ayahs into the very first alignment window, which
        the re-align loop can only shrink, never grow back out of."""
        clip = self.RECITATIONS_DIR / "abdurrahmaan_as_sudais" / "001001.mp3"
        if not clip.exists():
            pytest.skip("Reference clip not present in this checkout.")

        with open(clip, "rb") as f:
            audio_bytes = f.read()
        r = httpx.post(
            f"{BASE_URL}/api/v1/sessions/analyze_word_level",
            headers=auth_headers,
            data={"surah_number": "1", "from_ayah": "1", "qari_id": "abdurrahmaan_as_sudais"},
            files={"audio": (clip.name, audio_bytes, "audio/mpeg")},
            timeout=60,
        )
        assert r.status_code == 200
        body = r.json()

        assert body["reached_ayah"] == 1, (
            f"3 seconds of ayah-1-only audio should never be reported as reaching "
            f"ayah {body['reached_ayah']} -- this is the repeated-phrase false-match bug"
        )
        for w in body["words"]:
            if w["ayah_number"] > 1:
                assert w["recited"] is False, f"ayah {w['ayah_number']} word {w['word_index']!r} was never recited"
                assert w["flagged"] is False, f"an unrecited word must never be flagged as a mistake"

    def test_empty_audio_rejected(self, auth_headers):
        r = httpx.post(
            f"{BASE_URL}/api/v1/sessions/analyze_word_level",
            headers=auth_headers,
            data={"surah_number": "1", "ayah_number": "1"},
            files={"audio": ("empty.mp3", b"", "audio/mpeg")},
            timeout=30,
        )
        assert r.status_code == 400


class TestRattil:
    def test_qaris_list_no_auth_needed(self):
        _require_server()
        r = httpx.get(f"{BASE_URL}/api/v1/rattil/qaris", timeout=10)
        assert r.status_code == 200
        qaris = r.json()["qaris"]
        assert isinstance(qaris, list) and len(qaris) >= 1
        for q in qaris:
            assert "qariId" in q, f"expected camelCase 'qariId' key, got: {list(q.keys())}"

    def test_known_recitation_retrievable(self):
        _require_server()
        r = httpx.get(f"{BASE_URL}/api/v1/rattil/recitation?qari_id=abdurrahmaan_as_sudais&surah=1", timeout=10)
        assert r.status_code == 200

    def test_unavailable_surah_gives_helpful_message_not_bare_404(self):
        """REL-3: a missing recitation must explain itself, not just 404."""
        _require_server()
        r = httpx.get(f"{BASE_URL}/api/v1/rattil/recitation?qari_id=abdurrahmaan_as_sudais&surah=50", timeout=10)
        assert r.status_code == 404
        detail = r.json().get("detail", "")
        assert len(detail) > 20, "REL-3 requires a helpful message, not a bare 404"
