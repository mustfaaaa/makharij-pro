"""Evaluate the quality/uncertainty policy on all 773 learner clips.

The cached raw decode is used for normal-quality clips. Only the degraded
subset is decoded again through the production raw+enhanced consensus path, so
this measures the shipped policy without paying to rerun unchanged audio.
"""

from __future__ import annotations

import csv
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "backend"))

from app.audio_quality import assess_audio  # noqa: E402
from app.phoneme_analysis_service import PhonemeAnalysisService  # noqa: E402
from app.routers.sessions import _analyze_with_quality  # noqa: E402
from app.verdict_policy import CONFIRMED_ERROR, NEEDS_REVIEW, status_of  # noqa: E402
from app.tajweed_diff import classify  # noqa: E402

EVALSET = REPO / "ml" / "data" / "quranic_audio_dataset" / "evalset"
CACHE = Path(__file__).resolve().parent / "results" / "word_level.jsonl"
OUT = Path(__file__).resolve().parent / "results" / "quality_consensus.json"


def _rates(records: list[dict], field: str) -> dict:
    correct = [row for row in records if row["correct_clip"]]
    wrong = [row for row in records if not row["correct_clip"]]
    false_rate = sum(row[field] for row in correct) / max(len(correct), 1)
    caught = sum(row[field] for row in wrong) / max(len(wrong), 1)
    return {
        "correct_clips_flagged_pct": round(100 * false_rate, 1),
        "incorrect_clips_caught_pct": round(100 * caught, 1),
        "balanced_accuracy_pct": round(50 * ((1 - false_rate) + caught), 1),
    }


def main() -> int:
    raw_rows = {
        row["clip_id"]: row
        for row in (json.loads(line) for line in CACHE.read_text(encoding="utf-8").splitlines() if line.strip())
    }
    with (EVALSET / "manifest.csv").open(encoding="utf-8") as handle:
        manifest = list(csv.DictReader(handle))

    service = None
    records = []
    degraded = 0
    for index, row in enumerate(manifest, 1):
        path = EVALSET / row["file"]
        audio = path.read_bytes()
        _samples, quality = assess_audio(audio)
        if quality.needs_second_pass:
            degraded += 1
            service = service or PhonemeAnalysisService()
            results, _quality, _enhancement = _analyze_with_quality(
                service, audio, int(row["surah"]), int(row["ayah"]),
                int(row["surah"]), int(row["ayah"]),
            )
            displayed = any(r.recited and not r.correct for r in results)
            confirmed = any(status_of(r) == CONFIRMED_ERROR for r in results)
            review = any(status_of(r) == NEEDS_REVIEW for r in results)
        else:
            words = raw_rows[row["clip_id"]]["words"]
            flags = [w for w in words if w["recited"] and not w["correct"]]
            displayed = bool(flags)
            confirmed = any(
                w.get("error_type") != "makhraj"
                or len(classify(w["display"], w["expected"], w["predicted"])) >= 2
                for w in flags
            )
            review = any(
                w.get("error_type") == "makhraj"
                and len(classify(w["display"], w["expected"], w["predicted"])) < 2
                for w in flags
            )
        records.append({
            "correct_clip": row["recited_correctly"] == "1",
            "displayed": displayed,
            "confirmed": confirmed,
            "review": review,
        })
        if quality.needs_second_pass and degraded % 10 == 0:
            print(f"verified {degraded} degraded clips ({index}/{len(manifest)})")

    report = {
        "clips": len(records),
        "degraded_dual_decode_clips": degraded,
        "displayed_review_flags": _rates(records, "displayed"),
        "confirmed_errors_only": _rates(records, "confirmed"),
        "clips_with_review_status": sum(row["review"] for row in records),
        "note": "Displayed flags preserve the existing review UI. Only confirmed errors affect scores and practice plans.",
    }
    OUT.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))
    print(f"written to {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
