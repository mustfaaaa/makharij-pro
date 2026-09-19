# MakharijPro AI — Backend (Track B)

FastAPI service behind the MakharijPro app: word-level recitation analysis (the Quran-Lab zipformer), live feedback, sessions and progress, the Rattil Qari library, and the per-word Tajweed reference.

**Model v1 (the Track A clip-level CNN) has been removed.** It was loaded at every startup and served `/api/v1/analyze`, but the app never called that endpoint, and measured on QDAT's test split the saved file does not reproduce its own model card — it answers "correct" to almost every clip (0 of 49 ghunnah mistakes caught, against the card's 47). See `ml/eval/results/drill_model_comparison.json` and the commit that recorded it. The model, its card and its serving code are in `archive/`.

## Setup

Tested on Python 3.12. (TensorFlow is no longer a dependency — it was only needed for model v1.)

```bash
py -3.12 -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
```

## Run

```bash
uvicorn app.main:app --reload --port 8000
```

Then visit `http://localhost:8000/docs` for interactive API docs.

## Firebase setup (required for `/api/v1/sessions*` — only you can do this)

Auth verification and Firestore writes need a **service account key**, which only the Firebase
project owner can generate — I can't create this on your behalf.

1. Go to the [Firebase Console](https://console.firebase.google.com/) → your `makharijpro-ai-9606e`
   project → gear icon → **Project Settings** → **Service Accounts** tab.
2. Click **Generate new private key** → confirm. A JSON file downloads.
3. Save it as `backend/serviceAccountKey.json` (already in `.gitignore` — **never commit this
   file**, it's a full-access credential to your Firebase project).
4. Restart the server. You'll see `Firebase Admin initialized for project makharijpro-ai-9606e`
   instead of the "not initialized" warning.

Until you do this, the public endpoints (Rattil, the Tajweed reference) keep working — only
`/api/v1/sessions*` return `503` with a message pointing back here.

## Endpoints

- `GET /health` — liveness check.
- **Removed:** model v1's clip-level endpoints (POST /api/v1/analyze and GET /api/v1/model-info).
  No caller in the app, and the model behind them was not discriminating — see the top of this file.
- **Removed:** the clip-level three-rule session endpoint (POST /api/v1/sessions/analyze).
  It scored a whole recording against three rules as "a stand-in until word-level detection
  exists" — word-level detection exists, and `POST /api/v1/sessions/analyze_word_level` (below)
  replaced it. The route was deleted; this entry stayed behind describing it as live until
  `tests/test_documented_routes_exist.py` was written. Removed endpoints are named in prose, not
  in the backticked `METHOD /path` notation the live ones use, so that test can tell them apart.
- `GET /api/v1/sessions` — the signed-in user's session history, most recent first (FR-13/UC-5,
  feeds the progress dashboard).
- `POST /api/v1/sessions/{session_id}/reattempt` — FR-8/BR-5 self-correction, **at word
  granularity**. The reciter re-records either the whole passage or, with `ayah_number` (optionally
  plus `word_index`), the single place they want another go at. Only words the session already
  flagged can change: a word it called correct keeps that verdict even if the new take scores it
  worse, so trying again can never cost you a word you had already got right. Bumps `attemptCounts`
  and sets `hadMultipleAttempts` for the re-evaluated words, and recomputes `mistakes`,
  `mistakeCounts` and `accuracyScore`. `hadMultipleAttempts` stays `true` even after a successful
  correction, matching BR-5's intent that such items still count as weak areas for the practice
  plan (FR-14). The session's per-word phoneme record (`words`) is deliberately *not* rewritten —
  that is the evidence the correction loop turns into ML labels, and a first attempt that was
  wrongly flagged is the case most worth keeping. Each re-attempt is appended to `reattempts`.
  Pinned by `tests/test_reattempt.py` (15 tests).
- `GET /api/v1/progress` — FR-13: `total_sessions`, `avg_score`, `day_streak` (consecutive days
  with at least one session, UTC calendar date — no per-user timezone yet, documented
  simplification), and `daily_scores` (last 30 active days, chart-ready for the dashboard).
- `GET /api/v1/practice-plan` — FR-14/Algorithm 6.5, at rule-granularity (no per-ayah error
  localization exists yet): with fewer than 3 sessions, returns a generic "practice everything"
  beginner plan; otherwise ranks the 3 rules by how often each was flagged incorrect plus how
  often it needed multiple attempts (BR-4), not fabricated ayah-specific suggestions the model
  can't actually justify.
- `GET /api/v1/rattil/qaris` — the 3 available Qaris for the selector (FR-16), no auth required.
- `GET /api/v1/rattil/recitation?qari_id=...&surah=...&ayah_start=...&ayah_end=...` — playable
  clip URLs for a surah or ayah range (FR-17). Omit `ayah_start`/`ayah_end` for the whole surah.
  Unknown qari/surah/ayah returns a `404`/`400` listing what IS available (REL-3), not a bare error.

## Rattil AI repository

**Real audio, not placeholders** — 75 clips (5 short, commonly-practiced surahs: Al-Fatiha,
Al-Kawthar, Al-Ikhlas, Al-Falaq, An-Nas — × the 3 SRS-named Qaris: Mishary Rashid Alafasy, Abdul
Rahman As-Sudais, Yasser Al-Dosari), sourced from `Buraaq/quran-md-ayahs` on Hugging Face and
verified playable. Built by [`build_rattil_repository.py`](../archive/backend/tests/build_rattil_repository.py) (one-time script, now archived)
— re-run it to add more surahs (extend `SURAHS` and `ml`-style `SURAH_AYAH_COUNTS`/`SURAH_NAMES` in
`app/quran_metadata.py`) or more Qaris (the source dataset has 30 total, see its reciter list).

**Served from local disk, not Firebase Cloud Storage** — a deliberate deviation from the SDD's
original design (SI-4/OE-7 specify Cloud Storage). As of a February 2026 Google policy change,
Firebase Storage requires a linked billing account (Blaze plan) just to provision a bucket at all,
regardless of usage — confirmed by checking this project's actual bucket list via the GCS API
(zero buckets exist). Given the real cost for this repository's size would be ~$0 (75 files, 4.1MB
total, far under the free quota) but a card is still mandatory, and given explicit reluctance to
link one for a prototype, files are served instead via a FastAPI static mount at `/media/...`.
**Migration path when ready**: Firebase Storage becomes worthwhile once the backend is deployed
somewhere that needs billing set up anyway; at that point, swap `quran_metadata`'s local path
lookup for a Storage-signed-URL lookup in `rattil.py` — the retrieval endpoint's response shape
doesn't need to change, just where the URL points.

