# Madd / Ghunnah evaluation: baseline vs c1 vs c1_c2

- **baseline**: code b404126, run 2026-09-26 23:43:51
- **c1**: code 18a2ba9, run 2026-09-27 00:01:58
- **c1_c2**: code 222115b, run 2026-09-27 00:21:36

Learner labels are per clip. FP/TN/FPR are exact at clip level; TP*/FN*/precision*/recall*/F1* only say whether an incorrect clip got that rule's flag somewhere (its real mistake may be another kind), so they are not the rule's true precision/recall.

## Per-rule clip-level confusion — All 773 clips

| Rule | Version | TP* | FP | TN | FN* | precision* | recall* | F1* | FPR | FNR* |
|---|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| madd | baseline | 48 | 29 | 324 | 372 | 0.62 | 0.11 | 0.19 | 8.2% | 88.6% |
| madd | c1 | 38 | 17 | 336 | 382 | 0.69 | 0.09 | 0.16 | 4.8% | 91.0% |
| madd | c1_c2 | 38 | 17 | 336 | 382 | 0.69 | 0.09 | 0.16 | 4.8% | 91.0% |
| ghunnah | baseline | 10 | 3 | 350 | 410 | 0.77 | 0.02 | 0.05 | 0.8% | 97.6% |
| ghunnah | c1 | 10 | 3 | 350 | 410 | 0.77 | 0.02 | 0.05 | 0.8% | 97.6% |
| ghunnah | c1_c2 | 14 | 7 | 346 | 406 | 0.67 | 0.03 | 0.06 | 2.0% | 96.7% |
| makhraj | baseline | 271 | 114 | 239 | 149 | 0.70 | 0.65 | 0.67 | 32.3% | 35.5% |
| makhraj | c1 | 269 | 113 | 240 | 151 | 0.70 | 0.64 | 0.67 | 32.0% | 36.0% |
| makhraj | c1_c2 | 265 | 112 | 241 | 155 | 0.70 | 0.63 | 0.66 | 31.7% | 36.9% |
| shaddah | baseline | 71 | 36 | 317 | 349 | 0.66 | 0.17 | 0.27 | 10.2% | 83.1% |
| shaddah | c1 | 72 | 36 | 317 | 348 | 0.67 | 0.17 | 0.27 | 10.2% | 82.9% |
| shaddah | c1_c2 | 72 | 36 | 317 | 348 | 0.67 | 0.17 | 0.27 | 10.2% | 82.9% |

Ikhfa FP (correct clips with an ikhfa finding): baseline 4, c1 4, c1_c2 4

| Clip-level rate | baseline | c1 | c1_c2 | Δ vs baseline (95% CI, reciter bootstrap) |
|---|--:|--:|--:|---|
| correct clips with any flag | 41.9% | 40.2% | 40.2% | c1: -1.7 pts [-5.4, -0.3]; c1_c2: -1.7 pts [-5.4, -0.3] |
| incorrect clips flagged | 73.1% | 71.9% | 71.9% | c1: -1.2 pts [-2.2, +0.5]; c1_c2: -1.2 pts [-2.2, +0.5] |
| word flags on correct clips | 18.5% | 17.6% | 17.6% | c1: -0.9 pts [-1.8, +0.0]; c1_c2: -0.9 pts [-1.8, +0.0] |
| madd-flagged correct clips | 8.2% | 4.8% | 4.8% | c1: -3.4 pts [-5.7, -1.2]; c1_c2: -3.4 pts [-5.7, -1.2] |

## Per-rule clip-level confusion — Correct clips restricted to those every annotator agreed on (+ all incorrect)

| Rule | Version | TP* | FP | TN | FN* | precision* | recall* | F1* | FPR | FNR* |
|---|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| madd | baseline | 48 | 17 | 200 | 372 | 0.74 | 0.11 | 0.20 | 7.8% | 88.6% |
| madd | c1 | 38 | 12 | 205 | 382 | 0.76 | 0.09 | 0.16 | 5.5% | 91.0% |
| madd | c1_c2 | 38 | 12 | 205 | 382 | 0.76 | 0.09 | 0.16 | 5.5% | 91.0% |
| ghunnah | baseline | 10 | 2 | 215 | 410 | 0.83 | 0.02 | 0.05 | 0.9% | 97.6% |
| ghunnah | c1 | 10 | 2 | 215 | 410 | 0.83 | 0.02 | 0.05 | 0.9% | 97.6% |
| ghunnah | c1_c2 | 14 | 4 | 213 | 406 | 0.78 | 0.03 | 0.06 | 1.8% | 96.7% |
| makhraj | baseline | 271 | 63 | 154 | 149 | 0.81 | 0.65 | 0.72 | 29.0% | 35.5% |
| makhraj | c1 | 269 | 62 | 155 | 151 | 0.81 | 0.64 | 0.72 | 28.6% | 36.0% |
| makhraj | c1_c2 | 265 | 62 | 155 | 155 | 0.81 | 0.63 | 0.71 | 28.6% | 36.9% |
| shaddah | baseline | 71 | 18 | 199 | 349 | 0.80 | 0.17 | 0.28 | 8.3% | 83.1% |
| shaddah | c1 | 72 | 18 | 199 | 348 | 0.80 | 0.17 | 0.28 | 8.3% | 82.9% |
| shaddah | c1_c2 | 72 | 18 | 199 | 348 | 0.80 | 0.17 | 0.28 | 8.3% | 82.9% |

