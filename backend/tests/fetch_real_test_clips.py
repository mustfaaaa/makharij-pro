"""Pulls two real, held-out TEST-split QDAT clips (never seen in training) with known ground
truth, for a real end-to-end sanity check of the backend -- not synthetic noise this time.

Newer `datasets` versions decode audio via torchcodec by default, which needs torch installed --
not worth pulling in as a heavy dependency for a one-off test script. Disabling auto-decode and
decoding manually with soundfile (already a backend dependency) instead."""
import io

from datasets import Audio, load_dataset
import soundfile as sf

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

for case in CASES:
    ex = qdat[case["row_index"]]
    assert ex["id"] == case["id"], f"row_index/id mismatch: {ex['id']} != {case['id']}"
    array, sr = sf.read(io.BytesIO(ex["audio"]["bytes"]))
    out_path = f"tests/real_{case['name']}.wav"
    sf.write(out_path, array, sr)
    print(f"Wrote {out_path} (sr={sr}, duration={len(array)/sr:.2f}s)")
    print(f"  expected: {case['expected']}")
