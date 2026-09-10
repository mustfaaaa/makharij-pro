# MakharijPro AI

An Android app that listens to Quran recitation and points out Tajweed
mistakes — which word, which rule, and what to fix — for any of the 6,236
ayahs.

Recite from the mushaf-style reading page and words light up as you say them,
driven by the recogniser rather than a timer. When you stop, each word you
actually recited gets a verdict: correct, or a named mistake (madd, ghunnah,
shaddah, makhraj, skipped) with an explanation and playback of the exact slice
of your own recording it was judged on. Words you never reached stay grey and
are never counted against you.

```
frontend/   Flutter app (Android, web, Windows)
backend/    FastAPI service: recitation analysis, live streaming, session history
ml/         model training (Track A), and evaluation against real learners
```

## Running it

You need three things this repository deliberately does not contain, and the
app will start without them but not work properly. Each is explained below.

### 1. Backend

```bash
cd backend && python -m venv .venv && .venv\Scripts\pip install -r requirements.txt
```

Then fetch the phoneme model — **see [`backend/README.md`](backend/README.md)**.
It is a gated Hugging Face repository, so this needs an account and accepting
the model's terms; without it the server starts but word-level analysis and
live tracking return 503.

You also need a Firebase service account key at `backend/serviceAccountKey.json`
(never committed — only the project owner can generate one, from Firebase
Console → Project Settings → Service Accounts). Without it every authenticated
endpoint returns 503.

```bash
cd backend && .venv\Scripts\python -m uvicorn app.main:app --port 8000
```

Healthy startup logs all three parts loading:

```
INFO:app.model_service:Model loaded
INFO:app.firebase_admin_setup:Firebase Admin initialized
INFO:root:Phoneme analysis service loaded -- word-level analysis available
```

### 2. App

```bash
cd frontend && flutter pub get && flutter run
```

`lib/services/api_config.dart` points at `127.0.0.1:8000`, which is right for
Windows/web on the same machine. Use `10.0.2.2:8000` on the Android emulator, or
your machine's LAN IP on a physical device. Debug builds allow cleartext to the
dev backend; release builds do not, and must talk to it over https/wss.

Sign-in is required: without it the live socket won't connect and analysis
won't run.

### 3. If you are not the original owner

`firebase_options.dart` and `google-services.json` are committed and point at
the original Firebase project, which you cannot authenticate against. Replace
both with your own (`flutterfire configure`) and generate your own service
account key.

## How the analysis works

The recogniser is the Quran-Lab streaming zipformer — pre-trained, not ours. It
transcribes recitation into a phoneme stream whose alphabet encodes Tajweed
directly: elongation as a run of repeated `ا`/`ۥ`/`ۦ`, ghunnah as a run of
`م`/`ن`, shaddah as a doubled consonant. Diffing that against an ayah's
canonical sequence therefore recovers *which rule* was broken, not just that
something differed.

The part that took the most care is mapping the model's *phonetic units* onto
*written words*: the two only coincide for 2,121 of 6,236 ayahs, because Tajweed
fuses words across boundaries and the muqatta'at split the other way. See
[`backend/app/word_mapping.py`](backend/app/word_mapping.py).

## Honest limitations

Measured, not assumed — see [`ml/eval/README.md`](ml/eval/README.md).

- On professional Qari recordings, **1.0%** of words are wrongly flagged. On
  773 labelled recordings of ordinary learners, **42.8% of correctly recited
  clips** get flagged for something. The pipeline compares recognised phonemes
  against a canonical sequence, so it cannot separate a mistake from a
  misrecognition — and on learner voices the recogniser's own error rate is
  comparable to the signal.
- Threshold calibration was fitted properly against that labelled data and did
  **not** improve on the shipped setting. The limitation is the recogniser, not
  where the decision line sits.
- `ml/models/makharijpro_tajweed_model_v1` (Track A) is a whole-clip classifier
  trained on ~9-second single-phrase clips. It is out of distribution for real
  recitation and is no longer used to score sessions; it remains reachable at
  `GET /api/v1/model-info` and `POST /api/v1/analyze`.
