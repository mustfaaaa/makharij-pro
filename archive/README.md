# Archive

Files the app does not use, kept rather than deleted. Nothing in `backend/`,
`frontend/` or `ml/` imports, loads or reads anything in here -- that was
checked by searching the repo for every file's name before it was moved, and
by the full test suites and a backend boot passing afterwards.

Paths mirror where each file used to live, so `archive/backend/tests/x.py`
was `backend/tests/x.py`. Moved with `git mv`, so `git log --follow` still
shows each file's full history.

| What | Why it is here |
|---|---|
| `backend/tests/*` (not `test_*.py`) | One-off scripts from earlier development -- manual HTTP checks, sweeps, model probes -- and the logs, JSON outputs and WAV clips they produced. Not collected by pytest; the real suite is `backend/tests/test_*.py`. Includes `build_rattil_repository.py`, the one-time script that built the original 15-surah Qari library. |
| `backend/*.txt` | Scratch and debug output (`check_fail_*.txt`, `phoneme_check.txt`, ...). |
| `ml/train/train_lstm_clip_classifier.py`, `ml/models/makharijpro_clip_lstm_v1/` | An abandoned clip-level classifier. Superseded by word-level phoneme analysis; nothing loads it. |
| `logs/` | Old backend run logs from the repo root. |
| `ml/models/makharijpro_tajweed_model_v1/`, `backend/app/model_service.py`, `audio_features.py`, `routers/inference.py`, `ml/eval/compare_drill_models.py` | Model v1, the clip-level CNN, and everything that served or measured it. Loaded at every startup for an endpoint the app never called, and the saved file does not reproduce its model card (see `ml/eval/results/drill_model_comparison.json`). Removed from the app along with its TensorFlow dependency. |

These scripts are not maintained. Several import paths or data that have since
moved, so expect to fix them up before running one.
| `backend/app/tajweed_drill.py`, `ml/eval/calibrate_drill_guard.py` | The shelved Tajweed Drill: the close of Al-Ma'idah 5:109 (the phrase QDAT actually contains -- not 2:32 as its card says) and a guard that only lets a recording of that phrase through. The guard is sound and calibrated -- 100% of 300 genuine QDAT attempts kept, 100% of 162 non-attempts rejected, threshold 0.55 -- so it is ready if a drill is ever built on the app's own pipeline instead of v1. Results: `ml/eval/results/drill_guard_calibration.json`. |