Ikhfa FP (correct clips with an ikhfa finding): baseline 2, c1 2, c1_c2 2

| Clip-level rate | baseline | c1 | c1_c2 | Δ vs baseline (95% CI, reciter bootstrap) |
|---|--:|--:|--:|---|
| correct clips with any flag | 38.2% | 37.3% | 37.3% | c1: -0.9 pts [-5.7, +1.0]; c1_c2: -0.9 pts [-5.7, +1.0] |
| incorrect clips flagged | 73.1% | 71.9% | 71.9% | c1: -1.2 pts [-2.1, +0.7]; c1_c2: -1.2 pts [-2.1, +0.7] |
| word flags on correct clips | 15.7% | 15.3% | 15.3% | c1: -0.4 pts [-1.3, +0.9]; c1_c2: -0.4 pts [-1.3, +0.9] |
| madd-flagged correct clips | 7.8% | 5.5% | 5.5% | c1: -2.3 pts [-5.5, +0.0]; c1_c2: -2.3 pts [-5.5, +0.0] |

## Per-opportunity findings (finding fired / opportunities)

| Opportunity | Group | baseline | c1 | c1_c2 |
|---|---|--:|--:|--:|
| madd | expert | 4/3266 (0.1%) | 4/3266 (0.1%) | 4/3266 (0.1%) |
| madd | correct(agreed) | 19/513 (3.7%) | 15/516 (2.9%) | 15/516 (2.9%) |
| madd | correct(disputed) | 21/319 (6.6%) | 13/319 (4.1%) | 13/319 (4.1%) |
| madd | incorrect | 94/1052 (8.9%) | 83/1055 (7.9%) | 83/1055 (7.9%) |
| ghunnah | expert | 2/486 (0.4%) | 2/486 (0.4%) | 2/486 (0.4%) |
| ghunnah | correct(agreed) | 3/34 (8.8%) | 3/34 (8.8%) | 3/34 (8.8%) |
| ghunnah | correct(disputed) | 1/8 (12.5%) | 1/8 (12.5%) | 1/8 (12.5%) |
| ghunnah | incorrect | 13/47 (27.7%) | 12/46 (26.1%) | 12/46 (26.1%) |
| ikhfa | expert | 2/362 (0.6%) | 2/362 (0.6%) | 2/362 (0.6%) |
| ikhfa | correct(agreed) | 2/12 (16.7%) | 2/12 (16.7%) | 2/12 (16.7%) |
| ikhfa | correct(disputed) | 2/7 (28.6%) | 2/7 (28.6%) | 2/7 (28.6%) |
| ikhfa | incorrect | 8/20 (40.0%) | 8/20 (40.0%) | 8/20 (40.0%) |

## Expert recitation (every flag is a false alarm)

| Version | flagged words | by type |
|---|--:|---|
| baseline | 66/5016 (1.32%) | {'makhraj': 54, 'shaddah': 8, 'madd': 3, 'ghunnah': 1} |
| c1 | 66/5016 (1.32%) | {'makhraj': 54, 'shaddah': 8, 'madd': 3, 'ghunnah': 1} |
| c1_c2 | 66/5016 (1.32%) | {'makhraj': 52, 'shaddah': 8, 'madd': 3, 'ghunnah': 3} |

## Controlled edits (ground truth = the edit)

