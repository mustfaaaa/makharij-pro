"""Turns the downloaded Quranic Audio Dataset into an evaluation set the app's
own pipeline can be run against.

Keeps only clips that are (a) labelled correct/incorrect by a human and (b)
resolvable to a specific ayah, extracts their audio once, and writes a manifest.
Everything else -- unlabelled clips, non-Quran recordings, ayah fragments -- is
counted and reported rather than silently dropped.

    python ml/eval/build_manifest.py
"""
import argparse
import csv
import json
import sys
from collections import Counter
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, str(Path(__file__).resolve().parent))

import pyarrow.parquet as pq
from quran_match import AyahResolver

ROOT = Path(__file__).resolve().parent.parent.parent
DATA_DIR = ROOT / "ml" / "data" / "quranic_audio_dataset"
OUT_DIR = DATA_DIR / "evalset"

# The two labels that state whether the recitation itself was right. The others
# (not_related_quran, multiple_aya, not_match_aya, in_complete) describe what
# was recorded, not how well it was recited, so they can't score the detector.
SCORING_LABELS = {"correct": True, "in_correct": False}

COLUMNS = ["audio", "Surah", "Aya", "final_label", "golden", "reciter_id",
           "reciter_country", "reciter_gender", "reciter_age", "duration_ms"]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--data-dir", type=Path, default=DATA_DIR)
    parser.add_argument("--out-dir", type=Path, default=OUT_DIR)
    args = parser.parse_args()

    files = sorted(args.data_dir.glob("train-*.parquet"))
    if not files:
        print(f"No parquet files in {args.data_dir} -- see ml/eval/README.md")
        return 1

    clips_dir = args.out_dir / "clips"
    clips_dir.mkdir(parents=True, exist_ok=True)
    resolver = AyahResolver()

    dropped = Counter()
    rows = []

    for path in files:
        for batch in pq.ParquetFile(path).iter_batches(batch_size=512, columns=COLUMNS):
            for row in batch.to_pylist():
                label = row["final_label"]
                if label not in SCORING_LABELS:
                    dropped["unlabelled" if label is None else f"label:{label}"] += 1
                    continue

                placed = resolver.resolve(row["Surah"], row["Aya"])
                if placed is None:
                    dropped["unresolvable ayah"] += 1
                    continue
                surah, ayah = placed

                audio = row["audio"] or {}
                data = audio.get("bytes")
                if not data:
                    dropped["no audio"] += 1
                    continue

                clip_id = Path(audio.get("path") or f"{len(rows)}.wav").stem
                (clips_dir / f"{clip_id}.wav").write_bytes(data)
                rows.append({
                    "clip_id": clip_id,
                    "file": f"clips/{clip_id}.wav",
                    "surah": surah,
                    "ayah": ayah,
                    "label": label,
                    "recited_correctly": int(SCORING_LABELS[label]),
                    "golden": int(bool(row["golden"])),
                    "reciter_id": row["reciter_id"] or "Unknown",
                    "country": row["reciter_country"] or "Unknown",
                    "gender": row["reciter_gender"] or "Unknown",
                    "age": row["reciter_age"] or "Unknown",
                    "duration_ms": row["duration_ms"],
                })

    manifest = args.out_dir / "manifest.csv"
    with open(manifest, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)

    labels = Counter(r["label"] for r in rows)
    summary = {
        "clips": len(rows),
        "by_label": dict(labels),
        "by_gender": dict(Counter(r["gender"] for r in rows)),
        "by_age": dict(Counter(r["age"] for r in rows)),
        "distinct_reciters": len({r["reciter_id"] for r in rows}),
        "distinct_countries": len({r["country"] for r in rows}),
        "distinct_ayahs": len({(r["surah"], r["ayah"]) for r in rows}),
        "dropped": dict(dropped),
    }
    (args.out_dir / "summary.json").write_text(
        json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8"
    )

    print(f"wrote {manifest}  ({len(rows)} clips)")
    print(f"  correct    : {labels['correct']}")
    print(f"  in_correct : {labels['in_correct']}")
    print(f"  reciters   : {summary['distinct_reciters']}   "
          f"countries: {summary['distinct_countries']}   "
          f"ayahs: {summary['distinct_ayahs']}")
    print("  dropped    :")
    for reason, n in dropped.most_common():
        print(f"    {reason:22} {n}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
