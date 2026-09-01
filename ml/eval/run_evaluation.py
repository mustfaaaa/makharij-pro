"""Runs the app's real analysis pipeline over the labelled learner recordings
and reports how it behaves on voices it has never been measured against.

Every number the detector has been judged by so far came from professional
Qari recordings. That answers "does it agree with a perfect reciter", not "does
it accuse a learner of mistakes they did not make" -- and a false accusation is
the failure that costs the user's trust in every other verdict on the screen.

Two things are measurable from clip-level labels, and only two:
  - on clips a human marked `correct`, any flag at all is a false positive;
  - on clips marked `in_correct`, whether the detector noticed anything.
It cannot be verified that the *right* word was flagged -- the labels are not
per word. That limit is stated in the output rather than glossed over.

Per-word expected/predicted phonemes are written alongside the metrics so
threshold calibration can be re-run without paying for recognition again
(see calibrate_thresholds.py).

    python ml/eval/run_evaluation.py
"""
import argparse
import csv
import json
import sys
import time
from collections import Counter, defaultdict
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT / "backend"))

from app.phoneme_analysis_service import PhonemeAnalysisService  # noqa: E402

EVALSET = ROOT / "ml" / "data" / "quranic_audio_dataset" / "evalset"
RESULTS = ROOT / "ml" / "eval" / "results"


def analyse_all(service, rows, evalset_dir, limit=None):
    """Run the pipeline over every clip, keeping enough detail to re-score it."""
    out = []
    started = time.time()
    for i, row in enumerate(rows if limit is None else rows[:limit], 1):
        audio = (evalset_dir / row["file"]).read_bytes()
        surah, ayah = int(row["surah"]), int(row["ayah"])
        try:
            results = service.analyze_range(audio, surah, ayah, ayah)
        except Exception as exc:  # a clip the model simply can't process
            out.append({**row, "error": str(exc), "words": []})
            continue

        out.append({
            "clip_id": row["clip_id"],
            "label": row["label"],
            "recited_correctly": int(row["recited_correctly"]),
            "golden": int(row["golden"]),
            "gender": row["gender"],
            "age": row["age"],
            "country": row["country"],
            "reciter_id": row["reciter_id"],
            "surah": surah,
            "ayah": ayah,
            "words": [
                {
                    "display": r.display_word,
                    "expected": r.expected_phonemes,
                    "predicted": r.predicted_phonemes,
                    "recited": r.recited,
                    "correct": r.correct,
                    "error_type": r.error_type,
                }
                for r in results
            ],
        })

        if i % 50 == 0:
            rate = i / (time.time() - started)
            print(f"  {i}/{len(rows)}  ({rate:.1f} clips/s)", flush=True)
    return out


def clip_flagged(record) -> bool:
    """Did the app accuse this recitation of anything?"""
    return any(w["recited"] and not w["correct"] for w in record["words"])


def report(records):
    correct = [r for r in records if r["recited_correctly"] == 1]
    incorrect = [r for r in records if r["recited_correctly"] == 0]

    fp_clips = sum(clip_flagged(r) for r in correct)
    detected = sum(clip_flagged(r) for r in incorrect)

    fp_words = sum(
        sum(1 for w in r["words"] if w["recited"] and not w["correct"]) for r in correct
    )
    recited_words = sum(sum(1 for w in r["words"] if w["recited"]) for r in correct)

    print("\n" + "=" * 66)
    print("REAL LEARNER RECORDINGS -- what the app does on voices it was never tuned on")
    print("=" * 66)
    print(f"\nclips analysed: {len(records)}  "
          f"({len(correct)} recited correctly, {len(incorrect)} with a real mistake)")

    print("\n--- false positives (clips a human marked CORRECT) ---")
    print(f"  clips wrongly flagged : {fp_clips}/{len(correct)} "
          f"({100 * fp_clips / max(len(correct), 1):.1f}%)")
    print(f"  words wrongly flagged : {fp_words}/{recited_words} "
          f"({100 * fp_words / max(recited_words, 1):.1f}%)")

    print("\n--- detection (clips a human marked INCORRECT) ---")
    print(f"  clips where a mistake was found : {detected}/{len(incorrect)} "
          f"({100 * detected / max(len(incorrect), 1):.1f}%)")
    print("  (clip-level labels cannot confirm the *right* word was flagged)")

    tpr = detected / max(len(incorrect), 1)
    tnr = 1 - fp_clips / max(len(correct), 1)
    print(f"\n  balanced accuracy : {100 * (tpr + tnr) / 2:.1f}%")

    for field in ("gender", "age", "country"):
        groups = defaultdict(lambda: [0, 0, 0, 0])  # correct, fp, incorrect, detected
        for r in records:
            g = groups[r[field]]
            if r["recited_correctly"]:
                g[0] += 1
                g[1] += clip_flagged(r)
            else:
                g[2] += 1
                g[3] += clip_flagged(r)
        rows = [(k, v) for k, v in groups.items() if v[0] + v[2] >= 15]
        if not rows:
            continue
        print(f"\n--- by {field} (groups with 15+ clips) ---")
        print(f"  {'':14} {'false-positive rate':>20}   {'detection rate':>15}")
        for key, (nc, fp, ni, det) in sorted(rows, key=lambda kv: -(kv[1][0] + kv[1][2])):
            fp_txt = f"{100 * fp / nc:.0f}%  (n={nc})" if nc else "     n/a"
            det_txt = f"{100 * det / ni:.0f}%  (n={ni})" if ni else "     n/a"
            print(f"  {str(key):14} {fp_txt:>20}   {det_txt:>15}")

    types = Counter(
        w["error_type"] for r in correct for w in r["words"]
        if w["recited"] and not w["correct"] and w["error_type"]
    )
    if types:
        print("\n--- what the false positives are blamed on ---")
        for t, n in types.most_common():
            print(f"  {t:12} {n}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--evalset", type=Path, default=EVALSET)
    parser.add_argument("--out", type=Path, default=RESULTS)
    parser.add_argument("--limit", type=int, default=None, help="analyse only the first N clips")
    args = parser.parse_args()

    manifest = args.evalset / "manifest.csv"
    if not manifest.exists():
        print(f"No manifest at {manifest} -- run ml/eval/build_manifest.py first")
        return 1

    with open(manifest, encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    print(f"loading the phoneme model...")
    service = PhonemeAnalysisService()
    print(f"analysing {len(rows) if args.limit is None else args.limit} clips")

    records = analyse_all(service, rows, args.evalset, args.limit)

    args.out.mkdir(parents=True, exist_ok=True)
    detail = args.out / "word_level.jsonl"
    with open(detail, "w", encoding="utf-8") as f:
        for r in records:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")

    report(records)
    print(f"\nper-word detail written to {detail}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
