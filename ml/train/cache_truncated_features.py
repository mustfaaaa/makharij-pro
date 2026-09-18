"""Build our own "mini" recogniser by keeping only the first K encoder layers.

Why this exists
---------------
The fine-tuned candidate reached parity with production on learner audio, but
it is 0.6B parameters and decodes 4.4s of audio in 6.3s on CPU -- too slow for
the live cursor. The plan was to repeat the fine-tune on a smaller sibling,
`obadx/muaalem-model-v3-mini`. That repository does not exist (HTTP 404, as does
`muaalem-model-w2v2-384-tp`); the only other published version, v3_0, is the
same 24 x 1024 size. So no small model can be downloaded.

A smaller one can be *made*. Encoder depth is the cost: time is close to linear
in the number of layers. Keeping the first K of 24 and training the head on top
is the cheapest compression there is, and it answers the question directly --
how much quality survives at a speed the live path can afford?

How
---
One forward pass per clip with `output_hidden_states=True` yields the output of
every layer at once. For each K the frozen adapter (one layer, stride 2) is then
applied to layer K's output, exactly as it would be if the encoder stopped
there. That is precisely the truncated model's forward pass, for the cost of one
full pass instead of one per K.

The adapter was trained on layer-24 output, so at small K it is being fed
features it has never seen. The head trained on top can absorb some of that,
not all; it is the honest price of not retraining the adapter too, and it makes
the small-K numbers a lower bound.

    ml/.venv-muaalem/Scripts/python.exe ml/train/cache_truncated_features.py
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
OUT = REPO / "ml" / "train" / "cache_depth"
FULL_CACHE = REPO / "ml" / "train" / "cache"

LEAD_SEC, TAIL_SEC = 0.5, 1.5
DEPTHS = (6, 12, 18, 24)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--depths", type=int, nargs="+", default=list(DEPTHS))
    parser.add_argument("--limit", type=int, default=None)
    args = parser.parse_args()

    import numpy as np
    import torch
    from librosa.core import load as load_audio
    from transformers import AutoFeatureExtractor
    from quran_muaalem.modeling.modeling_multi_level_ctc import (
        Wav2Vec2BertForMultilevelCTC,
    )

    split = json.loads(SPLIT.read_text(encoding="utf-8"))
    wanted = set(split["train"]) | set(split["held_out"])
    with open(EVALSET / "manifest.csv", encoding="utf-8") as f:
        rows = [r for r in csv.DictReader(f) if r["clip_id"] in wanted]
    if args.limit:
        rows = rows[:args.limit]

    # The reference phonemes are already computed per clip; reuse them rather
    # than re-deriving, so every depth is scored against byte-identical text.
    full_index = json.loads((FULL_CACHE / "index.json").read_text(encoding="utf-8"))

    extractor = AutoFeatureExtractor.from_pretrained(str(MODEL_DIR))
    model = Wav2Vec2BertForMultilevelCTC.from_pretrained(str(MODEL_DIR), dtype=torch.float32)
    model.eval()
    base = model.wav2vec2_bert
    assert base.intermediate_ffn is None, "truncation below assumes no intermediate_ffn"
    n_layers = len(base.encoder.layers)

    for k in args.depths:
        (OUT / f"K{k}").mkdir(parents=True, exist_ok=True)

    indexes = {k: {} for k in args.depths}
    started = time.time()
    checked = False

    for i, row in enumerate(rows, 1):
        clip_id = row["clip_id"]
        if clip_id not in full_index:
            continue
        wave, _ = load_audio(str(EVALSET / row["file"]), sr=16000, mono=True)
        wave = np.concatenate([
            np.zeros(int(LEAD_SEC * 16000), dtype=np.float32),
            wave.astype(np.float32),
            np.zeros(int(TAIL_SEC * 16000), dtype=np.float32),
        ])
        features = extractor(wave, sampling_rate=16000, return_tensors="pt")
        mask = features.get("attention_mask")
        with torch.no_grad():
            out = base(features["input_features"], attention_mask=mask,
                       output_hidden_states=True)
            layers = out.hidden_states  # [0] = input to layer 1, [k] = after k layers

            if not checked:
                # The whole approach rests on hidden_states[24] being what the
                # adapter normally receives. Prove it on the first clip rather
                # than assume the indexing convention.
                assert len(layers) == n_layers + 1, len(layers)
                rebuilt = base.adapter(layers[n_layers], attention_mask=mask)
                gap = (rebuilt - out.last_hidden_state).abs().max().item()
                assert gap < 1e-4, f"layer indexing is off: max diff {gap}"
                print(f"  verified: adapter(hidden_states[{n_layers}]) == model output "
                      f"(max diff {gap:.2e})")
                checked = True

            for k in args.depths:
                h = base.adapter(layers[k], attention_mask=mask)
                np.save(OUT / f"K{k}" / f"{clip_id}.npy", h[0].numpy().astype(np.float16))
                indexes[k][clip_id] = {**full_index[clip_id], "frames": int(h.shape[1])}

        if i % 25 == 0 or i == len(rows):
            rate = i / max(time.time() - started, 1)
            print(f"  {i}/{len(rows)}  ({rate:.2f} clips/s, "
                  f"~{(len(rows) - i) / max(rate, 1e-9) / 60:.0f} min left)")

    for k in args.depths:
        (OUT / f"K{k}" / "index.json").write_text(
            json.dumps(indexes[k], ensure_ascii=False), encoding="utf-8")
    print(f"\n  cached depths {args.depths} for {len(indexes[args.depths[0]])} clips -> {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
