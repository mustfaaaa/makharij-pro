# Changed verdicts: baseline → final

Divergence = when the two decodes' tokens first differ, relative to the end of the recording (negative = before the end). Help/hurt is asserted only on correct clips.

## learners: 41 changed

| Effect | Clip | Label (agreed) | Word | Last word? | Expected | Heard before → after | Verdict before → after | Divergence |
|---|---|---|---|---|---|---|---|---|
| category only | 3970951b | correct (yes) | 114:4 w0 مِن | no | `مِںںں` | `مِن` → `مِن` | makhraj → ghunnah | decodes identical |
| category only | 88ffc5c2 | correct (no) | 113:2 w0 مِن | no | `مِںںں` | `مِن` → `م` | makhraj → ghunnah | +0.05s |
| category only | e3e67089 | correct (yes) | 113:2 w0 مِن | no | `مِںںں` | `مِن` → `مِن` | makhraj → ghunnah | decodes identical |
| category only | f4589d55 | correct (no) | 113:5 w0 وَمِن | no | `وَمِںںں` | `مِن` → `مِن` | makhraj → ghunnah | decodes identical |
| helped | 1fcf781e | correct (yes) | 1:5 w3 نَسْتَعِينُ | yes | `نَستَعِۦۦۦۦن` | `نَستَعِۦۦۦۦ` → `نَستَعِۦۦن` | makhraj → ok | +0.04s |
| helped | 20dba83b | correct (no) | 1:2 w3 ٱلْعَٰلَمِينَ | yes | `لعَاالَمِۦۦۦۦن` | `لعَاالَمِۦۦ` → `لعَاالَمِۦۦن` | madd → ok | +0.23s |
| helped | 428619e1 | correct (no) | 1:2 w3 ٱلْعَٰلَمِينَ | yes | `لعَاالَمِۦۦۦۦن` | `لعَاالَمِۦۦۦۦ` → `لعَاالَمِۦۦن` | makhraj → ok | +0.03s |
| helped | 57a1560a | correct (no) | 1:2 w3 ٱلْعَٰلَمِينَ | yes | `لعَاالَمِۦۦۦۦن` | `لعَاالَمِ` → `لعَاالَمِۦۦۦۦن` | madd → ok | +0.34s |
| helped | 6fc545e3 | correct (no) | 1:2 w3 ٱلْعَٰلَمِينَ | yes | `لعَاالَمِۦۦۦۦن` | `لعَاالَمِ` → `لعَاالَمِۦۦۦۦن` | madd → ok | +0.34s |
| helped | 79ab4b58 | correct (yes) | 1:6 w2 ٱلْمُسْتَقِيمَ | yes | `لمُستَقِۦۦۦۦم` | `لمُستَقِۦۦ` → `لمُستَقِۦۦم` | madd → ok | +0.31s |
| helped | 79eea09e | correct (no) | 1:2 w3 ٱلْعَٰلَمِينَ | yes | `لعَاالَمِۦۦۦۦن` | `لعَاالَمِ` → `لعَاالَمِۦۦۦۦن` | madd → ok | +0.26s |
| helped | 8d517f0b | correct (no) | 1:1 w3 ٱلرَّحِيمِ | yes | `ررَحِۦۦۦۦم` | `ررَحِۦۦ` → `ررَحِۦۦم` | madd → ok | +0.25s |
| helped | 91bec489 | correct (yes) | 1:4 w2 ٱلدِّينِ | yes | `ددِۦۦۦۦن` | `ددِۦۦۦۦ` → `ددِۦۦۦۦن` | makhraj → ok | +0.18s |
| helped | d31b1317 | correct (yes) | 1:2 w3 ٱلْعَٰلَمِينَ | yes | `لعَاالَمِۦۦۦۦن` | `لعَاالَمِ` → `لعَاالَمِۦۦن` | madd → ok | +0.11s |
| helped | d3731e93 | correct (yes) | 1:1 w3 ٱلرَّحِيمِ | yes | `ررَحِۦۦۦۦم` | `ررَحِۦۦ` → `ررَحِۦۦم` | madd → ok | +0.20s |
| hurt | 88ffc5c2 | correct (no) | 113:2 w3 خَلَقَ | yes | `خَلَقڇ` | `` → `حَلَ` | not recited → makhraj | +0.05s |
| unknown (clip label) | 20f7af2f | in_correct (no) | 114:4 w0 مِن | no | `مِںںں` | `ن` → `ن` | makhraj → ghunnah | decodes identical |
| unknown (clip label) | 22c55ab3 | in_correct (yes) | 1:1 w2 ٱلرَّحْمَٰنِ | no | `ررَحمَاانِ` | `` → `ِتِللَااهِحصَاا` | not recited → makhraj | -0.29s |
| unknown (clip label) | 22c55ab3 | in_correct (yes) | 1:1 w3 ٱلرَّحِيمِ | yes | `ررَحِۦۦۦۦم` | `` → `ررَهِۦۦم` | not recited → makhraj | -0.29s |
| unknown (clip label) | 2dd6cb87 | in_correct (yes) | 113:2 w0 مِن | no | `مِںںں` | `مِن` → `مِن` | makhraj → ghunnah | decodes identical |
| unknown (clip label) | 3ba0f105 | in_correct (no) | 114:4 w0 مِن | no | `مِںںں` | `مِن` → `مِن` | makhraj → ghunnah | decodes identical |
| unknown (clip label) | 3caf7401 | in_correct (no) | 1:4 w2 ٱلدِّينِ | no | `ددِۦۦۦۦن` | `دِۦۦ` → `` | madd → not recited | -0.00s |
| unknown (clip label) | 44338539 | in_correct (no) | 113:2 w0 مِن | no | `مِںںں` | `مِن` → `مِن` | makhraj → ghunnah | decodes identical |
| unknown (clip label) | 44e85d36 | in_correct (no) | 1:3 w1 ٱلرَّحِيمِ | yes | `ررَحِۦۦۦۦم` | `يرَهِۦۦ` → `يرَهِۦۦم` | makhraj → shaddah | +0.23s |
| unknown (clip label) | 59fc30fb | in_correct (no) | 3:2 w5 ٱلْحَىُّ | no | `لحَييُ` | `` → `لغَيتُ` | not recited → makhraj | +0.03s |
| unknown (clip label) | 59fc30fb | in_correct (no) | 3:2 w6 ٱلْقَيُّومُ | yes | `لقَييُۥۥۥۥم` | `` → `لخَييُۥۥمِ` | not recited → makhraj | +0.03s |
| unknown (clip label) | 6a4f8089 | in_correct (no) | 1:2 w3 ٱلْعَٰلَمِينَ | yes | `لعَاالَمِۦۦۦۦن` | `لاالَمِۦۦ` → `لاالَمِۦۦنَ` | madd → makhraj | +0.20s |
| unknown (clip label) | 7ef35524 | in_correct (yes) | 1:5 w3 نَسْتَعِينُ | yes | `نَستَعِۦۦۦۦن` | `نَستَعِۦۦۦۦ` → `نَستَعِۦۦن` | makhraj → ok | +0.03s |
| unknown (clip label) | 8a91da57 | in_correct (no) | 1:5 w3 نَسْتَعِينُ | yes | `نَستَعِۦۦۦۦن` | `نَستَعِ` → `نَستَعِۦۦن` | madd → ok | -0.03s |
| unknown (clip label) | 8ba2a37b | in_correct (no) | 1:7 w8 ٱلضَّآلِّينَ | yes | `لَضضَااااااللِۦۦۦۦن` | `لَتُںںںااااااللِۦۦم` → `لَتُںںںااااااللِۦۦن` | makhraj → ok | +0.06s |
| unknown (clip label) | 8cc8414f | in_correct (no) | 1:2 w3 ٱلْعَٰلَمِينَ | yes | `لعَاالَمِۦۦۦۦن` | `لعَاالَمِ` → `لعَاالَمِۦۦۦۦن` | madd → ok | +0.34s |
| unknown (clip label) | 8fd262d3 | in_correct (no) | 114:4 w0 مِن | no | `مِںںں` | `مِن` → `مِن` | makhraj → ghunnah | decodes identical |
| unknown (clip label) | a58991a9 | in_correct (no) | 1:3 w1 ٱلرَّحِيمِ | yes | `ررَحِۦۦۦۦم` | `ۦرَحِۦۦم` → `ۦرَحِم` | shaddah → madd | -0.05s |
| unknown (clip label) | a7a1d6cf | in_correct (no) | 1:2 w3 ٱلْعَٰلَمِينَ | yes | `لعَاالَمِۦۦۦۦن` | `` → `ۦلَاالَمُۥۥن` | not recited → makhraj | +0.09s |
| unknown (clip label) | be6743c1 | in_correct (yes) | 1:3 w1 ٱلرَّحِيمِ | yes | `ررَحِۦۦۦۦم` | `ررَحِ` → `ررَحِۦۦۦۦم` | madd → ok | +0.13s |
| unknown (clip label) | c475d7de | in_correct (yes) | 113:4 w0 وَمِن | no | `وَمِںںں` | `لَن` → `لَن` | makhraj → ghunnah | decodes identical |
| unknown (clip label) | cbdb4f60 | in_correct (no) | 1:5 w3 نَسْتَعِينُ | yes | `نَستَعِۦۦۦۦن` | `نَستَعِۦۦۦۦ` → `نَستَعِۦۦن` | makhraj → ok | +0.03s |
| unknown (clip label) | d509c392 | in_correct (no) | 1:2 w3 ٱلْعَٰلَمِينَ | yes | `لعَاالَمِۦۦۦۦن` | `لعَاالَمِۦۦۦۦيَرَح` → `لعَاالَمِۦۦۦۦرَ` | makhraj → ok | -0.31s |
| unknown (clip label) | d5878ea4 | in_correct (no) | 1:1 w3 ٱلرَّحِيمِ | yes | `ررَحِۦۦۦۦم` | `ررَحِ` → `ررَحِۦۦم` | madd → ok | +0.06s |
| unknown (clip label) | e2de051d | in_correct (no) | 1:3 w1 ٱلرَّحِيمِ | yes | `ررَحِۦۦۦۦم` | `ررَحِۦۦۦۦ` → `ررَحِۦۦم` | makhraj → ok | +0.01s |
| unknown (clip label) | ff103e40 | in_correct (no) | 1:7 w8 ٱلضَّآلِّينَ | yes | `لَضضَااااااللِۦۦۦۦن` | `لَتُںںںااااااللِۦۦم` → `لَتُںںںااااااللِۦۦن` | makhraj → ok | +0.06s |

## experts: 0 changed

| Effect | Clip | Label (agreed) | Word | Last word? | Expected | Heard before → after | Verdict before → after | Divergence |
|---|---|---|---|---|---|---|---|---|

