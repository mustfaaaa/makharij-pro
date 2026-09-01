"""Finds a real test-split clip the MODEL itself predicts as incorrect on at least one rule
(not just ground-truth-incorrect) -- needed to meaningfully test the /reattempt endpoint."""
import io
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import pandas as pd
import soundfile as sf
from datasets import Audio, load_dataset

from app.model_service import TajweedModelService

df = pd.read_csv("../ml/models/makharijpro_tajweed_model_v1/qdat_manifest.csv")
test_rows = df[df["split"] == "test"].sample(n=15, random_state=7)

qdat = load_dataset("obadx/qdat")["train"]
qdat = qdat.cast_column("audio", Audio(decode=False))

print("Loading model...")
service = TajweedModelService()
print("Model loaded.\n")

for _, row in test_rows.iterrows():
    ex = qdat[int(row["row_index"])]
    array, sr = sf.read(io.BytesIO(ex["audio"]["bytes"]))
    results = service.predict_from_waveform(array, sr)
    flagged = [t for t, r in results.items() if not r["correct"]]
    print(f"id={row['id']} row={row['row_index']} model_flagged_incorrect={flagged or 'none'}")
    if flagged:
        out_path = f"tests/real_model_flagged_{row['id']}.wav"
        sf.write(out_path, array, sr)
        print(f"  -> saved {out_path}")
