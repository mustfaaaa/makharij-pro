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

These scripts are not maintained. Several import paths or data that have since
moved, so expect to fix them up before running one.
