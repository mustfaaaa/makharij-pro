"""One-time script: extracts our chosen surahs/reciters from the downloaded parquet shards,
writes each clip to LOCAL disk under app/static/recitations/{qari_id}/{surah:03d}{ayah:03d}.mp3,
and writes the `qaris` Firestore catalogue (SDD Section 5 schema, adapted -- see README's "Rattil
AI repository" section for why this is local-disk rather than Cloud Storage: Firebase Storage now
requires a linked billing account even for trivial usage, and this is a free-tier prototype).
Re-runnable -- skips files already written, and upserts (not duplicates) the Firestore catalogue.

Scope: 15 short surahs (1, 101-114) x 3 SRS-named Qaris, not the full Quran -- see
backend/README.md for how to add more later. Surah 100 is deliberately excluded: the source
dataset is missing ayahs 1-2 for all three reciters there, a real gap, not a bug here.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import firebase_admin
import pandas as pd
from firebase_admin import credentials, firestore

from app import config
from app.quran_metadata import SURAH_AYAH_COUNTS

SURAHS = sorted(SURAH_AYAH_COUNTS.keys())

QARIS = {
    "alafasy": {"nameArabic": "مشاري بن راشد العفاسي", "nameEnglish": "Mishary Rashid Alafasy"},
    "abdurrahmaan_as_sudais": {"nameArabic": "عبد الرحمن السديس", "nameEnglish": "Abdul Rahman As-Sudais"},
    "yasser_ad_dussary": {"nameArabic": "ياسر الدوسري", "nameEnglish": "Yasser Al-Dosari"},
}

_HF_CACHE = r"C:\Users\shahs\.cache\huggingface\hub\datasets--Buraaq--quran-md-ayahs\snapshots\669e9c4b78716d4558cebab98e1072564801fbb0\data"
SHARD_PATHS = [
    f"{_HF_CACHE}\\train-00000-of-00071.parquet",  # contains surah 1
    f"{_HF_CACHE}\\train-00070-of-00071.parquet",  # contains surahs 108, 112-114
]

RECITATIONS_DIR = Path(__file__).resolve().parent.parent / "app" / "static" / "recitations"


def init_firebase():
    if not firebase_admin._apps:
        cred = credentials.Certificate(str(config.FIREBASE_SERVICE_ACCOUNT_PATH))
        firebase_admin.initialize_app(cred)


def main():
    init_firebase()
    db = firestore.client()

    frames = []
    for shard_path in SHARD_PATHS:
        if not Path(shard_path).exists():
            print(f"MISSING: {shard_path} -- run the download step first.")
            return
        df = pd.read_parquet(shard_path)
        frames.append(df[df["surah_id"].isin(SURAHS) & df["reciter_id"].isin(QARIS.keys())])
    subset = pd.concat(frames, ignore_index=True)
    total_ayat = sum(SURAH_AYAH_COUNTS.values())
    print(f"Found {len(subset)} matching rows "
          f"(expect {total_ayat} total ayat x {len(QARIS)} reciters = {total_ayat * len(QARIS)})")

    n_written, n_skipped = 0, 0
    for _, row in subset.iterrows():
        qari_id = row["reciter_id"]
        surah, ayah = int(row["surah_id"]), int(row["ayah_id"])
        qari_dir = RECITATIONS_DIR / qari_id
        qari_dir.mkdir(parents=True, exist_ok=True)
        out_path = qari_dir / f"{surah:03d}{ayah:03d}.mp3"
        if out_path.exists():
            n_skipped += 1
            continue
        audio_bytes = row["audio"]["bytes"]
        out_path.write_bytes(audio_bytes)
        n_written += 1

    print(f"Wrote {n_written} new clips, skipped {n_skipped} already present.")
    print(f"Repository root: {RECITATIONS_DIR}")

    for qari_id, meta in QARIS.items():
        db.collection("qaris").document(qari_id).set({
            "qariId": qari_id,
            "nameArabic": meta["nameArabic"],
            "nameEnglish": meta["nameEnglish"],
            "servingMode": "local",  # vs. "cloud_storage" once migrated
            "localFolderPath": f"recitations/{qari_id}/",
            "availableSurahs": SURAHS,
        })
    print(f"Wrote/updated {len(QARIS)} qaris catalogue documents in Firestore.")


if __name__ == "__main__":
    main()
