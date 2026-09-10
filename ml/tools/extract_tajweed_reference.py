"""Extract the per-word Tajweed reference table from the makharij_dataset
project into a standalone asset this app can serve.

What this takes, and what it deliberately leaves behind
-------------------------------------------------------
`makharij_dataset` holds two very different things in one parquet:

  * 256-dim reference EMBEDDINGS from a single reciter -- measured this week
    to reject 560 correctly-recited learner words as "does not resemble the
    expected word". Those are not taken.
  * a per-word TAJWEED EXPECTATION table covering all 77,429 word positions --
    which Makhraj each word starts from, which rules apply, the prescribed madd
    length. That is derived from Quran-Lab's phone sequences, so it is a
    property of the TEXT, not of anyone's recording.

Only the second is extracted. It runs no model, needs no torch, and none of the
model's measured failures apply to it: it is reference data about the Quran,
not a prediction about audio.

That matters because this app currently has no per-word teaching content at
all. This table can say "this word begins from `ash_shafatain` (ب م و) and
carries a 4-count madd" for every word of the Quran, with no inference and no
uncertainty to communicate.

Word indexing -- read this before using the output
--------------------------------------------------
The source indexes words 1-based within an ayah, and EXCLUDES the Basmala.
This app displays words 0-based and PREPENDS the Basmala to every surah's
ayah 1 (except Al-Fatihah, where it is ayah 1, and the surahs that carry none).

    reference_index = app_word_index - basmala_prefix_len(surah, ayah) + 1

Verified against the running app: S108:A1 shows 7 words with a 4-word Basmala
prefix while the reference holds 3, so the reference's word 1 is the app's
index 4. `backend/app/tajweed_reference.py` owns that conversion so it lives in
exactly one place.

Attribution
-----------
The Tajweed attributes derive from Quran-Lab/quran-tajweed-phonetics and the
word forms from Buraaq/quran-md-words. Both are third-party datasets; check
their licences before shipping this asset publicly.

Run:
    backend/.venv/Scripts/python.exe ml/tools/extract_tajweed_reference.py
"""
from __future__ import annotations

import argparse
import sqlite3
import sys
from pathlib import Path

import pandas as pd

REPO = Path(__file__).resolve().parents[2]
SOURCE = Path(r"C:\makharij_dataset\processed\references\reference_embeddings.parquet")
OUT_DIR = REPO / "backend" / "app" / "data"
SQLITE_PATH = OUT_DIR / "tajweed_reference.sqlite3"
PARQUET_PATH = OUT_DIR / "tajweed_reference.parquet"

# source column -> the name this app will use. Everything not listed is left
# behind: embedding_row, audio_uid, sample_id_md, unit_id and split are all
# internal to the training project and meaningless here.
COLUMNS = {
    "surah_id": "surah",
    "ayah_id": "ayah",
    "word_index": "word_index",
    "word_ar": "word_ar",
    "word_tr": "word_tr",
    "primary_consonant_makhraj_17_v2": "makhraj",
    "consonant_makhraj_17_set_v2": "makhraj_set",
    "target_ghunnah_v2": "has_ghunnah",
    "target_shaddah_v2": "has_shaddah",
    "target_madd_v2": "has_madd",
    "target_qalqalah_v2": "has_qalqalah",
    "target_tafkheem_v2": "has_tafkheem",
    "madd_length_class": "madd_length",
    "qalqalah_class": "qalqalah_class",
    "ghunna_primary": "ghunnah_type",
    "tafkheem_class": "tafkheem_class",
    "n_phones_v2": "n_phones",
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=SOURCE)
    args = parser.parse_args()

    if not args.source.is_file():
        print(f"source not found: {args.source}", file=sys.stderr)
        return 1

    print(f"reading {args.source.name} ...")
    frame = pd.read_parquet(args.source, columns=list(COLUMNS))
    frame = frame.rename(columns=COLUMNS)
    print(f"  {len(frame):,} rows, {len(frame.columns)} columns")

    # ---- verification, before anything is written -------------------------
    problems: list[str] = []

    if frame[["surah", "ayah", "word_index"]].duplicated().any():
        n = int(frame[["surah", "ayah", "word_index"]].duplicated().sum())
        problems.append(f"{n} duplicate (surah, ayah, word_index) keys")

    surahs = frame.surah.nunique()
    if surahs != 114:
        problems.append(f"expected 114 surahs, found {surahs}")

    ayahs = frame.groupby(["surah", "ayah"]).ngroups
    if ayahs != 6236:
        problems.append(f"expected 6236 ayahs, found {ayahs}")

    if int(frame.word_index.min()) != 1:
        problems.append(f"word_index is not 1-based (min={frame.word_index.min()})")

    for column in ("makhraj", "word_ar"):
        missing = int(frame[column].isna().sum()) + int((frame[column] == "").sum())
        if missing:
            problems.append(f"{missing} rows with empty {column}")

    print("\nverification:")
    if problems:
        for problem in problems:
            print(f"  FAIL  {problem}")
        print("\nrefusing to write a table that does not verify.", file=sys.stderr)
        return 1
    print(f"  OK  {len(frame):,} rows, {surahs} surahs, {ayahs} ayahs, no duplicate keys")
    print(f"  OK  word_index 1..{int(frame.word_index.max())}, no empty makhraj or word_ar")

    # Booleans arrive as numpy bool_; sqlite wants plain ints.
    for column in [c for c in frame.columns if c.startswith("has_")]:
        frame[column] = frame[column].astype(int)

    OUT_DIR.mkdir(parents=True, exist_ok=True)

    frame.to_parquet(PARQUET_PATH, index=False)

    if SQLITE_PATH.exists():
        SQLITE_PATH.unlink()
    connection = sqlite3.connect(SQLITE_PATH)
    try:
        frame.to_sql("tajweed_word", connection, index=False)
        # The only access pattern this asset has is "look up one word", so the
        # primary key is the whole point rather than an afterthought.
        connection.execute(
            "CREATE UNIQUE INDEX idx_word ON tajweed_word (surah, ayah, word_index)")
        connection.execute("VACUUM")
        connection.commit()
    finally:
        connection.close()

    print("\nwritten:")
    for path in (SQLITE_PATH, PARQUET_PATH):
        print(f"  {path.relative_to(REPO)}  ({path.stat().st_size / 1048576:.2f} MB)")

    print("\ncoverage by rule (share of all 77,429 words):")
    for column in [c for c in frame.columns if c.startswith("has_")]:
        share = 100.0 * frame[column].mean()
        print(f"  {column:16} {share:5.1f}%")
    print(f"\ndistinct makhraj classes: {frame.makhraj.nunique()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
