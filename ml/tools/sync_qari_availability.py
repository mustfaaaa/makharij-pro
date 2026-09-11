"""Bring each qari's `availableSurahs` in line with the audio actually on disk.

Why derived rather than declared
--------------------------------
The recitation endpoint refuses a surah unless it appears in the qari's
`availableSurahs`. That list was written by hand when three reciters shared the
same fifteen surahs. Now one of them has the complete Quran and the others do
not, so a hand-kept list would be wrong for somebody the moment it was written.

So this reads the truth off the filesystem: a surah counts as available for a
reciter only when *every* one of its ayahs is present and is a real file rather
than a truncated download. A partially-downloaded surah would otherwise offer a
"listen" button that dies in the middle of an ayah.

Safe to re-run; it only writes when the computed list differs from the stored
one, and prints what changed.

    backend/.venv/Scripts/python.exe ml/tools/sync_qari_availability.py
    backend/.venv/Scripts/python.exe ml/tools/sync_qari_availability.py --dry-run
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "backend"))

from app.firebase_admin_setup import get_firestore_client, init_firebase  # noqa: E402
from app.quran_metadata import SURAH_AYAH_COUNTS  # noqa: E402

RECITATIONS = REPO / "backend" / "app" / "static" / "recitations"
MIN_BYTES = 1500          # smaller than this is a stub, not audio


def complete_surahs(qari_dir: Path) -> list[int]:
    present = {
        p.name for p in qari_dir.glob("*.mp3")
        if p.stat().st_size >= MIN_BYTES
    }
    out = []
    for surah, count in sorted(SURAH_AYAH_COUNTS.items()):
        if all(f"{surah:03d}{ayah:03d}.mp3" in present for ayah in range(1, count + 1)):
            out.append(surah)
    return out


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    init_firebase()
    db = get_firestore_client()

    for qari_dir in sorted(p for p in RECITATIONS.iterdir() if p.is_dir()):
        qari_id = qari_dir.name
        available = complete_surahs(qari_dir)
        doc_ref = db.collection("qaris").document(qari_id)
        doc = doc_ref.get()
        if not doc.exists:
            print(f"  {qari_id}: no qari record in Firestore, skipped")
            continue

        stored = sorted(doc.to_dict().get("availableSurahs", []))
        if stored == available:
            print(f"  {qari_id}: unchanged ({len(available)} surahs)")
            continue

        added = sorted(set(available) - set(stored))
        removed = sorted(set(stored) - set(available))
        print(f"  {qari_id}: {len(stored)} -> {len(available)} surahs"
              f"{f', +{len(added)}' if added else ''}"
              f"{f', -{len(removed)}' if removed else ''}")
        if removed:
            print(f"      losing: {removed[:10]}{' ...' if len(removed) > 10 else ''}")
        if args.dry_run:
            continue
        doc_ref.update({"availableSurahs": available})

    if args.dry_run:
        print("\n  dry run -- nothing written")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
