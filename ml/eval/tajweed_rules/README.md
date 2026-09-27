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
| c1 | 18a2ba9 | recording ends on quiet noise, not digital silence (`finish_stream`) |
| c1_c2 | 222115b (C2 as first committed, 3065dd2) | + an ikhfa said as a plain noon/meem is reported under ghunnah |
| c1_c2_final | 09223b1 | C2 narrowed: only a hidden noon said as ن, or a hidden meem said as م/ن |
| final | 68f3926 | C1 at -80 dBFS (b48eb63); C2: hidden noon said as ن, hidden meem said as م (68f3926) |

Reports: `results/REPORT_baseline.md`, `REPORT_baseline_vs_c1.md`,
`REPORT_baseline_vs_c1_vs_c1_c2.md`, `REPORT_baseline_vs_c1_vs_c1_c2_final.md`
(C1 at -60 dBFS), `REPORT_baseline_vs_c1_c2_final_vs_final.md` (the final
comparison), `DIFF_baseline_vs_final.md` (every changed word, with where the
decodes diverge), `SANITY_baseline_c1_c2_final_final.md` (hand-read cases),
`PADDING_STRATEGIES.md`, `LATENCY.md`.

## End padding (C1): why -80 dBFS

`padding_experiment.py <strategy>` re-runs the harness with a different end
padding without touching production code; `padding_table.py` builds
`results/PADDING_STRATEGIES.md`; `padding_latency.py` times them fairly;
`diff_versions.py A B` lists every changed word with where the two decodes
first diverge relative to the end of the recording.

Every change any padding makes starts after the recording's last sample --
it only decides which final tokens are flushed. Noise at -60 or -70 dBFS sits
at many recordings' own noise floor (learner median -56 dBFS; 40% within 5 dB
of -60) and puts a quiet held final vowel on the decoder's decision boundary:
one correctly recited word newly lost its madd, a different one per level, and
9 verdicts changed with the noise sample alone. -80 dBFS removed fewer false
alarms (29 -> 21 madd-flagged correct clips, against 17 at -60) but newly
flagged no correct word, behaved the same with a second noise sample, and left
professional recitation unchanged. The recording's own room tone was much
worse (84 correct words newly flagged).

## What the detector can and cannot do (2026-09-27)

**Madd.** Detectable: a madd missing altogether in many cases; the end-of-
recording drop C1 addresses (partly -- some final madds are still lost); a
different long vowel in its place (reported as makhraj). Not reliably
detectable: a madd's actual duration. The recogniser's count (اا / اااا /
اااااا) follows the Quran text, not the voice -- measured on controlled edits
of professional audio, a 6-count madd cut to about 4 counts is still emitted as
6 in 36 of 40 cases -- so too short, too long, 2 vs 4 vs 6 counts, and
route-dependent lengths (e.g. munfasil, which Sudais recites short) cannot be
judged. Token timestamps do track duration (a candidate verification signal,
C3), but no threshold is validated on labelled learner audio, so none is used.

A known quirk, not introduced here: when a word is cut off right after its
madd (ٱلدِّينِ heard as ددِۦۦ), the run alignment in tajweed_diff pairs the
heard madd with the missing final letter and reports "madd: none came through"
plus a makhraj finding, when it is the final letter that is missing.

**Ghunnah.** Detectable: a ghunnah or ikhfa heard nowhere; an ikhfa said as a
plain noon or meem (C2). Not reliably detectable: degree of nasalisation,
partial ghunnah, the acoustic quality of the ghunnah. Timing separates a held
ghunnah from a plain noon/meem only moderately (AUC about 0.9). An iqlab said
as a clear noon is still reported as makhraj.

**Data.** The 773 learner clips are a regression set with per-clip labels only;
they are not per-rule ground truth. TP*/FN*/precision*/recall*/F1* in the
reports are proxies, not Madd or Ghunnah accuracy. Two clips are the same
recording listed twice (ef85bd78, fa31c38d).

## What this cannot measure

Learner labels are per clip, so a rule's true precision and recall on learner
audio are not measurable here: the clip-level TP*/FN* only say an incorrect clip
received that rule's flag somewhere. Rule-level learner labels (e.g. QDAT-Bench)
would be needed; its licence could not be verified (2026-09-26), so it is not used.
