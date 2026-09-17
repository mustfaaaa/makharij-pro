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

### Baseline — the app when this harness was first run, on 773 labelled learner clips

*(Current numbers, re-measured at HEAD: 41.9% of correct clips flagged, 17.2%
of words, 73.1% of mistakes caught, 12.2% of words wrongly shown as unread.
Run `ml/eval/measure_false_alarms.py` for today's figures — the table below is
the starting point everything since is measured against, not a claim about the
app as it stands.)*

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

Two routes forward were proposed here, in cost order. **Both have now been
run.** What follows is what they returned, replacing what this section used to
predict.

### Route 1 — swap the recogniser. Tried. It is worse out of the box.

The proposal was that [`obadx/muaalem-model-v3_2`](https://huggingface.co/obadx/muaalem-model-v3_2)
needs "no training required; just run it through this harness". It was run
(`ml/eval/transcribe_with_muaalem.py`, `ml/eval/compare_recognisers.py`) over
the same clips, scored by the same code, against a character-for-character
identical reference:

| correctly-recited clips | in production | candidate |
|---|---|---|
| median phoneme error rate | **0.069** | 0.154 |
| clips coming back essentially clean | **61.7%** | 31.6% |

Its published 0.16% PER is a number from expert reciters, and it does not
survive learners — the same blind spot the 1.0% Qari column above has. Two
measurement faults were found and fixed along the way, both of which had been
handicapping the candidate: 47 ayah-1 clips were being scored against different
reference strings (the app prepends the basmala, the candidate's phonetiser
does not), and the candidate was given no silence padding while the production
recogniser gets 1.5s.

Worth recording for whoever tries integration: **the two phoneme alphabets are
identical** — 35 symbols, no divergence, both from `quran_transcript`. The
43-vs-251 vocabulary mismatch that looked like the main integration risk does
not exist; 251 is the model's internal token inventory, not the alphabet the
reference is written in.

### Route 2 — adapt to learner voices. Tried. It works.

`ml/train/` does this: speaker-disjoint split, frozen encoder with its output
cached (no GPU on the build machine), and the phoneme head trained on the 353
clips a human marked correctly recited. Across five speaker splits, on
held-out reciters:

| | before | after | in production |
|---|---|---|---|
| median PER | 0.154 | **0.088** | 0.092 |

The honest reading is parity, not victory: the tuned candidate is better on
four splits of five, and the medians differ by less than the spread between
splits. Parity is not yet a reason to ship — the candidate is 0.6B and decodes
4.4s of audio in 6.3s on CPU, against a 69MB int8 ONNX that runs in real time.
What it establishes is that the MIT, trainable path reaches the quality of the
licence-locked one.

**Correction to what this file used to say.** It recommended the 5,600
*unlabelled* clips as "the right material" for that fine-tuning. They are not,
and they were not used. Training a recogniser on audio paired with the
canonical text, without knowing whether the reciter actually said it, teaches
the model to emit the right answer regardless of what it heard — which destroys
the only thing this app does. Only the 353 clips with a human verdict were
used. The unlabelled clips are usable for a recogniser *if* something
establishes what was said in them; nothing here does.

Either way the harness is still the thing that settles it: any change can be
run against the same 773 clips and put next to these numbers.
