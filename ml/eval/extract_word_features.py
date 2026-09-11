"""Per-flagged-word features, for training a filter that tells a real mistake
from recogniser noise.

Why a learned filter
--------------------
GOP alone -- one feature, one hand-picked threshold -- already removes about 22
points of false alarms on reciters it was never fitted to, at a cost of 14
points of real-mistake detection (ml/eval/results/gop_heldout_validation.json).
That is a single scalar doing all the work. The model knows more than that at
each word: how sure it was, how far ahead of the runner-up, how long the word
took, how much the decode differed, which rule was claimed. This dumps all of
it, once, so a filter can be fitted and validated without paying for the decode
again.

The label, and its asymmetry
----------------------------
The corpus labels whole clips, not words, so the two sides are not equally
clean:

  clip labelled `correct`   -> NO word in it is a mistake, so every flagged word
                               here is definitively a false alarm. Clean.
  clip labelled `in_correct` -> *somewhere* in it there is a mistake. A flagged
                               word here may be that mistake, or may be another
                               false alarm sitting beside it. Noisy.

So the negative class is trustworthy and the positive class is contaminated.
That is worth stating plainly rather than papering over: it caps how good any
model fitted on this can look, and it is why evaluation stays at clip level,
where the labels actually live.

Run from the repo root:
    backend/.venv/Scripts/python.exe ml/eval/extract_word_features.py
"""
from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path

import librosa
import numpy as np

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "backend"))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from app.phoneme_analysis_service import PhonemeAnalysisService  # noqa: E402

from measure_confidence_separation import (  # noqa: E402
    EVALSET, FRAME_SEC, SAMPLE_RATE, TAIL_PAD_SEC, Posterior, _span, ctc_gop,
    goodness_of_pronunciation, load_units, tokenise,
)

OUT = Path(__file__).resolve().parent / "results" / "word_features.jsonl"

RULES = ("madd", "ghunnah", "shaddah", "makhraj", "skipped")


def confidence_stats(lp: np.ndarray, start_sec: float, end_sec: float):
    """(mean chosen-unit probability, mean margin over the runner-up).

    The margin is what "the model was decisive here" actually means: a 0.6 that
    beat its rival by 0.5 is a different kind of evidence from a 0.6 that beat
    it by 0.02.
    """
    window = _span(lp, start_sec, end_sec)
    if window is None:
        return None, None
    probs = np.exp(window)
    top2 = np.sort(probs, axis=1)[:, -2:]
    return float(top2[:, 1].mean()), float((top2[:, 1] - top2[:, 0]).mean())


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--limit", type=int, default=None)
    parser.add_argument("--evalset", type=Path, default=EVALSET)
    parser.add_argument("--out", type=Path, default=OUT)
    args = parser.parse_args()

    with open(args.evalset / "manifest.csv", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    if args.limit:
        rows = rows[:args.limit]

    print(f"loading the model ({len(rows)} clips)...")
    service = PhonemeAnalysisService()
    posterior = Posterior()
    units = load_units()

    out_rows = []
    for i, row in enumerate(rows, 1):
        path = args.evalset / row["file"]
        try:
            verdicts = service.analyze_range(
                path.read_bytes(), int(row["surah"]), int(row["ayah"]), int(row["ayah"]))
            y, _ = librosa.load(str(path), sr=SAMPLE_RATE, mono=True)
            lp = posterior.log_probs(np.concatenate(
                [y, np.zeros(int(TAIL_PAD_SEC * SAMPLE_RATE), dtype=np.float32)]))
        except Exception:
            continue

        for v in verdicts:
            if not v.recited or v.correct:
                continue  # only flagged words; the filter never sees the rest
            ids = tokenise(v.expected_phonemes, units)
            conf, margin = confidence_stats(lp, v.start_sec, v.end_sec)
            if conf is None:
                continue
            gop = goodness_of_pronunciation(lp, ids, v.start_sec, v.end_sec)
            cg = ctc_gop(lp, ids, v.start_sec, v.end_sec)
            duration = max(v.end_sec - v.start_sec, 0.0)
            n_exp = max(len(v.expected_phonemes), 1)

            out_rows.append({
                "clip_id": row["clip_id"],
                "reciter_id": row.get("reciter_id", ""),
                # 1 = the clip was recited correctly, so this flag is a false
                # alarm. 0 = the clip contains a real mistake (this word may or
                # may not be it -- see the module docstring).
                "clip_correct": int(row["recited_correctly"]),
                "ayah": v.ayah_number,
                "word_index": v.word_index,
                "gop": gop,
                "ctc_gop": cg,
                "conf": conf,
                "margin": margin,
                "edit_distance": v.edit_distance,
                "n_expected": len(v.expected_phonemes),
                "n_predicted": len(v.predicted_phonemes),
                "len_ratio": len(v.predicted_phonemes) / n_exp,
                "distance_ratio": v.edit_distance / n_exp,
                "duration_sec": round(duration, 3),
                "frames": int(duration / FRAME_SEC),
                "error_type": v.error_type or "",
            })

        if i % 50 == 0 or i == len(rows):
            print(f"  {i}/{len(rows)}  ({len(out_rows)} flagged words so far)")

    args.out.parent.mkdir(parents=True, exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as fh:
        for r in out_rows:
            fh.write(json.dumps(r, ensure_ascii=False) + "\n")

    false_alarms = sum(1 for r in out_rows if r["clip_correct"] == 1)
    print()
    print(f"  flagged words total          : {len(out_rows)}")
    print(f"  on correctly recited clips   : {false_alarms}  (clean false alarms)")
    print(f"  on incorrectly recited clips : {len(out_rows) - false_alarms}  (noisy positives)")
    print(f"  reciters                     : {len({r['reciter_id'] for r in out_rows})}")
    print(f"\n  written to {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
