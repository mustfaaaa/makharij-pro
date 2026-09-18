"""How fast is the candidate recogniser at each encoder depth, on this CPU?

The live cursor needs a recogniser that keeps up with speech: a real-time
factor (compute seconds per second of audio) comfortably below 1. Production's
int8 zipformer does. The full 24-layer candidate does not -- 6.3s of compute for
4.4s of audio, RTF ~1.4. This times the truncated models built by
ml/train/cache_truncated_features.py, in float32 and with PyTorch's dynamic
int8 quantisation of the linear layers (the cheapest speed-up there is, and
the same kind of quantisation production already uses).

Timing covers feature extraction through the adapter and head -- everything a
decode costs -- on real clips, after a warm-up, median over clips. Production is
not timed here (different runtime, different venv); its RTF comes from
ml/eval/crossmodel/measure_live_latency.py and is stated alongside.

    ml/.venv-muaalem/Scripts/python.exe ml/eval/measure_depth_speed.py
"""
from __future__ import annotations

import argparse
import csv
import json
import statistics
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
EVALSET = REPO / "ml" / "data" / "quranic_audio_dataset" / "evalset"
MODEL_DIR = REPO / "ml" / "models" / "muaalem-v3_2"
OUT = REPO / "ml" / "eval" / "results" / "depth_speed.json"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--depths", type=int, nargs="+", default=[6, 12, 18, 24])
    parser.add_argument("--clips", type=int, default=15)
    args = parser.parse_args()

    import copy
    import numpy as np
    import torch
    from librosa.core import load as load_audio
    from transformers import AutoFeatureExtractor
    from quran_muaalem.modeling.modeling_multi_level_ctc import (
        Wav2Vec2BertForMultilevelCTC,
    )

    with open(EVALSET / "manifest.csv", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    # A spread of lengths, not the first N: short clips flatter per-call overhead.
    rows.sort(key=lambda r: int(r["duration_ms"] or 0))
    step = max(len(rows) // args.clips, 1)
    rows = rows[::step][:args.clips]
    waves = [load_audio(str(EVALSET / r["file"]), sr=16000, mono=True)[0].astype(np.float32)
             for r in rows]

    extractor = AutoFeatureExtractor.from_pretrained(str(MODEL_DIR))
    full = Wav2Vec2BertForMultilevelCTC.from_pretrained(str(MODEL_DIR), dtype=torch.float32)
    full.eval()
    head = full.level_to_lm_head["phonemes"]
    torch.set_num_threads(torch.get_num_threads())

    def build(k: int, int8: bool):
        base = copy.deepcopy(full.wav2vec2_bert)
        base.encoder.layers = base.encoder.layers[:k]
        if int8:
            base = torch.ao.quantization.quantize_dynamic(base, {torch.nn.Linear}, dtype=torch.qint8)
        base.eval()
        return base

    def rtf(base) -> float:
        with torch.no_grad():
            f = extractor(waves[0], sampling_rate=16000, return_tensors="pt")
            head(base(f["input_features"], attention_mask=f.get("attention_mask"))[0])  # warm-up
        ratios = []
        for w in waves:
            t0 = time.perf_counter()
            with torch.no_grad():
                f = extractor(w, sampling_rate=16000, return_tensors="pt")
                head(base(f["input_features"], attention_mask=f.get("attention_mask"))[0])
            ratios.append((time.perf_counter() - t0) / (len(w) / 16000))
        return statistics.median(ratios)

    results = []
    print(f"{len(waves)} clips, {sum(len(w) for w in waves) / 16000:.0f}s of audio, "
          f"{torch.get_num_threads()} threads\n")
    print(f"  {'layers':>6} {'params':>8} {'RTF fp32':>9} {'RTF int8':>9}")
    for k in args.depths:
        fp = build(k, int8=False)
        params = sum(p.numel() for p in fp.parameters()) / 1e6
        r32 = rtf(fp)
        del fp
        r8 = rtf(build(k, int8=True))
        results.append({"layers": k, "params_m": round(params, 1),
                        "rtf_fp32": round(r32, 3), "rtf_int8": round(r8, 3)})
        print(f"  {k:>6} {params:>7.0f}M {r32:>9.3f} {r8:>9.3f}")

    OUT.write_text(json.dumps({
        "what": "real-time factor (compute s / audio s), median over clips; <1 keeps up with speech",
        "clips": len(waves),
        "threads": torch.get_num_threads(),
        "results": results,
    }, indent=2), encoding="utf-8")
    print(f"\n  -> {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
