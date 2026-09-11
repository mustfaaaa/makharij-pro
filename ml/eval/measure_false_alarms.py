"""False alarms on the labelled learner corpus, and the words we wrongly grey out.

Two different wrongs, counted separately
----------------------------------------
A clip the reciter got right can go wrong for the app in two ways, and they do
not cost the same:

  flagged   a word is marked as a mistake. This accuses someone of an error they
            did not make, and it is what erodes trust in every other verdict.
  unread    a word is shown as never recited. Milder -- nobody is accused -- but
            still visibly wrong, since they did say it.

The headline 42.8%/53.5% figures only ever counted the first. This counts both,
because a fix that converts flags into greyed-out words has improved things
without having finished.

    backend/.venv/Scripts/python.exe ml/eval/measure_false_alarms.py
"""
from __future__ import annotations

import argparse
import csv
import json
import sys
from collections import Counter
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "backend"))

from app.phoneme_analysis_service import PhonemeAnalysisService  # noqa: E402

EVALSET = REPO / "ml" / "data" / "quranic_audio_dataset" / "evalset"
OUT = Path(__file__).resolve().parent / "results" / "false_alarms.json"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--limit", type=int, default=None)
    parser.add_argument("--label", default="current")
    parser.add_argument("--out", type=Path, default=OUT)
    args = parser.parse_args()

    with open(EVALSET / "manifest.csv", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    if args.limit:
        rows = rows[:args.limit]

    print(f"loading the model ({len(rows)} clips)...")
    service = PhonemeAnalysisService()

    correct_clips = incorrect_clips = 0
    false_alarm_clips = caught_clips = 0
    clips_with_unread = 0
    words_total = words_flagged = words_unread = 0
    per_ayah: dict[str, dict] = {}

    for i, row in enumerate(rows, 1):
        try:
            verdicts = service.analyze_range(
                (EVALSET / row["file"]).read_bytes(),
                int(row["surah"]), int(row["ayah"]), int(row["ayah"]))
        except Exception:
            continue

        was_right = int(row["recited_correctly"]) == 1
        flagged = [v for v in verdicts if v.recited and not v.correct]
        unread = [v for v in verdicts if not v.recited]

        if was_right:
            correct_clips += 1
            if flagged:
                false_alarm_clips += 1
            if unread:
                clips_with_unread += 1
            words_total += len(verdicts)
            words_flagged += len(flagged)
            words_unread += len(unread)
            key = f"S{row['surah']}:{row['ayah']}"
            bucket = per_ayah.setdefault(key, {"clips": 0, "flagged": 0, "unread": 0})
            bucket["clips"] += 1
            bucket["flagged"] += bool(flagged)
            bucket["unread"] += bool(unread)
        else:
            incorrect_clips += 1
            if flagged:
                caught_clips += 1

        if i % 100 == 0 or i == len(rows):
            print(f"  {i}/{len(rows)}")

    pct = lambda n, d: round(100 * n / max(d, 1), 1)  # noqa: E731
    summary = {
        "label": args.label,
        "correct_clips": correct_clips,
        "incorrect_clips": incorrect_clips,
        "false_alarm_pct": pct(false_alarm_clips, correct_clips),
        "caught_pct": pct(caught_clips, incorrect_clips),
        "clips_with_a_wrongly_unread_word_pct": pct(clips_with_unread, correct_clips),
        "words_on_correct_clips": words_total,
        "words_wrongly_flagged_pct": pct(words_flagged, words_total),
        "words_wrongly_unread_pct": pct(words_unread, words_total),
        "per_ayah": {
            k: {"clips": v["clips"],
                "flagged_pct": pct(v["flagged"], v["clips"]),
                "unread_pct": pct(v["unread"], v["clips"])}
            for k, v in sorted(per_ayah.items(), key=lambda kv: -kv[1]["clips"])
        },
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")

    print()
    print("=" * 60)
    print(f"FALSE ALARMS ON LEARNER RECORDINGS  [{args.label}]")
    print("=" * 60)
    print(f"  correctly recited clips        : {correct_clips}")
    print(f"  ...flagged as a mistake        : {summary['false_alarm_pct']}%")
    print(f"  ...with a word wrongly unread  : "
          f"{summary['clips_with_a_wrongly_unread_word_pct']}%")
    print()
    print(f"  real mistakes caught           : {summary['caught_pct']}%")
    print()
    print(f"  words on correct clips         : {words_total}")
    print(f"  ...wrongly flagged             : {summary['words_wrongly_flagged_pct']}%")
    print(f"  ...wrongly unread              : {summary['words_wrongly_unread_pct']}%")
    print(f"\n  written to {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
