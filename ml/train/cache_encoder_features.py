"""Run the frozen encoder once over the learner clips and keep what it produced.

Why cache instead of training end to end
----------------------------------------
There is no GPU on this machine -- torch is the CPU build, 8 cores. A forward
pass through the 0.6B w2v-BERT encoder costs about six seconds per clip, so an
end-to-end epoch over 353 clips is roughly half an hour before a single weight
moves, and a useful run is dozens of epochs.

Freezing the encoder and caching its output turns that into one 35-minute pass,
after which an epoch over the phoneme head is a few seconds. That is the
difference between an experiment that finishes today and one that does not.

What this does and does not test
--------------------------------
It tests whether the *head* is miscalibrated for learner audio. It cannot fix
the encoder, and the gap we measured looks like a domain gap -- the production
recogniser was trained on real phone-mic recitation (Quran-Lab's own benchmark
holds out "real phone-mic recitation ... from training"), while this candidate
was trained on studio audio only. Domain lives in the encoder.

So a null result here is not "fine-tuning does not work". It is evidence that
the encoder, not the head, is what needs to move -- which is exactly the finding
that would justify a GPU. Either outcome answers a question worth asking.

    ml/.venv-muaalem/Scripts/python.exe ml/train/cache_encoder_features.py
"""
from __future__ import annotations

import argparse
import csv
import json
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
EVALSET = REPO / "ml" / "data" / "quranic_audio_dataset" / "evalset"
MODEL_DIR = REPO / "ml" / "models" / "muaalem-v3_2"
SPLIT = REPO / "ml" / "train" / "splits" / "learner_split.json"
OUT = REPO / "ml" / "train" / "cache"

# The same silence the production recogniser gets, and the same the candidate
# was given when it was measured. A CTC model whose audio stops on the final
# consonant emits nothing for it.
LEAD_SEC, TAIL_SEC = 0.5, 1.5


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", type=Path, default=MODEL_DIR)
    parser.add_argument("--out", type=Path, default=OUT)
    parser.add_argument("--limit", type=int, default=None)
    args = parser.parse_args()

    import numpy as np
    import torch
    from librosa.core import load as load_audio
    from transformers import AutoFeatureExtractor
    from quran_muaalem.modeling.modeling_multi_level_ctc import (
        Wav2Vec2BertForMultilevelCTC,
    )
    from quran_transcript import Aya, MoshafAttributes, quran_phonetizer

    split = json.loads(SPLIT.read_text(encoding="utf-8"))
    wanted = set(split["train"]) | set(split["held_out"])
    with open(EVALSET / "manifest.csv", encoding="utf-8") as f:
        rows = [r for r in csv.DictReader(f) if r["clip_id"] in wanted]
    if args.limit:
        rows = rows[:args.limit]

    print(f"loading the encoder from {args.model} ...")
    started = time.time()
    extractor = AutoFeatureExtractor.from_pretrained(str(args.model))
    model = Wav2Vec2BertForMultilevelCTC.from_pretrained(
        str(args.model), dtype=torch.float32)
    model.eval()
    print(f"  loaded in {time.time() - started:.0f}s")

    moshaf = MoshafAttributes(
        rewaya="hafs", madd_monfasel_len=4, madd_mottasel_len=4,
        madd_mottasel_waqf=4, madd_aared_len=4,
    )

    args.out.mkdir(parents=True, exist_ok=True)
    index: dict[str, dict] = {}
    started = time.time()
    failed = 0

    for i, row in enumerate(rows, 1):
        clip_id = row["clip_id"]
        surah, ayah = int(row["surah"]), int(row["ayah"])
        try:
            wave, _ = load_audio(str(EVALSET / row["file"]), sr=16000, mono=True)
            wave = np.concatenate([
                np.zeros(int(LEAD_SEC * 16000), dtype=np.float32),
                wave.astype(np.float32),
                np.zeros(int(TAIL_SEC * 16000), dtype=np.float32),
            ])
            features = extractor(wave, sampling_rate=16000, return_tensors="pt")
            with torch.no_grad():
                # outputs[0] is what the heads are given, before dropout.
                hidden = model.wav2vec2_bert(
                    features["input_features"],
                    attention_mask=features.get("attention_mask"),
                )[0]
            reference = quran_phonetizer(
                Aya(surah, ayah).get().uthmani, moshaf, remove_spaces=True)
        except Exception as exc:
            failed += 1
            if failed <= 3:
                print(f"  {clip_id[:8]}: {type(exc).__name__}: {exc}")
            continue

        # float16 halves the cache on disk and costs nothing: these are inputs
        # to a linear layer, not accumulated gradients.
        np.save(args.out / f"{clip_id}.npy",
                hidden[0].numpy().astype(np.float16))
        index[clip_id] = {
            "surah": surah,
            "ayah": ayah,
            "frames": int(hidden.shape[1]),
            "reference_phonemes": reference.phonemes,
        }

        if i % 25 == 0 or i == len(rows):
            rate = i / max(time.time() - started, 1)
            left = (len(rows) - i) / max(rate, 1e-9)
            print(f"  {i}/{len(rows)}  ({rate:.2f} clips/s, ~{left/60:.0f} min left)")

    (args.out / "index.json").write_text(
        json.dumps(index, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"\n  cached : {len(index)}")
    print(f"  failed : {failed}")
    print(f"  -> {args.out}")
    return 0 if index else 1


if __name__ == "__main__":
    raise SystemExit(main())
