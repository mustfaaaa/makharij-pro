"""Set the Tajweed Drill's guard threshold from real audio, not by guessing.

The guard (backend/app/tajweed_drill.py) lets a recording reach model v1 only
if the production recogniser hears the drill phrase -- the close of 5:109 --
in it. It has two jobs that pull against each other:

  accept  every genuine attempt at the phrase, *including badly recited ones*.
          A guard that only lets clean recitations through would hide exactly
          the mistakes the drill exists to catch.
  reject  everything else: other ayat, the near-twin 2:32 ("لا علم لنا إلا ما
          علمتنا إنك أنت العليم الحكيم"), and a full recitation of 5:109, whose
          extra opening words would distort the duration input v1 relies on.

Positives are QDAT clips -- the recordings v1 learned from -- split by their
labels so the worst-recited ones are measured separately. Negatives are the
full-Quran reference reciter on 2:32, on all of 5:109 and on a spread of other
ayat, plus real learner recordings of other ayat from the RetaSy corpus.

    backend/.venv/Scripts/python.exe ml/eval/calibrate_drill_guard.py
"""
from __future__ import annotations

import argparse
import csv
import json
import random
import statistics
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "backend"))

SUDAIS = REPO / "backend" / "app" / "static" / "recitations" / "abdurrahmaan_as_sudais"
EVALSET = REPO / "ml" / "data" / "quranic_audio_dataset" / "evalset"
OUT = REPO / "ml" / "eval" / "results" / "drill_guard_calibration.json"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--qdat", type=int, default=300)
    parser.add_argument("--other-ayat", type=int, default=60)
    parser.add_argument("--learners", type=int, default=100)
    parser.add_argument("--seed", type=int, default=7)
    args = parser.parse_args()

    from datasets import Audio, load_dataset
    from app import tajweed_drill as drill
    from app.phoneme_analysis_service import PhonemeAnalysisService

    rng = random.Random(args.seed)
    svc = PhonemeAnalysisService()

    def per(audio_bytes: bytes) -> float:
        return drill.phrase_distance(svc, audio_bytes)[0]

    # --- positives: QDAT -----------------------------------------------------
    ds = load_dataset("obadx/qdat")["train"].cast_column("audio", Audio(decode=False))
    rules = ("separate_tide", "the_tight_noon", "concealment")

    def label_group(row) -> str:
        vals = [row.get(r) for r in rules]
        if any(v is None or v == "" for v in vals):
            return "unlabelled"
        wrong = sum(1 for v in vals if int(float(v)) == 0)
        return "all_correct" if wrong == 0 else ("all_wrong" if wrong == 3 else "some_wrong")

    positives: dict[str, list[float]] = {}
    for i in rng.sample(range(len(ds)), min(args.qdat, len(ds))):
        row = ds[i]
        positives.setdefault(label_group(row), []).append(per(row["audio"]["bytes"]))
        print(".", end="", flush=True)
    print()

    # --- negatives -----------------------------------------------------------
    negatives: dict[str, list[float]] = {}

    def sudais(surah: int, ayah: int) -> bytes | None:
        p = SUDAIS / f"{surah:03d}{ayah:03d}.mp3"
        return p.read_bytes() if p.exists() else None

    for name, (s, a) in {"twin 2:32": (2, 32), "whole of 5:109": (5, 109)}.items():
        b = sudais(s, a)
        if b:
            negatives[name] = [per(b)]

    candidates = sorted(SUDAIS.glob("*.mp3"))
    others = [p for p in candidates if p.stem not in ("002032", "005109")]
    negatives["other ayat (reference reciter)"] = [
        per(p.read_bytes()) for p in rng.sample(others, min(args.other_ayat, len(others)))]

    with open(EVALSET / "manifest.csv", encoding="utf-8") as f:
        learner_rows = [r for r in csv.DictReader(f)
                        if (int(r["surah"]), int(r["ayah"])) != (5, 109)]
    negatives["learner recordings, other ayat"] = [
        per((EVALSET / r["file"]).read_bytes())
        for r in rng.sample(learner_rows, min(args.learners, len(learner_rows)))]

    # --- sweep ---------------------------------------------------------------
    all_pos = [v for vs in positives.values() for v in vs]
    all_neg = [v for vs in negatives.values() for v in vs]
    grid = [round(0.05 * i, 2) for i in range(2, 21)]
    sweep = []
    for t in grid:
        sweep.append({
            "threshold": t,
            "qdat_accepted_pct": round(100 * sum(v <= t for v in all_pos) / len(all_pos), 1),
            "qdat_all_wrong_accepted_pct": round(
                100 * sum(v <= t for v in positives.get("all_wrong", [])) /
                max(len(positives.get("all_wrong", [])), 1), 1),
            "negatives_rejected_pct": round(100 * sum(v > t for v in all_neg) / len(all_neg), 1),
        })

    def describe(vs: list[float]) -> dict:
        return {"n": len(vs), "min": round(min(vs), 3), "median": round(statistics.median(vs), 3),
                "max": round(max(vs), 3)}

    summary = {
        "what": "phrase PER distribution of genuine attempts vs everything else",
        "positives": {k: describe(v) for k, v in positives.items()},
        "negatives": {k: describe(v) for k, v in negatives.items()},
        "closest_negative": round(min(all_neg), 3),
        "furthest_positive": round(max(all_pos), 3),
        "sweep": sweep,
    }
    OUT.write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")

    print("\nGENUINE ATTEMPTS (QDAT) -- phrase PER")
    for k, v in summary["positives"].items():
        print(f"  {k:34} n={v['n']:3}  min {v['min']:.3f}  median {v['median']:.3f}  max {v['max']:.3f}")
    print("\nEVERYTHING ELSE -- phrase PER")
    for k, v in summary["negatives"].items():
        print(f"  {k:34} n={v['n']:3}  min {v['min']:.3f}  median {v['median']:.3f}  max {v['max']:.3f}")
    print(f"\n  furthest genuine attempt : {summary['furthest_positive']}")
    print(f"  closest non-attempt      : {summary['closest_negative']}")
    print(f"\n  {'threshold':>9} {'QDAT kept':>10} {'all-wrong kept':>15} {'others rejected':>16}")
    for s in sweep:
        print(f"  {s['threshold']:>9} {s['qdat_accepted_pct']:>9}% "
              f"{s['qdat_all_wrong_accepted_pct']:>14}% {s['negatives_rejected_pct']:>15}%")
    print(f"\n  -> {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
