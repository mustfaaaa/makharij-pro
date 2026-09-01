"""Not a proper test suite -- a quick sanity pass verifying the model loads, the two-input
architecture is wired correctly, and feature extraction + resampling don't crash. Predictions on
synthetic noise are meaningless; this only checks the pipeline runs end-to-end without exceptions.
"""
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.model_service import TajweedModelService  # noqa: E402


def main():
    print("Loading model...")
    service = TajweedModelService()
    print("Model loaded OK.\n")

    print("Test 1: synthetic 16kHz audio (native rate, no resampling needed)")
    sr = 16000
    duration = 6.0
    t = np.linspace(0, duration, int(sr * duration), dtype=np.float32)
    y = 0.3 * np.sin(2 * np.pi * 220 * t) + 0.02 * np.random.randn(len(t)).astype(np.float32)
    results = service.predict_from_waveform(y, sr)
    for task, r in results.items():
        print(f"  {task}: correct={r['correct']} confidence={r['confidence']:.3f} "
              f"raw_prob={r['raw_probability']:.3f} threshold={r['threshold_used']}")

    print("\nTest 2: synthetic 44.1kHz audio (exercises the resample path)")
    sr2 = 44100
    t2 = np.linspace(0, duration, int(sr2 * duration), dtype=np.float32)
    y2 = 0.3 * np.sin(2 * np.pi * 220 * t2) + 0.02 * np.random.randn(len(t2)).astype(np.float32)
    results2 = service.predict_from_waveform(y2, sr2)
    for task, r in results2.items():
        print(f"  {task}: correct={r['correct']} confidence={r['confidence']:.3f} "
              f"raw_prob={r['raw_probability']:.3f} threshold={r['threshold_used']}")

    print("\nSmoke test passed: model loaded, both sample rates processed without error.")


if __name__ == "__main__":
    main()
