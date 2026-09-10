"""Re-cut the Qari word slices at several left-padding values, to test whether
the Makhraj head's collapse is caused by the cut itself.

The hypothesis
--------------
The head scores 96.4% on Quran-MD (words recorded in isolation) and 10.7% on
the same professional reciters when their words are cut out of continuous
recitation. Learner voices score 10.8% -- indistinguishable -- so the voice is
not the variable. The cut is.

Makhraj is the articulation point of a word's FIRST CONSONANT. In an isolated
recording that consonant begins from silence with a clean onset. In a slice cut
from connected speech it begins mid-stream, coarticulated with whatever came
before, and sits right at the boundary -- the most damaged part of the cut.

If that is the mechanism, giving the model more audio *before* the word onset
should recover accuracy. If accuracy is flat across padding values, the cause
is something else and this rules it out cheaply.

Only the left padding varies. Right padding, the usable window, the Basmala
offset, the timings and the output schema are all held identical to
stage1_slice_qari.py, so nothing else can explain a difference.

The Zipformer is never re-run: the word timings already recorded in
out_qari/slices_index.jsonl are reused, so this is a pure re-cut.

Run from the repo root:
    backend/.venv/Scripts/python.exe ml/eval/crossmodel/stage1_recut_left_context.py
"""
from __future__ import annotations

import collections
import json
import sys
from pathlib import Path

import librosa
import numpy as np
import soundfile as sf

REPO = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
SOURCE_INDEX = HERE / "out_qari" / "slices_index.jsonl"
RECITATIONS = REPO / "backend" / "app" / "static" / "recitations"

SAMPLE_RATE = 16000
RIGHT_PADDING_SEC = 0.12          # held fixed
LEFT_PADDINGS_SEC = [0.12, 0.25, 0.40, 0.60]   # 0.12 reproduces the 10.7% run

MIN_USABLE_SEC = 0.10
MAX_USABLE_SEC = 3.00


def main() -> int:
    if not SOURCE_INDEX.is_file():
        print(f"run stage1_slice_qari.py first -- {SOURCE_INDEX} missing", file=sys.stderr)
        return 1

    rows = [json.loads(l) for l in SOURCE_INDEX.open(encoding="utf-8") if l.strip()]
    print(f"re-cutting {len(rows)} words at left paddings {LEFT_PADDINGS_SEC}")

    by_clip: dict[tuple[str, int, int], list[dict]] = collections.defaultdict(list)
    for row in rows:
        by_clip[(row["reciter_id"], row["surah"], row["ayah"])].append(row)

    handles = {}
    counts = collections.Counter()
    for pad in LEFT_PADDINGS_SEC:
        out = HERE / f"out_qari_left{int(pad * 100):03d}"
        (out / "slices").mkdir(parents=True, exist_ok=True)
        handles[pad] = ((out / "slices_index.jsonl").open("w", encoding="utf-8"), out)

    for n, ((qari, surah, ayah), words) in enumerate(sorted(by_clip.items()), 1):
        mp3 = RECITATIONS / qari / f"{surah:03d}{ayah:03d}.mp3"
        if not mp3.is_file():
            continue
        # Decoded once and re-cut for every padding, rather than once per
        # padding -- the decode is the expensive part.
        y, _ = librosa.load(str(mp3), sr=SAMPLE_RATE, mono=True)

        for row in words:
            for pad, (fh, out) in handles.items():
                start = max(0, int((row["start_sec"] - pad) * SAMPLE_RATE))
                end = min(len(y), int((row["end_sec"] + RIGHT_PADDING_SEC) * SAMPLE_RATE))
                if end <= start:
                    continue
                duration = (end - start) / SAMPLE_RATE

                clip_dir = out / "slices" / row["clip_id"]
                clip_dir.mkdir(parents=True, exist_ok=True)
                slice_path = clip_dir / f"w{row['word_index_zipformer']:02d}.wav"
                sf.write(slice_path, np.clip(y[start:end], -1.0, 1.0), SAMPLE_RATE,
                         format="WAV", subtype="PCM_16")

                new_row = dict(row)
                new_row["duration_sec"] = round(duration, 4)
                new_row["left_padding_sec"] = pad
                new_row["usable"] = MIN_USABLE_SEC <= duration <= MAX_USABLE_SEC
                new_row["slice"] = str(slice_path.relative_to(out)).replace("\\", "/")
                fh.write(json.dumps(new_row, ensure_ascii=False) + "\n")
                counts[pad] += 1

        if n % 60 == 0:
            print(f"  {n}/{len(by_clip)} clips")

    for pad, (fh, out) in handles.items():
        fh.close()
        print(f"  left={pad:.2f}s -> {counts[pad]} slices  ({out.name})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
