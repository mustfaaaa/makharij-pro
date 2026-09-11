"""Where should the tail bar sit? Measured on both regimes at once.

The tension
-----------
TAIL_EXTEND_RATIO decides how strongly the *last* word of a recited span must
match before the span is allowed to reach it. It was raised from 0.75 to 0.85 to
stop the results screen highlighting words the reciter never reached -- measured
on truncated recitations, where someone stops part-way and everything after the
stop is spill.

Learner recordings are the opposite regime. There the reciter finished, so the
last word is genuinely theirs, and a bar that walks the span back marks a word
they did say as never recited. On the labelled corpus that is now the single
largest visible error: 25.3% of words on correctly-recited clips are wrongly
greyed out.

One threshold serves both, so it cannot be chosen from either alone. This runs
both at every candidate value.

Why it is not four times the work
---------------------------------
The threshold changes nothing before the decode -- same audio, same recognizer,
same phonemes. Only the span logic downstream differs. So each clip is decoded
once and replayed against every threshold, which is what makes sweeping four
values affordable.

    backend/.venv/Scripts/python.exe ml/eval/sweep_tail_bar.py
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "backend"))

import app.phoneme_analysis_service as pas  # noqa: E402
from app.phoneme_analysis_service import PhonemeAnalysisService  # noqa: E402

EVALSET = REPO / "ml" / "data" / "quranic_audio_dataset" / "evalset"
OUT = Path(__file__).resolve().parent / "results" / "tail_bar_sweep.json"

CANDIDATES = [0.5, 0.65, 0.75, 0.85]


def install_decode_cache(service: PhonemeAnalysisService) -> dict:
    """Memoise _decode on the audio bytes, so a clip is decoded once per run
    rather than once per threshold."""
    cache: dict[str, tuple] = {}
    original = service._decode

    def cached(audio_bytes: bytes):
        key = hashlib.sha1(audio_bytes).hexdigest()
        if key not in cache:
            cache[key] = original(audio_bytes)
        return cache[key]

    service._decode = cached
    return cache


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--limit", type=int, default=None)
    parser.add_argument("--out", type=Path, default=OUT)
    args = parser.parse_args()

    with open(EVALSET / "manifest.csv", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    if args.limit:
        rows = rows[:args.limit]

    print(f"loading the model ({len(rows)} clips x {len(CANDIDATES)} thresholds)...")
    service = PhonemeAnalysisService()
    install_decode_cache(service)

    tallies = {th: {"correct": 0, "incorrect": 0, "false_alarm": 0, "caught": 0,
                    "words": 0, "flagged": 0, "unread": 0} for th in CANDIDATES}

    for i, row in enumerate(rows, 1):
        try:
            audio = (EVALSET / row["file"]).read_bytes()
        except Exception:
            continue
        surah, ayah = int(row["surah"]), int(row["ayah"])
        was_right = int(row["recited_correctly"]) == 1

        for th in CANDIDATES:
            pas.TAIL_EXTEND_RATIO = th
            try:
                verdicts = service.analyze_range(audio, surah, ayah, ayah)
            except Exception:
                continue
            t = tallies[th]
            flagged = [v for v in verdicts if v.recited and not v.correct]
            if was_right:
                t["correct"] += 1
                t["false_alarm"] += bool(flagged)
                t["words"] += len(verdicts)
                t["flagged"] += len(flagged)
                t["unread"] += sum(1 for v in verdicts if not v.recited)
            else:
                t["incorrect"] += 1
                t["caught"] += bool(flagged)

        if i % 100 == 0 or i == len(rows):
            print(f"  {i}/{len(rows)}")

    pct = lambda n, d: round(100 * n / max(d, 1), 1)  # noqa: E731
    results = []
    for th in CANDIDATES:
        t = tallies[th]
        results.append({
            "tail_ratio": th,
            "false_alarm_pct": pct(t["false_alarm"], t["correct"]),
            "caught_pct": pct(t["caught"], t["incorrect"]),
            "words_wrongly_flagged_pct": pct(t["flagged"], t["words"]),
            "words_wrongly_unread_pct": pct(t["unread"], t["words"]),
        })

    summary = {
        "what": "TAIL_EXTEND_RATIO on the labelled learner corpus",
        "note": "spill on truncated recitations must be read from "
                "ml/eval/crossmodel/measure_recited_spill.py at the same values; "
                "this half of the trade-off only covers finished recitations",
        "clips": len(rows),
        "results": results,
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")

    print()
    print("=" * 68)
    print("TAIL BAR ON LEARNER RECORDINGS (all finished recitations)")
    print("=" * 68)
    print(f"  {'ratio':>6} {'false alarm':>12} {'caught':>8} "
          f"{'words flagged':>14} {'words unread':>13}")
    for r in results:
        print(f"  {r['tail_ratio']:>6} {r['false_alarm_pct']:>11}% "
              f"{r['caught_pct']:>7}% {r['words_wrongly_flagged_pct']:>13}% "
              f"{r['words_wrongly_unread_pct']:>12}%")
    print(f"\n  written to {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
