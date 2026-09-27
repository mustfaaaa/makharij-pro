# End-padding strategies

What follows a recording into the recognizer before its last tokens are read
out (finish_stream). Same 773 learner clips and 865 professional recitations,
every strategy scored by the same verdict code (git 68f3926 for tajweed_diff);
reference = digital silence through the same path (`pad_zeros`, byte-identical
to the frozen baseline decodes). Regenerate with `padding_experiment.py
<strategy>` then `padding_table.py`.

| Strategy | Correct madd FP (clips) | New regressions ok→flag / unread→flag | Fixed final madd | Incorrect clips flagged | Expert flags | Seed flips |
|---|--:|--:|--:|--:|--:|--:|
| A digital silence (baseline) | 29 | 0 / 0 | 0 | 73.1% | 66/5016 (0 changed) | – |
| B -60 dBFS, 1.5 s (C1) | 17 | 1 / 4 | 13 | 71.9% | 66/5016 (0 changed) | 9 |
| C -70 dBFS, 1.5 s | 19 | 1 / 4 | 12 | 72.6% | 66/5016 (0 changed) | 9 |
| C' -80 dBFS, 1.5 s (selected) | 21 | 0 / 1 | 8 | 72.1% | 66/5016 (0 changed) | 6 |
| D recording floor -10 dB | 21 | 0 / 3 | 9 | 72.4% | 66/5016 (0 changed) | – |
| E recording's own room tone | 76 | 84 / 2 | 1 | 79.5% | 78/5016 (12 changed) | – |
| F -70 dBFS, 1.0 s | 20 | 1 / 4 | 11 | 72.6% | 66/5016 (0 changed) | – |

Seed flips: learner word verdicts that differ when only the noise sample
changes (a second seed). With a second seed, -80 dBFS gave 19 madd FP clips,
11 fixed, and the same single new flag; -60 gave 17/16/5 and -70 19/16/5.

## Decode time (padding_latency.py, 150 learner clips, 584 s audio, rotating order)

| Strategy | total | vs digital silence |
|---|--:|--:|
| digital silence | 45.44 s | — |
| -60 dBFS | 45.90 s | +1.0% |
| -70 dBFS | 45.08 s | -0.8% |
| **-80 dBFS (selected)** | 44.76 s | -1.5% |
| floor -10 dB | 45.26 s | -0.4% |
| room tone | 45.20 s | -0.5% |
| -70 dBFS, 1.0 s | 41.22 s | -9.3% |

All 1.5 s paddings cost the same within run-to-run noise; production builds its
padding once per process (96 KB).

## Decision: -80 dBFS, 1.5 s, fixed seed

- -60 (the first C1) removed the most madd false alarms (29 -> 17) but newly
  flagged a correctly recited word, flagged 4 words it used to call "not
  recited", and changed 9 verdicts with the noise sample alone: at many
  learners' own noise floor (median -56 dBFS; 40% within 5 dB of -60) a quiet
  held final vowel sits on the decoder's decision boundary. -70 behaved the
  same, on a different clip.
- -80 removes fewer (29 -> 21) but newly flags no correct word, one previously
  "not recited" word (on a clip annotators disputed), gives the same result with
  a second noise sample, and leaves professional recitation unchanged.
- Recording-relative (floor -10 dB) was no better than -80 and needs the
  recording's audio at finish time; room tone was much worse; 1.0 s fixed fewer.