**Rattil's assistant** — `POST /api/v1/rattil/chat`, signed-in. The app sends a message here only
when its own parser cannot read it, so open-ended questions ("how do I fix my ghunnah?") get an
answer while every request the parser handles stays instant, free and offline. Backed by Google
Gemini's free tier over REST (`app/rattil_assistant.py`), enabled by `GEMINI_API_KEY` in
`backend/.env` (see `.env.example`; the file is git-ignored) and off without it — the endpoint then
returns 503 and the app keeps its parser's reply. Body `{"message", "history"}`, reply
`{"reply", "actions"}` where an action is `{"type": "play", "surah", "ayah_start", "ayah_end",
"qari_id"}` or `{"type": "rule", "rule"}`. The model never supplies Quranic text: it can only ask the
app to play a verified recitation or show its library entry, and vocalised Arabic runs in its
reply are removed before they reach the screen. Nothing identifying is sent — free-tier content is
used by Google to improve its products. Pinned by `tests/test_rattil_assistant.py` (36 tests).

**FR-19 request parsing** is built, client-side, in `frontend/lib/services/rattil_request_parser.dart`
and pinned by 229 tests: named passages ("Ayat al-Kursi" → 2:255), colon references (`18:1-10`),
a surah plus ayat ("baqarah 255", "kahf 1 se 10 tak"), first/last N ayat, surah names in common
spellings and in Arabic, and reciters by the names people use. It is rule-based, not a language
model: it covers the phrasings it was written for, and says so rather than guessing when it cannot
read a request.

**FR-18 playback** is built, in the player on the Ask AI screen: play/pause, previous/next ayah,
play again, slow (0.75x), and a three-state end-of-clip mode — stop, play on through the passage,
or loop this ayah (`lib/models/after_clip.dart`). This paragraph previously listed all of FR-18 as
"not yet built" while slow and next/previous had been shipped for some time.

## Status

