"""Decode time per end-padding strategy, measured fairly: the same recordings,
one process, every strategy decoded for each clip in rotating order.

    backend/.venv/Scripts/python.exe ml/eval/tajweed_rules/padding_latency.py [n_clips]
"""
import io
import statistics as st
import sys
import time

import librosa
import numpy as np

import harness as H
from padding_experiment import make_pad

STRATS = ["zeros", "n60", "n70", "n80", "floor10", "roomtone", "n70_1s"]


def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 150
    svc = H.PhonemeAnalysisService()
    t = {s: [] for s in STRATS}
    pad_t = {s: [] for s in STRATS}
    audio = 0.0
    for k, it in enumerate(H.learner_items()[:n]):
        y16 = librosa.load(io.BytesIO(H.wav_bytes(H.load_audio(it["path"]))), sr=H.SR, mono=True)[0].astype(np.float32)
        audio += len(y16) / H.SR
        order = STRATS[k % len(STRATS):] + STRATS[:k % len(STRATS)]
        for s in order:
            t0 = time.perf_counter()
            pad = make_pad(s, y16)
            pad_t[s].append(time.perf_counter() - t0)
            stream = svc.recognizer.create_stream()
            stream.accept_waveform(H.SR, y16)
            stream.accept_waveform(H.SR, pad)
            stream.input_finished()
            while svc.recognizer.is_ready(stream):
                svc.recognizer.decode_stream(stream)
            svc.recognizer.tokens(stream)
            t[s].append(time.perf_counter() - t0)
    base = sum(t["zeros"])
    print(f"{n} learner clips, {audio:.0f}s audio, rotating order")
    for s in STRATS:
        print(f"  {s:9s} total {sum(t[s]):6.2f}s  median {1000 * st.median(t[s]):6.1f} ms  "
              f"({100 * (sum(t[s]) / base - 1):+.1f}% vs zeros)  of which making the padding {1000 * st.median(pad_t[s]):.2f} ms")


if __name__ == "__main__":
    main()