| Condition | baseline flagged / as intended rule / collateral | c1 flagged / as intended rule / collateral | c1_c2 flagged / as intended rule / collateral |
|---|---|---|---|
| madd4_short (n=40) | 4 / 4 / 34 | 4 / 4 / 34 | 4 / 4 / 34 |
| natural_long4 (n=40) | 5 / 2 / 13 | 5 / 2 / 13 | 5 / 2 / 13 |
| natural_long6 (n=40) | 8 / 2 / 26 | 8 / 2 / 26 | 8 / 2 / 26 |
| ghunnah_short (n=40) | 19 / 16 / 14 | 19 / 16 / 14 | 19 / 16 / 14 |
| lazim_to2 (n=40) | 24 / 18 / 8 | 24 / 18 / 8 | 24 / 18 / 8 |
| lazim_to4 (n=40) | 6 / 5 / 9 | 6 / 5 / 9 | 6 / 5 / 9 |
| control (n=40) | 0 / – / 6 | 0 / – / 6 | 0 / – / 6 |
| lazim_control (n=40) | 0 / – / 17 | 0 / – / 17 | 0 / – / 17 |

## Latency (this machine, one process)

| Version | set | clips | audio s | decode s | analysis s | real-time factor |
|---|---|--:|--:|--:|--:|--:|
| baseline | learners | 773 | 3000.4 | 225.66 | 0.734 | 0.0755 |
| baseline | experts | 865 | 5686.1 | 355.74 | 2.947 | 0.0631 |
| c1 | learners | 773 | 3000.4 | 241.85 | 0.785 | 0.0809 |
| c1 | experts | 865 | 5686.1 | 365.95 | 3.15 | 0.0649 |
| c1_c2 | learners | 773 | 3000.4 | 208.98 | 0.678 | 0.0699 |
| c1_c2 | experts | 865 | 5686.1 | 359.87 | 2.872 | 0.0638 |

## Every verdict that changed: baseline → c1

**learners**: correct / cleared: 17, correct / newly flagged: 5, correct / type changed: 2, in_correct / cleared: 14, in_correct / newly flagged: 6, in_correct / type changed: 4

