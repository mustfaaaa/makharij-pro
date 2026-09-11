"""The analyser against one reciter's complete Quran.

Why this is a different test from everything else here
------------------------------------------------------
Every number in ml/eval/crossmodel comes from 86 ayahs -- Al-Fatihah and the
last fourteen surahs -- because that is all the reference audio the repository
ships. Those ayahs run three to five words. Most of the Quran does not: ayahs of
fifteen, thirty, even eighty words are ordinary outside Juz 30, and the analyser
behaves measurably differently on them, because a verdict needs several *words*
of following context before it settles.

So a result that holds on Al-Ikhlas says very little about Al-Baqarah. This runs
all 114 surahs.

What counts as an error
-----------------------
The audio is a professional reciter, so every word is correct by construction.
Any word reported as a mistake is a false alarm, and any word reported as never
recited is wrong too -- he recited all of them. No labelling and no judgement
call, which is what makes the whole Quran usable as a test set.

Each ayah is analysed on its own, the way a single-ayah practice session is. The
alignment is O(predicted x expected), so feeding it a two-hour surah in one call
is not a test, it is a different and much harder problem.

    backend/.venv/Scripts/python.exe ml/eval/measure_full_quran.py
    backend/.venv/Scripts/python.exe ml/eval/measure_full_quran.py --max-surah 30
"""
from __future__ import annotations

import argparse
import json
import sys
import time
from collections import Counter
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "backend"))
sys.path.insert(0, str(REPO / "ml" / "tools"))

from app.phoneme_analysis_service import PhonemeAnalysisService  # noqa: E402

from fetch_full_quran_reference import AYAH_COUNTS  # noqa: E402

AUDIO_ROOT = REPO / "ml" / "data" / "reference_full"
OUT = Path(__file__).resolve().parent / "results" / "full_quran.json"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--reciter", default="Abdurrahmaan_As-Sudais_64kbps")
    parser.add_argument("--max-surah", type=int, default=114)
    parser.add_argument("--out", type=Path, default=OUT)
    args = parser.parse_args()

    audio_dir = AUDIO_ROOT / args.reciter
    if not audio_dir.is_dir():
        print(f"No audio at {audio_dir} -- run ml/tools/fetch_full_quran_reference.py")
        return 1

    print("loading the phoneme model...")
    service = PhonemeAnalysisService()

    ayahs = words = flagged = unread = 0
    ayahs_clean = 0
    by_rule = Counter()
    per_surah: dict[str, dict] = {}
    worst: list[dict] = []
    started = time.time()

    for surah in range(1, args.max_surah + 1):
        count = AYAH_COUNTS[surah - 1]
        s_words = s_flagged = s_unread = 0
        for ayah in range(1, count + 1):
            mp3 = audio_dir / f"{surah:03d}{ayah:03d}.mp3"
            if not mp3.is_file():
                continue
            try:
                results = service.analyze_range(mp3.read_bytes(), surah, ayah, ayah)
            except Exception:
                continue

            ayahs += 1
            bad = [r for r in results if r.recited and not r.correct]
            missing = [r for r in results if not r.recited]
            words += len(results)
            flagged += len(bad)
            unread += len(missing)
            s_words += len(results)
            s_flagged += len(bad)
            s_unread += len(missing)
            for r in bad:
                by_rule[r.error_type or "unknown"] += 1
            if not bad and not missing:
                ayahs_clean += 1
            elif len(bad) + len(missing) >= max(3, len(results) // 2):
                worst.append({
                    "ayah": f"{surah}:{ayah}", "words": len(results),
                    "flagged": len(bad), "unread": len(missing),
                })

        if s_words:
            per_surah[f"S{surah}"] = {
                "words": s_words,
                "flagged_pct": round(100 * s_flagged / s_words, 1),
                "unread_pct": round(100 * s_unread / s_words, 1),
            }
        if surah % 10 == 0 or surah == args.max_surah:
            rate = ayahs / max(time.time() - started, 1)
            print(f"  surah {surah}/{args.max_surah}  ayahs={ayahs} "
                  f"flagged={100*flagged/max(words,1):.1f}% "
                  f"unread={100*unread/max(words,1):.1f}%  ({rate:.1f} ayah/s)")

    pct = lambda n, d: round(100 * n / max(d, 1), 1)  # noqa: E731
    summary = {
        "what": "a professional reciter's complete Quran; every flag is a false alarm",
        "reciter": args.reciter,
        "ayahs_analysed": ayahs,
        "ayahs_completely_clean_pct": pct(ayahs_clean, ayahs),
        "words": words,
        "words_wrongly_flagged_pct": pct(flagged, words),
        "words_wrongly_unread_pct": pct(unread, words),
        "flags_by_rule": dict(by_rule.most_common()),
        "worst_ayahs": sorted(
            worst, key=lambda w: -(w["flagged"] + w["unread"]))[:40],
        "per_surah": per_surah,
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")

    print()
    print("=" * 62)
    print("FULL QURAN, PERFECT RECITATION -- every error here is ours")
    print("=" * 62)
    print(f"  ayahs analysed            : {ayahs}")
    print(f"  ayahs with nothing wrong  : {summary['ayahs_completely_clean_pct']}%")
    print(f"  words                     : {words}")
    print(f"  ...wrongly flagged        : {summary['words_wrongly_flagged_pct']}%")
    print(f"  ...wrongly unread         : {summary['words_wrongly_unread_pct']}%")
    print()
    print("  flags by rule:")
    for rule, n in by_rule.most_common():
        print(f"    {rule:<12} {n:>6}  ({pct(n, flagged)}% of flags)")
    print(f"\n  written to {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
