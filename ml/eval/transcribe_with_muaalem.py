"""Stage A of the recogniser comparison: decode the eval clips with the candidate.

Runs in ml/.venv-muaalem, NOT the backend venv
----------------------------------------------
`quran-muaalem` wants a newer pydantic than the backend is pinned to, and
pinning the backend's version drags the package itself back from 0.2.2 to 0.0.3.
Rather than disturb a serving environment that works, the candidate lives in its
own venv and hands its output over as a file. That also keeps the comparison
honest: neither model can accidentally borrow the other's preprocessing.

It also needs transformers 4.x -- the package imports a private symbol
(`_HIDDEN_STATES_START_POSITION`) that transformers 5 removed.

What it writes
--------------
One JSON line per clip: the phonemes the model predicted, the canonical phonemes
for that ayah, and the per-phoneme confidences. Scoring happens in Stage B
(compare_recognisers.py) using the same rules the current model is judged by, so
the two are never scored by different code.

    ml/.venv-muaalem/Scripts/python.exe ml/eval/transcribe_with_muaalem.py
"""
from __future__ import annotations

import argparse
import csv
import json
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
EVALSET = REPO / "ml" / "data" / "quranic_audio_dataset" / "evalset"
MODEL_DIR = REPO / "ml" / "models" / "muaalem-v3_2"
OUT = Path(__file__).resolve().parent / "results" / "muaalem_predictions.jsonl"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--limit", type=int, default=None)
    parser.add_argument("--model", type=Path, default=MODEL_DIR)
    parser.add_argument("--out", type=Path, default=OUT)
    args = parser.parse_args()

    import numpy as np
    import torch
    from librosa.core import load as load_audio
    from quran_muaalem import Muaalem
    from quran_transcript import Aya, MoshafAttributes, quran_phonetizer

    with open(EVALSET / "manifest.csv", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    if args.limit:
        rows = rows[:args.limit]

    print(f"loading the candidate model from {args.model} ...")
    started = time.time()
    # float32 on CPU: the package defaults to bfloat16, which several CPU
    # kernels either do not implement or run far slower than fp32.
    cuda = torch.cuda.is_available()
    muaalem = Muaalem(
        model_name_or_path=str(args.model),
        device="cuda" if cuda else "cpu",
        dtype=torch.bfloat16 if cuda else torch.float32,
    )
    print(f"  loaded in {time.time() - started:.0f}s")

    # Hafs via Shatibiyyah with the common madd lengths. These are not
    # cosmetic: they decide how long the canonical madd runs are, so the
    # reference the model is scored against depends on them. 4/4/4/4 matches
    # the murattal style of the reference reciters.
    moshaf = MoshafAttributes(
        rewaya="hafs",
        madd_monfasel_len=4,
        madd_mottasel_len=4,
        madd_mottasel_waqf=4,
        madd_aared_len=4,
    )
    args.out.parent.mkdir(parents=True, exist_ok=True)
    written = failed = 0
    started = time.time()

    with open(args.out, "w", encoding="utf-8") as fh:
        for i, row in enumerate(rows, 1):
            surah, ayah = int(row["surah"]), int(row["ayah"])
            try:
                wave, _ = load_audio(str(EVALSET / row["file"]), sr=16000, mono=True)
                # Silence on both ends, for the same reason the production
                # recogniser pads: a CTC model given audio that stops on the
                # final consonant emits nothing for it, and the layer above
                # reports the last word as dropped. Measured on the 40
                # worst-truncated correct clips, padding cut the median
                # phoneme error rate from 0.52 to 0.38 -- without it the
                # comparison measures our preprocessing, not the model.
                wave = np.concatenate([
                    np.zeros(int(0.5 * 16000), dtype=np.float32),
                    wave.astype(np.float32),
                    np.zeros(int(1.5 * 16000), dtype=np.float32),
                ])
                reference = quran_phonetizer(
                    Aya(surah, ayah).get().uthmani, moshaf, remove_spaces=True)
                out = muaalem([wave], [reference], sampling_rate=16000)[0]
            except Exception as exc:
                failed += 1
                if failed <= 3:
                    print(f"  {row['clip_id'][:8]}: {type(exc).__name__}: {exc}")
                continue

            fh.write(json.dumps({
                "clip_id": row["clip_id"],
                "reciter_id": row.get("reciter_id", ""),
                "surah": surah,
                "ayah": ayah,
                "recited_correctly": int(row["recited_correctly"]),
                "reference_phonemes": reference.phonemes,
                "predicted_phonemes": out.phonemes.text,
                # Kept because the current pipeline had to reconstruct posteriors
                # from raw ONNX to get anything equivalent; here it is given.
                # `probs` is a tensor, so it cannot be truth-tested with `or`.
                "phoneme_confidences": (
                    [round(float(p), 4) for p in out.phonemes.probs]
                    if out.phonemes.probs is not None else []
                ),
            }, ensure_ascii=False) + "\n")
            written += 1

            if i % 50 == 0 or i == len(rows):
                rate = i / max(time.time() - started, 1)
                print(f"  {i}/{len(rows)}  ({rate:.1f} clips/s)")

    print(f"\n  written : {written}")
    print(f"  failed  : {failed}")
    print(f"  -> {args.out}")
    return 0 if written else 1


if __name__ == "__main__":
    raise SystemExit(main())