- correct · cleared · 1:5 word 3 نَسْتَعِينُ · makhraj → ok · heard `نَستَعِۦۦۦۦ` → `نَستَعِۦۦن` · expected `نَستَعِۦۦۦۦن` · clip 1fcf781e
- correct · cleared · 1:2 word 3 ٱلْعَٰلَمِينَ · madd → ok · heard `لعَاالَمِۦۦ` → `لعَاالَمِۦۦن` · expected `لعَاالَمِۦۦۦۦن` · clip 20dba83b
- correct · cleared · 1:2 word 3 ٱلْعَٰلَمِينَ · madd → ok · heard `لعَاالَمِ` → `لعَاالَمِۦۦۦۦن` · expected `لعَاالَمِۦۦۦۦن` · clip 40ee8b37
- correct · cleared · 1:2 word 3 ٱلْعَٰلَمِينَ · makhraj → ok · heard `لعَاالَمِۦۦۦۦ` → `لعَاالَمِۦۦن` · expected `لعَاالَمِۦۦۦۦن` · clip 428619e1
- correct · cleared · 1:2 word 3 ٱلْعَٰلَمِينَ · madd → ok · heard `لعَاالَمِ` → `لعَاالَمِۦۦۦۦن` · expected `لعَاالَمِۦۦۦۦن` · clip 57a1560a
- correct · cleared · 1:2 word 3 ٱلْعَٰلَمِينَ · madd → ok · heard `لعَاالَمِ` → `لعَاالَمِۦۦۦۦن` · expected `لعَاالَمِۦۦۦۦن` · clip 6fc545e3
- correct · cleared · 1:6 word 2 ٱلْمُسْتَقِيمَ · madd → ok · heard `لمُستَقِۦۦ` → `لمُستَقِۦۦم` · expected `لمُستَقِۦۦۦۦم` · clip 79ab4b58
- correct · cleared · 1:2 word 3 ٱلْعَٰلَمِينَ · madd → ok · heard `لعَاالَمِ` → `لعَاالَمِۦۦۦۦن` · expected `لعَاالَمِۦۦۦۦن` · clip 79eea09e
- correct · cleared · 1:2 word 3 ٱلْعَٰلَمِينَ · madd → ok · heard `لعَاالَمِ` → `لعَاالَمِۦۦۦۦن` · expected `لعَاالَمِۦۦۦۦن` · clip 8bd41b61
- correct · cleared · 1:1 word 3 ٱلرَّحِيمِ · madd → ok · heard `ررَحِۦۦ` → `ررَحِۦۦم` · expected `ررَحِۦۦۦۦم` · clip 8d517f0b
- correct · cleared · 1:4 word 2 ٱلدِّينِ · makhraj → ok · heard `ددِۦۦۦۦ` → `ددِۦۦۦۦن` · expected `ددِۦۦۦۦن` · clip 91bec489
- correct · cleared · 1:6 word 2 ٱلْمُسْتَقِيمَ · madd → ok · heard `لمُستَقِۦۦ` → `لمُستَقِۦۦم` · expected `لمُستَقِۦۦۦۦم` · clip 9f21679b
- correct · cleared · 1:1 word 3 ٱلرَّحِيمِ · madd → ok · heard `ررَحِ` → `ررَحِۦۦم` · expected `ررَحِۦۦۦۦم` · clip 9f41f41c
- correct · cleared · 1:2 word 3 ٱلْعَٰلَمِينَ · madd → ok · heard `لعَاالَمِ` → `لعَاالَمِۦۦن` · expected `لعَاالَمِۦۦۦۦن` · clip d31b1317
- correct · cleared · 1:1 word 3 ٱلرَّحِيمِ · madd → ok · heard `ررَحِۦۦ` → `ررَحِۦۦم` · expected `ررَحِۦۦۦۦم` · clip d3731e93
- correct · cleared · 1:2 word 3 ٱلْعَٰلَمِينَ · madd → ok · heard `لعَاالَمِ` → `لعَاالَمِۦۦۦۦن` · expected `لعَاالَمِۦۦۦۦن` · clip df1d9825
- correct · cleared · 1:7 word 8 ٱلضَّآلِّينَ · makhraj → ok · heard `لَضضَااااااللِمءَاادِ` → `لَضضَااااااللِمءَاادِۦۦن` · expected `لَضضَااااااللِۦۦۦۦن` · clip f5ddfefe
- correct · newly flagged · 3:2 word 5 ٱلْحَىُّ · not recited → makhraj · heard `` → `لحَزمُ` · expected `لحَييُ` · clip 2710fe02
- correct · newly flagged · 3:2 word 6 ٱلْقَيُّومُ · not recited → makhraj · heard `` → `لقَرِۥۥم` · expected `لقَييُۥۥۥۥم` · clip 2710fe02
- correct · newly flagged · 1:1 word 3 ٱلرَّحِيمِ · ok → madd · heard `ررَحِۦۦم` → `ررَحِم` · expected `ررَحِۦۦۦۦم` · clip b82ed2e6
- correct · newly flagged · 1:4 word 2 ٱلدِّينِ · not recited → madd · heard `` → `ددِۦۦ` · expected `ددِۦۦۦۦن` · clip ef85bd78
- correct · newly flagged · 1:4 word 2 ٱلدِّينِ · not recited → madd · heard `` → `ددِۦۦ` · expected `ددِۦۦۦۦن` · clip fa31c38d
- correct · type changed · 1:6 word 2 ٱلْمُسْتَقِيمَ · madd → makhraj · heard `ِمُستَفِۦۦ` → `ِمُستَفِۦۦم` · expected `لمُستَقِۦۦۦۦم` · clip e8b3d6c6
- correct · type changed · 1:7 word 8 ٱلضَّآلِّينَ · madd → makhraj · heard `لَااتَاالِۦۦن` → `لَااتَاالِۦۦم` · expected `لَضضَااااااللِۦۦۦۦن` · clip f156e5f0
- in_correct · cleared · 111:4 word 1 حَمَّالَةَ · madd → not recited · heard `حَمَلتَ` → `` · expected `حَممممَاالَتَ` · clip 324c68ae
- in_correct · cleared · 1:2 word 3 ٱلْعَٰلَمِينَ · madd → ok · heard `لعَاالَمِ` → `لعَاالَمِۦۦۦۦن` · expected `لعَاالَمِۦۦۦۦن` · clip 4ec67b10
- in_correct · cleared · 1:5 word 3 نَسْتَعِينُ · makhraj → ok · heard `نَستَعِۦۦۦۦ` → `نَستَعِۦۦن` · expected `نَستَعِۦۦۦۦن` · clip 7ef35524
- in_correct · cleared · 1:5 word 3 نَسْتَعِينُ · madd → ok · heard `نَستَعِ` → `نَستَعِۦۦن` · expected `نَستَعِۦۦۦۦن` · clip 8a91da57
- in_correct · cleared · 1:7 word 8 ٱلضَّآلِّينَ · makhraj → ok · heard `لَتُںںںااااااللِۦۦم` → `لَتُںںںااااااللِۦۦن` · expected `لَضضَااااااللِۦۦۦۦن` · clip 8ba2a37b
- in_correct · cleared · 1:2 word 3 ٱلْعَٰلَمِينَ · madd → ok · heard `لعَاالَمِ` → `لعَاالَمِۦۦۦۦن` · expected `لعَاالَمِۦۦۦۦن` · clip 8cc8414f
- in_correct · cleared · 1:4 word 2 ٱلدِّينِ · madd → ok · heard `ددِۦۦۦۦۦۦۦۦن` → `ددِۦۦۦۦۦۦن` · expected `ددِۦۦۦۦن` · clip b3f55585
- in_correct · cleared · 1:3 word 1 ٱلرَّحِيمِ · madd → ok · heard `ررَحِ` → `ررَحِۦۦم` · expected `ررَحِۦۦۦۦم` · clip be6743c1
- in_correct · cleared · 1:5 word 3 نَسْتَعِينُ · makhraj → ok · heard `نَستَعِۦۦۦۦ` → `نَستَعِۦۦن` · expected `نَستَعِۦۦۦۦن` · clip cbdb4f60
- in_correct · cleared · 1:2 word 3 ٱلْعَٰلَمِينَ · makhraj → ok · heard `لعَاالَمِۦۦۦۦيَرَح` → `لعَاالَمِۦۦۦۦرَ` · expected `لعَاالَمِۦۦۦۦن` · clip d509c392
- in_correct · cleared · 1:1 word 3 ٱلرَّحِيمِ · madd → ok · heard `ررَحِ` → `ررَحِۦۦم` · expected `ررَحِۦۦۦۦم` · clip d5878ea4
- in_correct · cleared · 1:3 word 1 ٱلرَّحِيمِ · makhraj → ok · heard `ررَحِۦۦۦۦ` → `ررَحِۦۦم` · expected `ررَحِۦۦۦۦم` · clip e2de051d
- in_correct · cleared · 1:5 word 3 نَسْتَعِينُ · madd → ok · heard `نَستَعِ` → `نَستَعِۦۦۦۦن` · expected `نَستَعِۦۦۦۦن` · clip fbd4a5d2
- in_correct · cleared · 1:7 word 8 ٱلضَّآلِّينَ · makhraj → ok · heard `لَتُںںںااااااللِۦۦم` → `لَتُںںںااااااللِۦۦن` · expected `لَضضَااااااللِۦۦۦۦن` · clip ff103e40
- in_correct · newly flagged · 1:1 word 2 ٱلرَّحْمَٰنِ · not recited → makhraj · heard `` → `ِتِللَااهِحصَاا` · expected `ررَحمَاانِ` · clip 22c55ab3
- in_correct · newly flagged · 1:1 word 3 ٱلرَّحِيمِ · not recited → makhraj · heard `` → `ررَهِۦۦم` · expected `ررَحِۦۦۦۦم` · clip 22c55ab3
- in_correct · newly flagged · 113:2 word 3 خَلَقَ · not recited → makhraj · heard `` → `لَق` · expected `خَلَقڇ` · clip 2dd6cb87
- in_correct · newly flagged · 3:2 word 5 ٱلْحَىُّ · not recited → makhraj · heard `` → `لغَيتُ` · expected `لحَييُ` · clip 59fc30fb
- in_correct · newly flagged · 3:2 word 6 ٱلْقَيُّومُ · not recited → makhraj · heard `` → `لخَييُۥۥمِ` · expected `لقَييُۥۥۥۥم` · clip 59fc30fb
- in_correct · newly flagged · 1:3 word 1 ٱلرَّحِيمِ · not recited → shaddah · heard `` → `حِۦۦم` · expected `ررَحِۦۦۦۦم` · clip a2d97d3d
- in_correct · type changed · 1:7 word 8 ٱلضَّآلِّينَ · madd → makhraj · heard `لَااتَاالِۦۦن` → `لَااتَاالِۦۦم` · expected `لَضضَااااااللِۦۦۦۦن` · clip 3cda165a
- in_correct · type changed · 1:2 word 3 ٱلْعَٰلَمِينَ · madd → makhraj · heard `لعَاالَمِ` → `لعَاالَمِۦۦۦۦ` · expected `لعَاالَمِۦۦۦۦن` · clip 449c9e0c
- in_correct · type changed · 1:3 word 1 ٱلرَّحِيمِ · makhraj → shaddah · heard `يرَهِۦۦ` → `يرَهِۦۦم` · expected `ررَحِۦۦۦۦم` · clip 44e85d36
- in_correct · type changed · 1:2 word 3 ٱلْعَٰلَمِينَ · madd → makhraj · heard `لاالَمِۦۦ` → `لاالَمِۦۦن` · expected `لعَاالَمِۦۦۦۦن` · clip 6a4f8089

