"""Does int8 quantisation cost the candidate recogniser any accuracy?

measure_depth_speed.py showed dynamic int8 quantisation of the linear layers
cuts the candidate's real-time factor by 40-50% at every depth. Speed bought
with accuracy is not a saving, so this measures the other half: the same
trained head, fed the same held-out clips, once through the float32 encoder and
once through its int8 twin. Any difference in phoneme error rate is the price of
quantising, and nothing else.

The head is trained offline in float32 (as it would be in deployment) and only
the encoder is quantised -- the setup a shipped model would actually have.

    ml/.venv-muaalem/Scripts/python.exe ml/eval/measure_int8_quality.py
"""
from __future__ import annotations

import argparse
import csv
import json
import statistics
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
EVALSET = REPO / "ml" / "data" / "quranic_audio_dataset" / "evalset"
MODEL_DIR = REPO / "ml" / "models" / "muaalem-v3_2"
SPLIT = REPO / "ml" / "train" / "splits" / "learner_split.json"
WEIGHTS = REPO / "ml" / "train" / "weights"
OUT = REPO / "ml" / "eval" / "results" / "int8_quality.json"
LEAD_SEC, TAIL_SEC = 0.5, 1.5


def edit_distance(a: str, b: str) -> int:
    previous = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        current = [i]
        for j, cb in enumerate(b, 1):
            current.append(min(previous[j] + 1, current[j - 1] + 1,
                               previous[j - 1] + (ca != cb)))
        previous = current
    return previous[-1]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--depths", type=int, nargs="+", default=[24, 18])
    args = parser.parse_args()

    import copy
    import numpy as np
    import torch
    from librosa.core import load as load_audio
    from transformers import AutoFeatureExtractor
    from quran_muaalem.modeling.modeling_multi_level_ctc import (
        Wav2Vec2BertForMultilevelCTC,
    )
    from quran_muaalem.modeling.multi_level_tokenizer import MultiLevelTokenizer

    split = json.loads(SPLIT.read_text(encoding="utf-8"))
    index = json.loads((REPO / "ml" / "train" / "cache" / "index.json").read_text(encoding="utf-8"))
    held = [c for c in split["held_out"] if c in index]
    files = {r["clip_id"]: r["file"] for r in
             csv.DictReader(open(EVALSET / "manifest.csv", encoding="utf-8"))}

    extractor = AutoFeatureExtractor.from_pretrained(str(MODEL_DIR))
    full = Wav2Vec2BertForMultilevelCTC.from_pretrained(str(MODEL_DIR), dtype=torch.float32)
    full.eval()
    tok = MultiLevelTokenizer(str(MODEL_DIR)).level_to_tokenizer["phonemes"]
    vocab = tok.get_vocab()
    id_to = {v: k for k, v in vocab.items()}
    blank = vocab[tok.pad_token]

    waves = {}
    for c in held:
        w, _ = load_audio(str(EVALSET / files[c]), sr=16000, mono=True)
        waves[c] = np.concatenate([np.zeros(int(LEAD_SEC * 16000), np.float32),
                                   w.astype(np.float32),
                                   np.zeros(int(TAIL_SEC * 16000), np.float32)])

    def decode(logits):
        out, prev = [], None
        for t in logits.argmax(-1).tolist():
            if t != prev and t != blank:
                out.append(id_to.get(t, ""))
            prev = t
        return "".join(out)

    results = []
    for k in args.depths:
        state = torch.load(WEIGHTS / f"phoneme_head_mlp_K{k}.pt")
        hidden = state["0.weight"].shape[0]
        head = torch.nn.Sequential(torch.nn.Linear(1024, hidden), torch.nn.GELU(),
                                   torch.nn.Linear(hidden, state["2.weight"].shape[0]))
        head.load_state_dict(state)
        head.eval()

        fp = copy.deepcopy(full.wav2vec2_bert)
        fp.encoder.layers = fp.encoder.layers[:k]
        fp.eval()
        q8 = torch.ao.quantization.quantize_dynamic(copy.deepcopy(fp), {torch.nn.Linear},
                                                   dtype=torch.qint8)
        q8.eval()

        per = {"fp32": [], "int8": []}
        agree = 0
        for c in held:
            ref = index[c]["reference_phonemes"]
            f = extractor(waves[c], sampling_rate=16000, return_tensors="pt")
            outs = {}
            with torch.no_grad():
                for name, enc in (("fp32", fp), ("int8", q8)):
                    h = enc(f["input_features"], attention_mask=f.get("attention_mask"))[0][0]
                    outs[name] = decode(head(h))
                    per[name].append(edit_distance(outs[name], ref) / len(ref))
            agree += outs["fp32"] == outs["int8"]

        row = {
            "layers": k,
            "clips": len(held),
            "median_per_fp32": round(statistics.median(per["fp32"]), 4),
            "median_per_int8": round(statistics.median(per["int8"]), 4),
            "mean_per_fp32": round(statistics.mean(per["fp32"]), 4),
            "mean_per_int8": round(statistics.mean(per["int8"]), 4),
            "identical_output_pct": round(100 * agree / len(held), 1),
        }
        results.append(row)
        print(f"  K{k:<3} fp32 {row['median_per_fp32']:.4f} (mean {row['mean_per_fp32']:.4f})  "
              f"int8 {row['median_per_int8']:.4f} (mean {row['mean_per_int8']:.4f})  "
              f"identical transcripts {row['identical_output_pct']}%")

    OUT.write_text(json.dumps({"what": "same trained head, fp32 vs int8 encoder, "
                               "held-out clips of the default split",
                               "results": results}, indent=2), encoding="utf-8")
    print(f"\n  -> {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