Whole-clip classification only, matching what the model was actually trained on (see
`model_card.json`'s `known_limitations`). Not yet real-time per-word streaming — that needs a
separate architectural extension, tracked as future work, not a gap in this endpoint.

## Progress log

| Item | Status |
|---|---|
| FastAPI skeleton + model loading at startup | **done, verified** |
| Canonical feature extraction ported from `ml/notebooks/02_qdat_manifest.ipynb` §7, resampling added for non-16kHz uploads | **done, verified** (16kHz and 44.1kHz both tested) |
| Local smoke test (`archive/backend/tests/smoke_test.py`) + live HTTP test (`archive/backend/tests/make_test_wav.py` + curl) — superseded by the pytest suite | **done, passed** |
| Real-audio spot check against 3 held-out QDAT test clips with known labels | **done** — see "Real-audio validation" below |
| Stereo-audio robustness fix (`predict_from_waveform` now downmixes defensively) | **done, verified no prediction change** |
| Firebase Auth verification (`app/auth.py`) | **done, verified end-to-end with a real token** |
| Firestore session/history persistence (`app/firestore_service.py`, `/api/v1/sessions*`) | **done, verified end-to-end** — analyze → save → read-back all confirmed working against the real `makharijpro-ai-9606e` project |
| Self-correction / re-attempt endpoint (`POST /api/v1/sessions/{id}/reattempt`, FR-8/BR-5) | **done, at word granularity** — pinned by `tests/test_reattempt.py`. This row previously claimed "done, verified end-to-end" while no such route existed in the code: the rule-granularity version described here was lost in the move to word-level analysis and the row was never updated. Rebuilt per-word, which is what the requirement wanted in the first place. Frontend: "Try again" on the flagged-word card (`try_word_again_button.dart`), beside "I said it right" — one overrules the verdict, the other offers to settle it. The microphone path itself is untested at runtime (no device in the build environment); the response parsing is pinned by `frontend/test/reattempt_outcome_test.dart`. |
| Progress stats (`GET /api/v1/progress`, FR-13) | **done, verified end-to-end** — day streak, avg score, and daily chart data all confirmed correct against a 4-session/3-day test history |
| Practice plan (`GET /api/v1/practice-plan`, FR-14) | **done, verified end-to-end** — beginner-plan fallback and personalized ranking both confirmed correct |
| Rattil AI repository + retrieval (`GET /api/v1/rattil/qaris`, `GET /api/v1/rattil/recitation`) | **done, verified end-to-end** — 258 real clips (3 Qaris × 15 surahs: 1, 101-114), served from local disk (Firebase Storage needs a billing account now, see "Rattil AI repository" below). Surah 100 deliberately excluded — the source dataset is missing ayahs 1-2 for all three reciters there, a real gap, not a bug. Qaris list + recitation retrieval + all error cases tested against real HTTP, a served clip confirmed to decode as valid playable audio (MPEG layer III). |
| Achievements (`GET /api/v1/achievements`) | **done, verified with fake session data** — every badge derived from real session history (total sessions, day streak, best score, distinct surahs); "Tajweed Scholar" honestly reported locked (no read-tracking exists yet for the Rules library) |
| Notifications (`GET /api/v1/notifications`) | **done, verified with fake session data** — a real derived status feed (streak, achievement unlocks, top practice-plan focus), not a stored/triggered system; no push infrastructure exists |
| Activity heatmap + rule mastery (added to `GET /api/v1/progress`) | **done, verified with fake session data** — 10-week session-count grid and rolling per-rule correct-rate, both computed from existing session documents, no new schema |

## Track B status: core scope complete

Everything from the original 60% iteration checklist is now done and verified against the real
model, a real Firebase project, and real audio/session data — not just scaffolded. Frontend
integration (Track C) is now wired end-to-end too: Practice Plan, Ask AI/Rattil, Progress
Dashboard, Achievements, Notifications, and the Tajweed Rules library all call these real
endpoints instead of dummy data. Rattil AI's request parsing (FR-19) is rule-based — see above.

## Real-audio validation

Ran 3 real, held-out QDAT test clips (never seen in training) through the backend, not synthetic
noise: `archive/backend/tests/fetch_real_test_clips.py` downloads them from `obadx/qdat` by row index/id with
known ground truth. Result: the "correct" clip matched on all 3 rules with high confidence
(0.87-1.00); two "incorrect" clips were both misclassified as correct. This isn't a backend bug —
verified identical predictions across three different decode paths (ruling out a pipeline issue) —
it's the model's own documented real-error-recall limits (60.2% / 95.9% / 67.8% by rule, see
`model_card.json`) showing up on a small, honest sample. Along the way this did surface one real
bug, now fixed: `predict_from_waveform` crashed on stereo audio (QDAT's source files are stereo
even though training's decode path auto-downmixed) instead of downmixing defensively.

## Environment note

This machine only had Python 3.14 installed, which has no TensorFlow wheel yet. Installed Python
3.12.10 via `py install 3.12` and built the venv against that — matches the exact Python version
(3.12.13) and TensorFlow version (2.20.0) the model was trained with on Kaggle, so inference
behavior is reproducible.

## Phoneme model

Word-level analysis and live word tracking both run on the Quran-Lab streaming
zipformer. **The weights are committed to this repository** at
`models_cache/quran-lab-zipformer/` — a fresh clone needs no model download and
no Hugging Face account.

Source: [`Quran-Lab/zipformer_p-arabic-v3`](https://huggingface.co/Quran-Lab/zipformer_p-arabic-v3),
under the Quran-Lab No-Profit License v1.2, retained beside the weights at
`models_cache/quran-lab-zipformer/LICENSE`. That license forbids charging for
the Work or for any feature it powers, and requires every Derivative to carry
the same terms — see the License section of the root [README](../README.md).

Re-downloading from the source (only needed to update the model) requires an
account, because the repository is gated: anonymous requests get a 401, not a
404, which is easy to misread as "the file moved".

```
hf auth login
hf download Quran-Lab/zipformer_p-arabic-v3   zipformer_p_arabic_v3.1.int8.onnx tokens.txt ordered_quran_phonemes.json   --local-dir models_cache/quran-lab-zipformer
```

The three files the app loads:

| file | used for |
|---|---|
| `zipformer_p_arabic_v3.1.int8.onnx` | the recognizer itself |
| `tokens.txt` | its token inventory |
| `ordered_quran_phonemes.json` | the expected phoneme sequence per ayah, all 6,236 |

Without them the server still starts, but `POST /api/v1/sessions/analyze_word_level`
and the `/api/v1/sessions/stream` socket return 503 — startup logs
`Phoneme analysis service not available` rather than failing silently.

## Python dependencies

```
pip install -r requirements.txt
```
