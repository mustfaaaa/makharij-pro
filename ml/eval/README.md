# Evaluation on real learner recitations

Every number the Tajweed detector had been judged by came from professional Qari
recordings — Sudais, Alafasy, Yasser Ad-Dussary. That answers *"does it agree
with a perfect reciter"*, which is not the question the app has to get right.
The question that matters is *"does it accuse a learner of a mistake they did
not make"*, because an invented mistake costs the user's trust in every other
verdict on the screen.

This directory answers that against labelled recordings of ordinary people.

## The corpus

[RetaSy/quranic_audio_dataset](https://huggingface.co/datasets/RetaSy/quranic_audio_dataset)
— crowd-sourced from non-Arabic speakers
([paper](https://arxiv.org/abs/2405.02675)). 6,828 clips, 11.5 hours, 1,289
reciters, 82 countries, roughly even male/female, including children.

Not committed (~1.2 GB). To fetch it:

```bash
mkdir -p ml/data/quranic_audio_dataset && cd ml/data/quranic_audio_dataset && for i in 0 1 2; do curl -L -O -C - "https://huggingface.co/datasets/RetaSy/quranic_audio_dataset/resolve/main/data/train-0000${i}-of-00003.parquet"; done
```

What the corpus actually yields, measured rather than assumed:

| | clips | |
|---|---|---|
| total | 6,828 | |
| labelled `correct` / `in_correct` | 911 | the only labels that state whether the *recitation* was right |
| … also resolvable to an ayah | **773** | 353 correct + 420 incorrect, 88 reciters, 46 ayahs |
| unlabelled | 5,600 | no ground truth; usable for fine-tuning later, not for scoring |
| not Quran at all | ~900 | Adhan, At-Tahiyyat, Subhanaka, Salawat, du'as |
| other labels | 317 | `multiple_aya`, `not_match_aya`, `in_complete`, `not_related_quran` |

**Resolution was the gate.** The dataset names a clip by the surah's English
name and the ayah's Arabic *text*, never by number, in a different orthography
from the app's Quran asset. Exact matching resolved 18.8%. Three orthographic
differences accounted for nearly all the misses — plain alif vs connecting
hamza (`الدين` / `ٱلدين`), Farsi `ی` `ک` vs Arabic `ي` `ك`, and a superscript
alef written out in one source and not the other (`مَٰلِكِ` / `مَالِكِ`, but
`ٱلرَّحْمَٰنِ` / `الرَّحْمَنِ` goes the other way). Folding alif away entirely on
both sides takes it to 73.1%, and what remains is material that should not
resolve. See `quran_match.py`.

## What can and cannot be measured here

The labels are **per clip**, not per word. So:

- on a clip a human marked `correct`, any flag at all is a false positive — an
  exact measurement;
- on a clip marked `in_correct`, whether the detector noticed anything — a real
  detection rate;
- whether the **right word** was flagged — *not measurable*. Nothing in this
  directory claims it.

## Running it

```bash
python ml/eval/build_manifest.py        # parquet -> 773 clips + manifest.csv
```
```bash
python ml/eval/run_evaluation.py        # runs the app's real pipeline, ~4 min
```
```bash
python ml/eval/calibrate_thresholds.py  # fits the decision thresholds
```

`run_evaluation.py` caches every clip's per-word expected/predicted phonemes to
`results/word_level.jsonl`, so calibration re-scores thousands of candidate
settings without the recogniser ever running again.

## What calibration does — and does not — do

It does **not** retrain anything. The Quran-Lab zipformer is untouched; it is
not the weak part, and 773 clips could not fine-tune it honestly anyway.

What gets fitted is where the line sits between *"the recogniser heard something
different"* and *"the reciter made a mistake"* — the tolerances in
`backend/app/tajweed_diff.py`. Those were chosen by watching what the recogniser
does to Qari audio, because that was the only audio available. Fitting them to
labelled learner data is the one part of this system that labelled data can set
honestly.

Method:

- fits only on clips whose reciter is known, split **by speaker**, so no reciter
  appears on both sides of the split;
- clips with an unknown reciter are never fitted on and are reported separately
  — they cannot be proven disjoint from anyone, so they are held out wholesale;
- the selection rule is fixed before looking at results: **maximise detection
  subject to a clip-level false-positive rate at or below 10%**, the same bar
  Track A's own threshold calibration used (`ml/README.md`, Phase 13).

The fit split chose the setting, so its own improvement is not evidence. The
validation and held-out columns are the ones that count.

## Results

### Baseline — the app as shipped, on 773 labelled learner clips

|  | professional Qaris | real learners |
|---|---|---|
| words wrongly flagged | **1.0%** | **19.3%** |
| clips wrongly flagged | — | **42.8%** (151 / 353) |
| mistakes detected | — | 73.8% (310 / 420) |
| balanced accuracy | — | 65.5% |

Nearly one correct recitation in two is accused of something. The gap to the
Qari figure is the whole point of this evaluation: it was invisible until real
learner voices were measured.

False positives are not spread evenly across the rules — 168 of the 249 wrongly
flagged words are blamed on `makhraj`, the catch-all bucket that also absorbs
the recogniser's own error. Detection holds up across genders (male 78%, female
71%) and the false-positive rate does too (38% vs 40%), so this is not a bias
against a particular voice; it is a weak detector for everyone.

### Calibration — fitted, and it did not help

54 settings, speaker-split, cost-asymmetric selection rule fixed in advance. No
setting reached the 10% false-positive budget, and **none beat the shipped
setting on both unseen splits.** The trade-off is close to 1:1:

| `MAKHRAJ_MIN_FINDINGS` | false positives | detection | balanced |
|---|---|---|---|
| 1 (shipped) | 46.6% | 74.6% | **64.0%** |
| 2 | 28.1% | 52.0% | 62.0% |
| 3 | 23.6% | 36.4% | 56.4% |

*(held-out split, 351 clips)*

So the thresholds were already sitting at the best available separation, and
they stay where they are. **Threshold placement is not what limits this
detector.**

### What that actually means

The pipeline compares recognised phonemes against a canonical sequence, so it
cannot tell a mistake apart from a misrecognition. On skilled reciters the
recogniser is accurate enough that almost every difference is a real mistake.
On learner voices — accented, hesitant, often children — its own error rate is
comparable to the signal being measured, and no decision threshold can separate
two things that arrive mixed together.

Two routes forward, in cost order:

1. **Swap the recogniser for one that predicts Tajweed attributes directly.**
   [`obadx/muaalem-model-v3`](https://huggingface.co/obadx/muaalem-model-v3)
   emits `sifat` — ghunnah, shidda/rakhawa, tafkheem/tarqeeq, madd length —
   rather than leaving them to be inferred from phoneme run-lengths as
   `tajweed_diff.py` does. No training required; just run it through this
   harness and compare the table above.
2. **Adapt the recogniser to learner voices.** The 5,600 *unlabelled* clips in
   this same corpus are the right material, and unlike calibration this is real
   fine-tuning with a real GPU cost.

Either way the harness is now the thing that settles it: any change can be run
against the same 773 clips and put next to these numbers.
