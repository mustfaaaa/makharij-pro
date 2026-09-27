"""What should follow a recording into the recognizer? (evaluation only)

Runs the full harness with the end padding swapped for a candidate strategy,
without touching production code: harness.decode is replaced for the run, so
the learner set, the experts and the controlled edits all use the candidate.
Everything else (PCM16 round trip, streaming decode, alignment, verdicts) is
the production code path.

Strategies (1.5 s unless named otherwise, noise from a fixed seed):
  zeros        digital silence -- the baseline
  n60          noise at -60 dBFS -- C1 as committed
  n70          noise at -70 dBFS
  n80          noise at -80 dBFS
  floor10      noise 10 dB below the recording's own noise floor (10th-percentile
               25 ms frame), clamped to [-90, -50] dBFS
  roomtone     the recording's own quietest 200 ms, looped with crossfades
  n70_1s       noise at -70 dBFS, 1.0 s
Suffix _s1 = the same strategy with noise seed 1 (decoder-stability check).

    backend/.venv/Scripts/python.exe ml/eval/tajweed_rules/padding_experiment.py n70 [--sets learners --no-edits]
"""
import io
import json
import sys

import librosa
import numpy as np

import harness as H
import run_version

PAD_SEC = 1.5


def noise(db: float, sec: float = PAD_SEC, seed: int = 0) -> np.ndarray:
    return (np.random.default_rng(seed).standard_normal(int(sec * H.SR)) * 10 ** (db / 20)).astype(np.float32)


def floor_db(y: np.ndarray) -> float:
    frame = 400
    n = len(y) // frame
    if n == 0:
        return -90.0
    db = 20 * np.log10(np.sqrt((y[: n * frame].reshape(n, frame).astype(np.float64) ** 2).mean(axis=1)) + 1e-9)
    return float(np.percentile(db, 10))


def room_tone(y: np.ndarray, sec: float = PAD_SEC) -> np.ndarray:
    win = int(0.2 * H.SR)
    if len(y) < win * 2:
        return np.zeros(int(sec * H.SR), np.float32)
    hop = int(0.025 * H.SR)
    starts = range(0, len(y) - win, hop)
    s0 = min(starts, key=lambda s: float(np.mean(y[s:s + win] ** 2)))
    chunk = y[s0:s0 + win]
    out = chunk
    while len(out) < int(sec * H.SR):
        out = H.xfade_join(out, chunk)
    return out[: int(sec * H.SR)].astype(np.float32)


def make_pad(strategy: str, y: np.ndarray) -> np.ndarray:
    base, seed = (strategy[:-3], 1) if strategy.endswith("_s1") else (strategy, 0)
    if base == "zeros":
        return np.zeros(int(PAD_SEC * H.SR), np.float32)
    if base in ("n60", "n70", "n80"):
        return noise(-float(base[1:]), seed=seed)
    if base == "n70_1s":
        return noise(-70.0, sec=1.0, seed=seed)
    if base == "floor10":
        return noise(min(max(floor_db(y) - 10.0, -90.0), -50.0), seed=seed)
    if base == "roomtone":
        return room_tone(y)
    raise SystemExit(f"unknown strategy {strategy}")


def strategy_decode(strategy):
    def decode(svc, y):
        # Exactly what _decode does to the audio before it reaches the recognizer.
        y16 = librosa.load(io.BytesIO(H.wav_bytes(y)), sr=H.SR, mono=True)[0].astype(np.float32)
        stream = svc.recognizer.create_stream()
        stream.accept_waveform(H.SR, y16)
        stream.accept_waveform(H.SR, make_pad(strategy, y16))
        stream.input_finished()
        while svc.recognizer.is_ready(stream):
            svc.recognizer.decode_stream(stream)
        return svc.recognizer.tokens(stream), svc.recognizer.timestamps(stream)
    return decode


def main():
    strategy = sys.argv[1]
    H.decode = strategy_decode(strategy)
    run_version.main([f"pad_{strategy}"] + sys.argv[2:], note=f"padding experiment: {strategy}")


if __name__ == "__main__":
    main()
