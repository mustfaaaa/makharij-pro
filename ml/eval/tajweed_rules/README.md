# Madd / Ghunnah evaluation

Before/after evaluation for changes to how Madd and Ghunnah are detected. Every
number comes from the production backend code, run unchanged on real audio.

## Sets

| Set | What | Ground truth |
|---|---|---|
| learners | the 773 labelled learner clips (`ml/data/quranic_audio_dataset/evalset`) | per **clip** only (correct / incorrect); annotator votes in `evalset_votes.json` |
| experts | 865 professional ayahs: Sudais (Al-Fatihah, Juz 30, every ayah with a 6-count madd), Alafasy, Yasser | correct by construction — every flag is a false alarm |
| edits | 320 expert recordings with one madd / ghunnah shortened or lengthened (`edits_manifest.json`, chosen once from the baseline decode) | certain — the edit is the error |

## Run

```bash
backend/.venv/Scripts/python.exe ml/eval/tajweed_rules/build_votes.py        # once
backend/.venv/Scripts/python.exe ml/eval/tajweed_rules/run_version.py <name>  # one per code version
backend/.venv/Scripts/python.exe ml/eval/tajweed_rules/compare.py baseline <name> ...
```

`run_version.py` records the git commit (and a fingerprint of any uncommitted
backend change) and refuses to overwrite an existing `results/<name>/`. Run
versions one at a time; the latency figures assume an otherwise idle CPU.

Committed per version: `meta.json`, `decodes_*.jsonl` (raw recogniser tokens and
timestamps), `edits.jsonl`. `words_*.jsonl` / `opps_*.jsonl` are regenerated
locally (gitignored).

## Versions

| Name | Code | Change |
|---|---|---|
| baseline | b404126 | — |
| c1 | see meta.json | recording ends on quiet noise, not digital silence (`finish_stream`) |
| c1_c2 | see meta.json | + an ikhfa said as a plain noon/meem is reported under ghunnah |

## What this cannot measure

Learner labels are per clip, so a rule's true precision and recall on learner
audio are not measurable here: the clip-level TP*/FN* only say an incorrect clip
received that rule's flag somewhere. Rule-level learner labels (e.g. QDAT-Bench)
would be needed; its licence could not be verified (2026-09-26), so it is not used.
