# Processing time (ml/eval/tajweed_rules/latency.py, 2026-09-27, code 09223b1)

Same 200 learner clips (782 s of audio), one process, alternating the old and
new ending clip by clip so machine load affects both equally:

| Ending | total decode | median per clip |
|---|--:|--:|
| digital silence (before C1) | 52.56 s | 237.8 ms |
| quiet noise (C1) | 52.96 s | 240.8 ms |

Difference +0.77% -- within run-to-run noise: the padding is the same length,
only its samples differ. The separate full runs in meta.json (learner decode
totals 225.7 s, 241.9 s, 209.0 s, 193.6 s for identical work) show how much
machine load alone moves those numbers.

Verdict step (tajweed_diff.classify + summarize, including the C2 ikhfa
branch): 23.3 µs per word over 2,966 recited learner words.
