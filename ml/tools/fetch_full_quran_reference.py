"""Fetch one reciter's complete Quran, for evaluating across all 114 surahs.

Why
---
The repository ships 86 ayahs of reference audio -- Al-Fatihah and the last
fourteen surahs -- for three reciters. That is enough to measure the analyser on
short surahs with short ayahs, and every number in ml/eval/crossmodel comes from
it. It cannot answer what happens on the long ayahs that make up most of the
Quran, and the two are measurably different: verdicts need several *words* of
following context to settle, so an ayah of three words and an ayah of twenty
words are not the same test.

Deliberately written to a separate directory rather than into
backend/app/static/recitations. Dropping 6,236 files there would silently change
what the app serves -- the "listen to a Qari" button would start working for
surahs the app's own metadata does not claim to cover -- and that is a product
decision, not a side effect of an evaluation script.

Resumable: a file already on disk with a sane size is skipped, so an interrupted
run costs nothing.

    backend/.venv/Scripts/python.exe ml/tools/fetch_full_quran_reference.py
    backend/.venv/Scripts/python.exe ml/tools/fetch_full_quran_reference.py --reciter Husary_64kbps
"""
from __future__ import annotations

import argparse
import concurrent.futures as futures
import json
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "backend"))

BASE = "https://everyayah.com/data"
OUT_ROOT = REPO / "ml" / "data" / "reference_full"

# Ayah counts for all 114 surahs. The app's own quran_metadata covers only the
# fifteen surahs it serves, so this cannot come from there.
AYAH_COUNTS = [
    7, 286, 200, 176, 120, 165, 206, 75, 129, 109, 123, 111, 43, 52, 99, 128,
    111, 110, 98, 135, 112, 78, 118, 64, 77, 227, 93, 88, 69, 60, 34, 30, 73,
    54, 45, 83, 182, 88, 75, 85, 54, 53, 89, 59, 37, 35, 38, 29, 18, 45, 60,
    49, 62, 55, 78, 96, 29, 22, 24, 13, 14, 11, 11, 18, 12, 12, 30, 52, 52,
    44, 28, 28, 20, 56, 40, 31, 50, 40, 46, 42, 29, 19, 36, 25, 22, 17, 19,
    26, 30, 20, 15, 21, 11, 8, 8, 19, 5, 8, 8, 11, 11, 8, 3, 9, 5, 4, 7, 3,
    6, 3, 5, 4, 5, 6,
]

MIN_BYTES = 1500          # anything smaller is an error page, not audio


def fetch_one(reciter: str, surah: int, ayah: int, out_dir: Path,
              retries: int = 3) -> tuple[str, int]:
    name = f"{surah:03d}{ayah:03d}.mp3"
    target = out_dir / name
    if target.is_file() and target.stat().st_size >= MIN_BYTES:
        return "skip", target.stat().st_size

    url = f"{BASE}/{reciter}/{name}"
    for attempt in range(retries):
        try:
            request = urllib.request.Request(
                url, headers={"User-Agent": "makharij-pro-eval/1.0"})
            with urllib.request.urlopen(request, timeout=30) as response:
                data = response.read()
            if len(data) < MIN_BYTES:
                return "bad", len(data)
            # Write via a temp name so an interrupted run never leaves a
            # half-file that the next run would treat as complete.
            tmp = target.with_suffix(".part")
            tmp.write_bytes(data)
            tmp.replace(target)
            return "ok", len(data)
        except (urllib.error.URLError, TimeoutError, OSError):
            if attempt == retries - 1:
                return "fail", 0
            time.sleep(1.5 * (attempt + 1))
    return "fail", 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--reciter", default="Abdurrahmaan_As-Sudais_64kbps")
    parser.add_argument("--workers", type=int, default=6,
                        help="kept modest on purpose: this is someone else's server")
    parser.add_argument("--out", type=Path, default=None)
    args = parser.parse_args()

    out_dir = args.out or (OUT_ROOT / args.reciter)
    out_dir.mkdir(parents=True, exist_ok=True)

    jobs = [(s, a) for s, count in enumerate(AYAH_COUNTS, start=1)
            for a in range(1, count + 1)]
    print(f"{args.reciter}: {len(jobs)} ayahs -> {out_dir}")

    done = {"ok": 0, "skip": 0, "fail": 0, "bad": 0}
    total_bytes = 0
    failures: list[str] = []
    started = time.time()

    with futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
        pending = {pool.submit(fetch_one, args.reciter, s, a, out_dir): (s, a)
                   for s, a in jobs}
        for i, future in enumerate(futures.as_completed(pending), 1):
            surah, ayah = pending[future]
            status, size = future.result()
            done[status] += 1
            total_bytes += size
            if status in ("fail", "bad"):
                failures.append(f"{surah:03d}{ayah:03d}")
            if i % 250 == 0 or i == len(jobs):
                rate = i / max(time.time() - started, 1)
                print(f"  {i}/{len(jobs)}  ok={done['ok']} skip={done['skip']} "
                      f"fail={done['fail']+done['bad']}  "
                      f"{total_bytes/1e6:.0f} MB  {rate:.0f}/s")

    summary = {
        "reciter": args.reciter,
        "ayahs_expected": len(jobs),
        "downloaded": done["ok"],
        "already_present": done["skip"],
        "failed": done["fail"] + done["bad"],
        "megabytes": round(total_bytes / 1e6, 1),
        "failures": failures[:200],
    }
    (out_dir / "_fetch_report.json").write_text(
        json.dumps(summary, indent=2), encoding="utf-8")

    print()
    print(f"  downloaded : {done['ok']}")
    print(f"  skipped    : {done['skip']}")
    print(f"  failed     : {done['fail'] + done['bad']}")
    print(f"  size       : {total_bytes/1e6:.0f} MB")
    if failures:
        print(f"  re-run to retry {len(failures)} missing files")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
