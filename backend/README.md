# MakharijPro AI — Backend (Track B)

FastAPI service wrapping the Track A model ([`ml/models/makharijpro_tajweed_model_v1/`](../ml/models/makharijpro_tajweed_model_v1/)).

## Setup

Requires Python 3.12 — TensorFlow 2.20 (what the model was trained with) has no wheel for newer
Python versions yet.

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

Until you do this, `/api/v1/analyze` (stateless inference) keeps working fine — only
`/api/v1/sessions*` return `503` with a message pointing back here.

## Endpoints

- `GET /health` — liveness check.
- `POST /api/v1/analyze` — multipart upload, field name `audio`, no auth required. Returns
  per-rule (Separate Madd, Ghunnah, Ikhfa) correct/incorrect + confidence, using the calibrated
  thresholds from the model card. Stateless — nothing is saved.
- `GET /api/v1/model-info` — model metadata, task list, thresholds, and known limitations (surface
  these to the frontend/product team — don't let "the model works" get overclaimed).
- `POST /api/v1/sessions/analyze` — same as `/analyze`, but requires
  `Authorization: Bearer <firebase_id_token>` and saves the result to
  `users/{uid}/sessions/{sessionId}` in Firestore (FR-12). Optional form fields `surah_number`,
  `ayah_range` to tag which passage was recited. Returns an `accuracy_score` (BR-3: proportion of
  the 3 rules marked correct — a clip-level stand-in until word-level detection exists).
- `GET /api/v1/sessions` — the signed-in user's session history, most recent first (FR-13/UC-5,
  feeds the progress dashboard).
- `POST /api/v1/sessions/{session_id}/reattempt` — FR-8/BR-5 self-correction, **adapted to
  rule-granularity**: the model has no word-level detection yet, so a "re-attempt" resubmits a new
  recording of the same passage, and only rules that were previously flagged incorrect in that
  session get updated from the new result — rules already correct are left untouched, even if the
  new clip's fresh analysis of them differs. Bumps `attemptCounts` and sets `hadMultipleAttempts`
  only for the re-evaluated rule(s), and recomputes `accuracyScore`. `hadMultipleAttempts` stays
  `true` even after a successful correction, matching BR-5's intent that such items still count as
  weak areas for the future practice plan (FR-14).
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
verified playable. Built by [`tests/build_rattil_repository.py`](tests/build_rattil_repository.py)
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

**Not yet built**: natural-language request parsing (FR-19 — "give me Ayat al-Kursi" instead of
explicit surah/ayah numbers) and playback commands (FR-18 — repeat/slow/continue). Both are layers
on top of `/rattil/recitation` that make more sense to build once Track C's chat UI exists to
actually drive them, rather than speculatively now.

## Status

Whole-clip classification only, matching what the model was actually trained on (see
`model_card.json`'s `known_limitations`). Not yet real-time per-word streaming — that needs a
separate architectural extension, tracked as future work, not a gap in this endpoint.

## Progress log

| Item | Status |
|---|---|
| FastAPI skeleton + model loading at startup | **done, verified** |
| `/api/v1/analyze` — audio in, per-rule verdict out | **done, verified over real HTTP** |
| `/api/v1/model-info` — surfaces thresholds + known limitations | **done, verified** |
| Canonical feature extraction ported from `ml/notebooks/02_qdat_manifest.ipynb` §7, resampling added for non-16kHz uploads | **done, verified** (16kHz and 44.1kHz both tested) |
| Local smoke test (`tests/smoke_test.py`) + live HTTP test (`tests/make_test_wav.py` + curl) | **done, passed** |
| Real-audio spot check against 3 held-out QDAT test clips with known labels | **done** — see "Real-audio validation" below |
| Stereo-audio robustness fix (`predict_from_waveform` now downmixes defensively) | **done, verified no prediction change** |
| Firebase Auth verification (`app/auth.py`) | **done, verified end-to-end with a real token** |
| Firestore session/history persistence (`app/firestore_service.py`, `/api/v1/sessions*`) | **done, verified end-to-end** — analyze → save → read-back all confirmed working against the real `makharijpro-ai-9606e` project |
| Self-correction / re-attempt endpoint (`POST /api/v1/sessions/{id}/reattempt`, FR-8/BR-5) | **done, verified end-to-end** — adapted to rule-granularity (see below); confirmed only the previously-incorrect rule gets updated, already-correct rules are untouched, attempt counts and accuracy score recompute correctly |
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
endpoints instead of dummy data. Remaining work: Rattil AI's full natural-language request parsing
(FR-19 — the chat UI does simple name/number matching today, not free-form NLU) and richer
playback commands beyond repeat/slow/next/previous (FR-18).

## Real-audio validation

Ran 3 real, held-out QDAT test clips (never seen in training) through the backend, not synthetic
noise: `tests/fetch_real_test_clips.py` downloads them from `obadx/qdat` by row index/id with
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
zipformer. Its weights are **not** in this repository: the checkpoint alone is
69 MB, and git would carry it in every clone forever. Fetch it into
`backend/models_cache/quran-lab-zipformer/` from
[obadx/quran-phonetic-asr](https://huggingface.co/obadx) — the files the app
loads are:

| file | used for |
|---|---|
| `zipformer_p_arabic_v3.1.int8.onnx` | the recognizer itself |
| `tokens.txt` | its token inventory |
| `ordered_quran_phonemes.json` | the expected phoneme sequence per ayah, all 6,236 |

Without them the server still starts, but `POST /api/v1/sessions/analyze_word_level`
and the `/api/v1/sessions/stream` socket return 503 — startup logs
`Phoneme analysis service not available` rather than failing silently.

Install the Python side with:

```
pip install -r requirements.txt
```
