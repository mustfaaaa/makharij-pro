# Madd / Ghunnah evaluation: baseline

- **baseline**: code b404126, run 2026-09-26 23:43:51

Learner labels are per clip. FP/TN/FPR are exact at clip level; TP*/FN*/precision*/recall*/F1* only say whether an incorrect clip got that rule's flag somewhere (its real mistake may be another kind), so they are not the rule's true precision/recall.

## Per-rule clip-level confusion — All 773 clips

| Rule | Version | TP* | FP | TN | FN* | precision* | recall* | F1* | FPR | FNR* |
|---|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| madd | baseline | 48 | 29 | 324 | 372 | 0.62 | 0.11 | 0.19 | 8.2% | 88.6% |
| ghunnah | baseline | 10 | 3 | 350 | 410 | 0.77 | 0.02 | 0.05 | 0.8% | 97.6% |
| makhraj | baseline | 271 | 114 | 239 | 149 | 0.70 | 0.65 | 0.67 | 32.3% | 35.5% |
| shaddah | baseline | 71 | 36 | 317 | 349 | 0.66 | 0.17 | 0.27 | 10.2% | 83.1% |

Ikhfa FP (correct clips with an ikhfa finding): baseline 4

| Clip-level rate | baseline | Δ vs baseline (95% CI, reciter bootstrap) |
|---|--:|---|
| correct clips with any flag | 41.9% |  |
| incorrect clips flagged | 73.1% |  |
| word flags on correct clips | 18.5% |  |
| madd-flagged correct clips | 8.2% |  |

## Per-rule clip-level confusion — Correct clips restricted to those every annotator agreed on (+ all incorrect)

| Rule | Version | TP* | FP | TN | FN* | precision* | recall* | F1* | FPR | FNR* |
|---|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| madd | baseline | 48 | 17 | 200 | 372 | 0.74 | 0.11 | 0.20 | 7.8% | 88.6% |
| ghunnah | baseline | 10 | 2 | 215 | 410 | 0.83 | 0.02 | 0.05 | 0.9% | 97.6% |
| makhraj | baseline | 271 | 63 | 154 | 149 | 0.81 | 0.65 | 0.72 | 29.0% | 35.5% |
| shaddah | baseline | 71 | 18 | 199 | 349 | 0.80 | 0.17 | 0.28 | 8.3% | 83.1% |

Ikhfa FP (correct clips with an ikhfa finding): baseline 2

| Clip-level rate | baseline | Δ vs baseline (95% CI, reciter bootstrap) |
|---|--:|---|
| correct clips with any flag | 38.2% |  |
| incorrect clips flagged | 73.1% |  |
| word flags on correct clips | 15.7% |  |
| madd-flagged correct clips | 7.8% |  |

## Per-opportunity findings (finding fired / opportunities)

| Opportunity | Group | baseline |
|---|---|--:|
| madd | expert | 4/3266 (0.1%) |
| madd | correct(agreed) | 19/513 (3.7%) |
| madd | correct(disputed) | 21/319 (6.6%) |
| madd | incorrect | 94/1052 (8.9%) |
| ghunnah | expert | 2/486 (0.4%) |
| ghunnah | correct(agreed) | 3/34 (8.8%) |
| ghunnah | correct(disputed) | 1/8 (12.5%) |
| ghunnah | incorrect | 13/47 (27.7%) |
| ikhfa | expert | 2/362 (0.6%) |
| ikhfa | correct(agreed) | 2/12 (16.7%) |
| ikhfa | correct(disputed) | 2/7 (28.6%) |
| ikhfa | incorrect | 8/20 (40.0%) |

## Expert recitation (every flag is a false alarm)

| Version | flagged words | by type |
|---|--:|---|
| baseline | 66/5016 (1.32%) | {'makhraj': 54, 'shaddah': 8, 'madd': 3, 'ghunnah': 1} |

## Controlled edits (ground truth = the edit)

| Condition | baseline flagged / as intended rule / collateral |
|---|---|
| madd4_short (n=40) | 4 / 4 / 34 |
| natural_long4 (n=40) | 5 / 2 / 13 |
| natural_long6 (n=40) | 8 / 2 / 26 |
| ghunnah_short (n=40) | 19 / 16 / 14 |
| lazim_to2 (n=40) | 24 / 18 / 8 |
| lazim_to4 (n=40) | 6 / 5 / 9 |
| control (n=40) | 0 / – / 6 |
| lazim_control (n=40) | 0 / – / 17 |

## Latency (this machine, one process)

| Version | set | clips | audio s | decode s | analysis s | real-time factor |
|---|---|--:|--:|--:|--:|--:|
| baseline | learners | 773 | 3000.4 | 225.66 | 0.734 | 0.0755 |
| baseline | experts | 865 | 5686.1 | 355.74 | 2.947 | 0.0631 |
