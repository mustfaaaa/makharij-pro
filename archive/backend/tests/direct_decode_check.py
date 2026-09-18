"""Isolates whether writing test clips to WAV and reloading them (an extra round-trip the
training pipeline never did) changes predictions vs. feeding the decoded array directly."""
import io
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from datasets import Audio, load_dataset
import soundfile as sf

from app.model_service import TajweedModelService

qdat = load_dataset("obadx/qdat")["train"]
qdat = qdat.cast_column("audio", Audio(decode=False))

CASES = [
    {"name": "correct", "row_index": 569, "id": "8f24c17c",
     "expected": {"separate_tide": 1, "the_tight_noon": 1, "concealment": 1}},
    {"name": "incorrect", "row_index": 1149, "id": "b57ee055",
     "expected": {"separate_tide": 0, "the_tight_noon": 0, "concealment": 0}},
    {"name": "incorrect_typical", "row_index": 1364, "id": "8afc068d",
     "expected": {"separate_tide": 0, "the_tight_noon": 0, "concealment": 0}},
]

print("Loading model...")
service = TajweedModelService()
print("Model loaded.\n")

for case in CASES:
    ex = qdat[case["row_index"]]
    assert ex["id"] == case["id"]
    array, sr = sf.read(io.BytesIO(ex["audio"]["bytes"]))
    results = service.predict_from_waveform(array, sr)  # no WAV write/reread in between
    print(f"=== {case['name']} (direct decode, no WAV round-trip) ===")
    for task, r in results.items():
        predicted = 1 if r["correct"] else 0
        expected = case["expected"][task]
        match = "MATCH" if predicted == expected else "MISMATCH"
        print(f"  {task:16s} expected={expected} predicted={predicted} (prob={r['raw_probability']:.3f})  [{match}]")
    print()