**experts**: none



## Every verdict that changed: baseline → c1_c2

**learners**: correct / cleared: 17, correct / newly flagged: 5, correct / type changed: 6, in_correct / cleared: 14, in_correct / newly flagged: 6, in_correct / type changed: 10

- correct · cleared · 1:5 word 3 نَسْتَعِينُ · makhraj → ok · heard `نَستَعِۦۦۦۦ` → `نَستَعِۦۦن` · expected `نَستَعِۦۦۦۦن` · clip 1fcf781e
- correct · cleared · 1:2 word 3 ٱلْعَٰلَمِينَ · madd → ok · heard `لعَاالَمِۦۦ` → `لعَاالَمِۦۦن` · expected `لعَاالَمِۦۦۦۦن` · clip 20dba83b
- correct · cleared · 1:2 word 3 ٱلْعَٰلَمِينَ · madd → ok · heard `لعَاالَمِ` → `لعَاالَمِۦۦۦۦن` · expected `لعَاالَمِۦۦۦۦن` · clip 40ee8b37
- correct · cleared · 1:2 word 3 ٱلْعَٰلَمِينَ · makhraj → ok · heard `لعَاالَمِۦۦۦۦ` → `لعَاالَمِۦۦن` · expected `لعَاالَمِۦۦۦۦن` · clip 428619e1
- correct · cleared · 1:2 word 3 ٱلْعَٰلَمِينَ · madd → ok · heard `لعَاالَمِ` → `لعَاالَمِۦۦۦۦن` · expected `لعَاالَمِۦۦۦۦن` · clip 57a1560a
- correct · cleared · 1:2 word 3 ٱلْعَٰلَمِينَ · madd → ok · heard `لعَاالَمِ` → `لعَاالَمِۦۦۦۦن` · expected `لعَاالَمِۦۦۦۦن` · clip 6fc545e3
- correct · cleared · 1:6 word 2 ٱلْمُسْتَقِيمَ · madd → ok · heard `لمُستَقِۦۦ` → `لمُستَقِۦۦم` · expected `لمُستَقِۦۦۦۦم` · clip 79ab4b58
- correct · cleared · 1:2 word 3 ٱلْعَٰلَمِينَ · madd → ok · heard `لعَاالَمِ` → `لعَاالَمِۦۦۦۦن` · expected `لعَاالَمِۦۦۦۦن` · clip 79eea09e
- correct · cleared · 1:2 word 3 ٱلْعَٰلَمِينَ · madd → ok · heard `لعَاالَمِ` → `لعَاالَمِۦۦۦۦن` · expected `لعَاالَمِۦۦۦۦن` · clip 8bd41b61
- correct · cleared · 1:1 word 3 ٱلرَّحِيمِ · madd → ok · heard `ررَحِۦۦ` → `ررَحِۦۦم` · expected `ررَحِۦۦۦۦم` · clip 8d517f0b
- correct · cleared · 1:4 word 2 ٱلدِّينِ · makhraj → ok · heard `ددِۦۦۦۦ` → `ددِۦۦۦۦن` · expected `ددِۦۦۦۦن` · clip 91bec489
- correct · cleared · 1:6 word 2 ٱلْمُسْتَقِيمَ · madd → ok · heard `لمُستَقِۦۦ` → `لمُستَقِۦۦم` · expected `لمُستَقِۦۦۦۦم` · clip 9f21679b
- correct · cleared · 1:1 word 3 ٱلرَّحِيمِ · madd → ok · heard `ررَحِ` → `ررَحِۦۦم` · expected `ررَحِۦۦۦۦم` · clip 9f41f41c
- correct · cleared · 1:2 word 3 ٱلْعَٰلَمِينَ · madd → ok · heard `لعَاالَمِ` → `لعَاالَمِۦۦن` · expected `لعَاالَمِۦۦۦۦن` · clip d31b1317
- correct · cleared · 1:1 word 3 ٱلرَّحِيمِ · madd → ok · heard `ررَحِۦۦ` → `ررَحِۦۦم` · expected `ررَحِۦۦۦۦم` · clip d3731e93
- correct · cleared · 1:2 word 3 ٱلْعَٰلَمِينَ · madd → ok · heard `لعَاالَمِ` → `لعَاالَمِۦۦۦۦن` · expected `لعَاالَمِۦۦۦۦن` · clip df1d9825
- correct · cleared · 1:7 word 8 ٱلضَّآلِّينَ · makhraj → ok · heard `لَضضَااااااللِمءَاادِ` → `لَضضَااااااللِمءَاادِۦۦن` · expected `لَضضَااااااللِۦۦۦۦن` · clip f5ddfefe
- correct · newly flagged · 3:2 word 5 ٱلْحَىُّ · not recited → makhraj · heard `` → `لحَزمُ` · expected `لحَييُ` · clip 2710fe02
- correct · newly flagged · 3:2 word 6 ٱلْقَيُّومُ · not recited → makhraj · heard `` → `لقَرِۥۥم` · expected `لقَييُۥۥۥۥم` · clip 2710fe02
- correct · newly flagged · 1:1 word 3 ٱلرَّحِيمِ · ok → madd · heard `ررَحِۦۦم` → `ررَحِم` · expected `ررَحِۦۦۦۦم` · clip b82ed2e6
- correct · newly flagged · 1:4 word 2 ٱلدِّينِ · not recited → madd · heard `` → `ددِۦۦ` · expected `ددِۦۦۦۦن` · clip ef85bd78
- correct · newly flagged · 1:4 word 2 ٱلدِّينِ · not recited → madd · heard `` → `ددِۦۦ` · expected `ددِۦۦۦۦن` · clip fa31c38d
- correct · type changed · 114:4 word 0 مِن · makhraj → ghunnah · heard `مِن` → `مِن` · expected `مِںںں` · clip 3970951b
- correct · type changed · 113:2 word 0 مِن · makhraj → ghunnah · heard `مِن` → `مِن` · expected `مِںںں` · clip 88ffc5c2
- correct · type changed · 113:2 word 0 مِن · makhraj → ghunnah · heard `مِن` → `مِن` · expected `مِںںں` · clip e3e67089
- correct · type changed · 1:6 word 2 ٱلْمُسْتَقِيمَ · madd → makhraj · heard `ِمُستَفِۦۦ` → `ِمُستَفِۦۦم` · expected `لمُستَقِۦۦۦۦم` · clip e8b3d6c6
- correct · type changed · 1:7 word 8 ٱلضَّآلِّينَ · madd → makhraj · heard `لَااتَاالِۦۦن` → `لَااتَاالِۦۦم` · expected `لَضضَااااااللِۦۦۦۦن` · clip f156e5f0
- correct · type changed · 113:5 word 0 وَمِن · makhraj → ghunnah · heard `مِن` → `مِن` · expected `وَمِںںں` · clip f4589d55
- in_correct · cleared · 111:4 word 1 حَمَّالَةَ · madd → not recited · heard `حَمَلتَ` → `` · expected `حَممممَاالَتَ` · clip 324c68ae
- in_correct · cleared · 1:2 word 3 ٱلْعَٰلَمِينَ · madd → ok · heard `لعَاالَمِ` → `لعَاالَمِۦۦۦۦن` · expected `لعَاالَمِۦۦۦۦن` · clip 4ec67b10
- in_correct · cleared · 1:5 word 3 نَسْتَعِينُ · makhraj → ok · heard `نَستَعِۦۦۦۦ` → `نَستَعِۦۦن` · expected `نَستَعِۦۦۦۦن` · clip 7ef35524
- in_correct · cleared · 1:5 word 3 نَسْتَعِينُ · madd → ok · heard `نَستَعِ` → `نَستَعِۦۦن` · expected `نَستَعِۦۦۦۦن` · clip 8a91da57
- in_correct · cleared · 1:7 word 8 ٱلضَّآلِّينَ · makhraj → ok · heard `لَتُںںںااااااللِۦۦم` → `لَتُںںںااااااللِۦۦن` · expected `لَضضَااااااللِۦۦۦۦن` · clip 8ba2a37b
- in_correct · cleared · 1:2 word 3 ٱلْعَٰلَمِينَ · madd → ok · heard `لعَاالَمِ` → `لعَاالَمِۦۦۦۦن` · expected `لعَاالَمِۦۦۦۦن` · clip 8cc8414f
- in_correct · cleared · 1:4 word 2 ٱلدِّينِ · madd → ok · heard `ددِۦۦۦۦۦۦۦۦن` → `ددِۦۦۦۦۦۦن` · expected `ددِۦۦۦۦن` · clip b3f55585
- in_correct · cleared · 1:3 word 1 ٱلرَّحِيمِ · madd → ok · heard `ررَحِ` → `ررَحِۦۦم` · expected `ررَحِۦۦۦۦم` · clip be6743c1
- in_correct · cleared · 1:5 word 3 نَسْتَعِينُ · makhraj → ok · heard `نَستَعِۦۦۦۦ` → `نَستَعِۦۦن` · expected `نَستَعِۦۦۦۦن` · clip cbdb4f60
- in_correct · cleared · 1:2 word 3 ٱلْعَٰلَمِينَ · makhraj → ok · heard `لعَاالَمِۦۦۦۦيَرَح` → `لعَاالَمِۦۦۦۦرَ` · expected `لعَاالَمِۦۦۦۦن` · clip d509c392
- in_correct · cleared · 1:1 word 3 ٱلرَّحِيمِ · madd → ok · heard `ررَحِ` → `ررَحِۦۦم` · expected `ررَحِۦۦۦۦم` · clip d5878ea4
- in_correct · cleared · 1:3 word 1 ٱلرَّحِيمِ · makhraj → ok · heard `ررَحِۦۦۦۦ` → `ررَحِۦۦم` · expected `ررَحِۦۦۦۦم` · clip e2de051d
- in_correct · cleared · 1:5 word 3 نَسْتَعِينُ · madd → ok · heard `نَستَعِ` → `نَستَعِۦۦۦۦن` · expected `نَستَعِۦۦۦۦن` · clip fbd4a5d2
- in_correct · cleared · 1:7 word 8 ٱلضَّآلِّينَ · makhraj → ok · heard `لَتُںںںااااااللِۦۦم` → `لَتُںںںااااااللِۦۦن` · expected `لَضضَااااااللِۦۦۦۦن` · clip ff103e40
- in_correct · newly flagged · 1:1 word 2 ٱلرَّحْمَٰنِ · not recited → makhraj · heard `` → `ِتِللَااهِحصَاا` · expected `ررَحمَاانِ` · clip 22c55ab3
- in_correct · newly flagged · 1:1 word 3 ٱلرَّحِيمِ · not recited → makhraj · heard `` → `ررَهِۦۦم` · expected `ررَحِۦۦۦۦم` · clip 22c55ab3
- in_correct · newly flagged · 113:2 word 3 خَلَقَ · not recited → makhraj · heard `` → `لَق` · expected `خَلَقڇ` · clip 2dd6cb87
- in_correct · newly flagged · 3:2 word 5 ٱلْحَىُّ · not recited → makhraj · heard `` → `لغَيتُ` · expected `لحَييُ` · clip 59fc30fb
- in_correct · newly flagged · 3:2 word 6 ٱلْقَيُّومُ · not recited → makhraj · heard `` → `لخَييُۥۥمِ` · expected `لقَييُۥۥۥۥم` · clip 59fc30fb
- in_correct · newly flagged · 1:3 word 1 ٱلرَّحِيمِ · not recited → shaddah · heard `` → `حِۦۦم` · expected `ررَحِۦۦۦۦم` · clip a2d97d3d
- in_correct · type changed · 114:4 word 0 مِن · makhraj → ghunnah · heard `ن` → `ن` · expected `مِںںں` · clip 20f7af2f
- in_correct · type changed · 113:2 word 0 مِن · makhraj → ghunnah · heard `مِن` → `مِن` · expected `مِںںں` · clip 2dd6cb87
- in_correct · type changed · 114:4 word 0 مِن · makhraj → ghunnah · heard `مِن` → `مِن` · expected `مِںںں` · clip 3ba0f105
- in_correct · type changed · 1:7 word 8 ٱلضَّآلِّينَ · madd → makhraj · heard `لَااتَاالِۦۦن` → `لَااتَاالِۦۦم` · expected `لَضضَااااااللِۦۦۦۦن` · clip 3cda165a
- in_correct · type changed · 113:2 word 0 مِن · makhraj → ghunnah · heard `مِن` → `مِن` · expected `مِںںں` · clip 44338539
- in_correct · type changed · 1:2 word 3 ٱلْعَٰلَمِينَ · madd → makhraj · heard `لعَاالَمِ` → `لعَاالَمِۦۦۦۦ` · expected `لعَاالَمِۦۦۦۦن` · clip 449c9e0c
- in_correct · type changed · 1:3 word 1 ٱلرَّحِيمِ · makhraj → shaddah · heard `يرَهِۦۦ` → `يرَهِۦۦم` · expected `ررَحِۦۦۦۦم` · clip 44e85d36
- in_correct · type changed · 1:2 word 3 ٱلْعَٰلَمِينَ · madd → makhraj · heard `لاالَمِۦۦ` → `لاالَمِۦۦن` · expected `لعَاالَمِۦۦۦۦن` · clip 6a4f8089
- in_correct · type changed · 114:4 word 0 مِن · makhraj → ghunnah · heard `مِن` → `مِن` · expected `مِںںں` · clip 8fd262d3
- in_correct · type changed · 113:4 word 0 وَمِن · makhraj → ghunnah · heard `لَن` → `لَن` · expected `وَمِںںں` · clip c475d7de

**experts**: expert / type changed: 2

- expert · type changed · 11:6 word 14 كُلٌّۭ · makhraj → ghunnah · heard `كُللُهُم` → `كُللُهُم` · expected `كُللُںںں` · clip abdurrah
- expert · type changed · 24:41 word 13 كُلٌّۭ · makhraj → ghunnah · heard `كُللُهُم` → `كُللُهُم` · expected `كُللُںںں` · clip abdurrah

