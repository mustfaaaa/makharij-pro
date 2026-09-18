<div align="center">

# MakharijPro AI

**Recite the Quran. Get told which word you got wrong, which Tajweed rule it broke, and why.**

Word-by-word Tajweed feedback for all **6,236 ayahs** — live as you recite, and in detail when you stop.

[![Flutter](https://img.shields.io/badge/Flutter-Android%20%7C%20Web%20%7C%20Windows-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-backend-009688?logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![Python](https://img.shields.io/badge/Python-3.12-3776AB?logo=python&logoColor=white)](https://python.org)
[![Model](https://img.shields.io/badge/ASR-streaming%20zipformer-orange)](https://huggingface.co/Quran-Lab/zipformer_p-arabic-v3)
[![License](https://img.shields.io/badge/license-NPL--1.2%20(no--profit)-red)](#-license--this-matters)

</div>

---

## What it does

Open the mushaf-style reading page and start reciting. **Words light up as you say them** — driven by the recogniser hearing you, not by a timer guessing.

When you stop, every word you actually recited gets a verdict:

- ✅ **Correct**, or
- ⚠️ **A named mistake** — `madd` · `ghunnah` · `shaddah` · `makhraj` · `skipped` — with an explanation and **playback of the exact slice of your own recording** it was judged on.

Words you never reached stay grey. They are never counted against you.

### Beyond the verdict

| Feature | What it gives you |
|---|---|
| 📖 **Per-word Tajweed reference** | Tap any word: which **makhraj** it is articulated from, which rules it carries, how many counts its madd should be held — **77,429 words**, model-free, always correct |
| 🎧 **Hear a Qari** | Reference recitation from **Sudais, Alafasy, or Yasser ad-Dussary** |
| 📊 **Progress tracking** | Accuracy trend, per-rule mastery, practice-activity heatmap, streaks |
| 🎯 **Practice plan** | Built from the rules *you* actually break, not a fixed syllabus |
| 🙋 **"I said it right"** | Disagree with any flag. The app records it instead of arguing (see [limitations](#-honest-limitations)) |

---

## How the analysis actually works

This is the part worth reading.

The recogniser transcribes recitation into a **phoneme stream whose alphabet encodes Tajweed directly**:

| Rule | How it appears in the phoneme stream |
|---|---|
| **Madd** (elongation) | a run of repeated `ا` / `ۥ` / `ۦ` |
| **Ghunnah** (nasalisation) | a run of `م` / `ن` |
| **Shaddah** (doubling) | a doubled consonant |

So **diffing** that stream against the ayah's canonical sequence doesn't just say *something differed* — it recovers **which rule was broken**. No separate Tajweed classifier, no hand-written rule engine.

> **The hard part wasn't the model — it was the mapping.**
> The recogniser's *phonetic units* and the *written words* on screen only line up for **2,121 of 6,236 ayahs**. Tajweed fuses words across boundaries; the muqatta'at split the other way. See [`backend/app/word_mapping.py`](backend/app/word_mapping.py).

---

## Quick start

> **Everything heavy is already in this repository** — the 69 MB recogniser, the 77,429-word Tajweed table, and 258 reference recitations. No model download, no Hugging Face account.

### 1 · Backend

```bash
cd backend
python -m venv .venv
.venv/Scripts/pip install -r requirements.txt
```

You need **one** file this repo deliberately does not contain: a Firebase service account key at `backend/serviceAccountKey.json`.
Generate it from **Firebase Console → Project Settings → Service Accounts → Generate new private key**. Without it, every authenticated endpoint returns 503.

```bash
.venv/Scripts/python -m uvicorn app.main:app --port 8000
```

A healthy startup logs its parts loading:

```
INFO:app.firebase_admin_setup:Firebase Admin initialized
INFO:root:Phoneme analysis service loaded -- word-level analysis available
```

### 2 · App

```bash
cd frontend
flutter pub get
flutter run
```

Point the app at your backend in [`lib/services/api_config.dart`](frontend/lib/services/api_config.dart):

| Running on | Use |
|---|---|
| Windows / web, same machine | `127.0.0.1:8000` *(default)* |
| Android emulator | `10.0.2.2:8000` |
| Physical phone | your LAN IP, **or** run `adb reverse tcp:8000 tcp:8000` and keep the default |

> `adb reverse` does **not** survive a disconnect — re-run it after replugging.

Debug builds allow cleartext to a dev backend. Release builds do not, and must reach it over https/wss.

### 3 · If you are not the original owner

`firebase_options.dart` and `google-services.json` are committed and point at the original Firebase project, which you cannot authenticate against. Replace both with `flutterfire configure` and generate your own service account key.

---

## Repository layout

```
frontend/   Flutter app (Android, web, Windows)
backend/    FastAPI — recitation analysis, live streaming socket, session history
ml/         training (Track A), evaluation harnesses, and the Tajweed table extractor
```

### API surface

```
POST  /api/v1/sessions/analyze_word_level     word-by-word verdicts for a recording
WS    /api/v1/sessions/stream                 live cursor while reciting
POST  /api/v1/sessions/{id}/word-feedback     "I said it right"
GET   /api/v1/tajweed/word/{s}/{a}/{i}        makhraj + rules for one word
GET   /api/v1/tajweed/ayah/{s}/{a}            the whole ayah
GET   /api/v1/tajweed/examples/{rule}         real Quranic words carrying a rule
GET   /api/v1/progress · /achievements · /practice-plan · /rattil/*
```

---


### Recently measured and fixed

Both were cases of the app highlighting words the reciter never said:

| Fix | Before | After | Guard |
|---|---|---|---|
| Result screen over-highlighting | 88 words wrongly marked | **27** | full-surah control unchanged |
| Live cursor running ahead of the voice | 13 updates ahead | **0** | highlight reach 99.2% → 97.7% |

Harnesses: [`measure_recited_spill.py`](ml/eval/crossmodel/measure_recited_spill.py) · [`measure_live_overrun.py`](ml/eval/crossmodel/measure_live_overrun.py)

---


