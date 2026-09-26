"""Processing-time cost of the changes, measured fairly.

Per-version run times (meta.json) come from separate runs and drift with
whatever else the machine is doing. This decodes the SAME recordings in ONE
process, alternating the old ending (digital silence) and the new one (quiet
noise) clip by clip, so any load affects both equally; and times the verdict
step with and without the ikhfa branch (C2) on every learner word.

    backend/.venv/Scripts/python.exe ml/eval/tajweed_rules/latency.py [n_clips]
"""
import statistics as st
import sys
import time

import numpy as np

import harness as H
from app import tajweed_diff as td
from app import phoneme_analysis_service as pas


def decode_with(svc, y, pad):
    stream = svc.recognizer.create_stream()
    stream.accept_waveform(H.SR, y)
    stream.accept_waveform(H.SR, pad)
    stream.input_finished()
    while svc.recognizer.is_ready(stream):
        svc.recognizer.decode_stream(stream)
    return svc.recognizer.tokens(stream)


def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 200
    svc = H.PhonemeAnalysisService()
    zeros = np.zeros(int(1.5 * H.SR), np.float32)
    items = H.learner_items()[:n]
    t_old, t_new, audio = [], [], 0.0
    for k, it in enumerate(items):
        y = H.load_audio(it["path"])
        audio += len(y) / H.SR
        order = [("old", zeros), ("new", pas.END_PADDING)]
        if k % 2:
            order.reverse()
        for name, pad in order:
            t = time.perf_counter()
            decode_with(svc, y, pad)
            (t_old if name == "old" else t_new).append(time.perf_counter() - t)
    print(f"decode, {n} learner clips ({audio:.0f}s audio), alternating:")
    print(f"  digital-silence ending: total {sum(t_old):.2f}s  median {1000 * st.median(t_old):.1f} ms/clip")
    print(f"  quiet-noise ending    : total {sum(t_new):.2f}s  median {1000 * st.median(t_new):.1f} ms/clip")
    print(f"  difference: {100 * (sum(t_new) / sum(t_old) - 1):+.2f}%")

    words = [w for w in H.jsonl_read(H.RESULTS / "baseline" / "words_learners.jsonl") if w["recited"]]
    t = time.perf_counter()
    for _ in range(5):
        for w in words:
            td.summarize(w["word"], td.classify(w["word"], w["exp"], w["pred"]))
    per_word = (time.perf_counter() - t) / (5 * len(words))
    print(f"verdict step (classify + summarize, current code): {1e6 * per_word:.1f} µs per word over {len(words)} words")


if __name__ == "__main__":
    main()
