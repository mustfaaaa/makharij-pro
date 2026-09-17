"""Stage B: judge the candidate recogniser against the one in production.

The question
------------
The current recogniser wrongly flags 1.3% of words on professional Qari audio
and 41.9% of correctly-recited learner clips. The pipeline around it is the same
in both cases, so that gap is the recogniser mishearing learners -- and it is
the single biggest source of the app telling people they made a mistake when
they did not.

A candidate is only worth switching to if it closes that gap. This measures
whether it does, on the same 773 labelled clips, with the same rule for what
counts as a wrongly-flagged word.

Why phoneme error rate, and why only on correct clips
-----------------------------------------------------
The two models speak different alphabets -- 251 symbols for the current one,
43 for the candidate -- so their outputs cannot be compared directly, and
neither can be dropped into the other's diff. What *is* comparable is how badly
each one mishears a recitation that is known to be correct.

On a clip the reciter got right, every phoneme the recogniser gets wrong is a
chance for the layer above to invent a mistake. So per-clip phoneme error rate
against the canonical text, restricted to the 353 clips labelled `correct`, is
the cleanest like-for-like signal available: lower PER there means fewer false
accusations downstream, whatever alphabet it is measured in.

Incorrect clips are reported too, but they are not the headline: there the
reciter genuinely deviated, so a high PER is the recogniser working.

Both models must face the same reference
----------------------------------------
The app's word mapper prepends the basmala to every ayah 1, because that is
what a learner opening a surah actually recites. The candidate's phonetiser is
given the ayah alone. So on ayah-1 clips the two models are answering different
questions, and their error rates are not comparable -- the first run of this
script compared them anyway, which flattered whichever model happened to match
the reciter's habit.

Those clips are now excluded from the headline and counted separately. The two
alphabets turned out to be identical (both come from `quran_transcript`), so on
every other clip the reference strings are character-for-character the same and
the comparison is exact.

    backend/.venv/Scripts/python.exe ml/eval/compare_recognisers.py
"""
from __future__ import annotations

import argparse
import csv
import json
import statistics
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "backend"))

EVALSET = REPO / "ml" / "data" / "quranic_audio_dataset" / "evalset"
CANDIDATE = Path(__file__).resolve().parent / "results" / "muaalem_predictions.jsonl"
OUT = Path(__file__).resolve().parent / "results" / "recogniser_comparison.json"
CURRENT_CACHE = Path(__file__).resolve().parent / "results" / "current_predictions.jsonl"


def edit_distance(a: str, b: str) -> int:
    """Levenshtein, iterative so a long ayah cannot blow the stack."""
    if a == b:
        return 0
    if not a:
        return len(b)
    if not b:
        return len(a)
    previous = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        current = [i]
        for j, cb in enumerate(b, 1):
            current.append(min(
                previous[j] + 1,          # deletion
                current[j - 1] + 1,       # insertion
                previous[j - 1] + (ca != cb),
            ))
        previous = current
    return previous[-1]


def per(predicted: str, reference: str) -> float | None:
    if not reference:
        return None
    return edit_distance(predicted, reference) / len(reference)


def current_model_decode(rows: list[dict], limit: int | None) -> dict[str, dict]:
    """Decode every clip with the production recogniser, and cache the result.

    Cached because the decode is the slow half of this script and the scoring
    rules changed twice while the predictions did not -- re-deciding how to
    score should not cost another full pass over 773 clips.
    """
    if CURRENT_CACHE.exists():
        print(f"reusing cached current-model predictions ({CURRENT_CACHE.name})")
        return {
            r["clip_id"]: r
            for r in (json.loads(l) for l in
                      CURRENT_CACHE.read_text(encoding="utf-8").splitlines() if l.strip())
        }

    from app.phoneme_analysis_service import PhonemeAnalysisService

    print("loading the current recogniser...")
    service = PhonemeAnalysisService()
    out: dict[str, dict] = {}

    CURRENT_CACHE.parent.mkdir(parents=True, exist_ok=True)
    with open(CURRENT_CACHE, "w", encoding="utf-8") as fh:
        for i, row in enumerate(rows if limit is None else rows[:limit], 1):
            surah, ayah = int(row["surah"]), int(row["ayah"])
            expected = service.expected_words(surah, ayah)
            if not expected:
                continue
            try:
                tokens, _ = service._decode((EVALSET / row["file"]).read_bytes())
            except Exception:
                continue
            rec = {
                "clip_id": row["clip_id"],
                "surah": surah,
                "ayah": ayah,
                "reference_phonemes": "".join(expected),
                "predicted_phonemes": "".join(tokens),
            }
            out[row["clip_id"]] = rec
            fh.write(json.dumps(rec, ensure_ascii=False) + "\n")
            if i % 100 == 0:
                print(f"  {i}...")
    return out


def summarise(name: str, pers: dict[str, float], labels: dict[str, int]) -> dict:
    correct = [v for cid, v in pers.items() if labels.get(cid) == 1]
    incorrect = [v for cid, v in pers.items() if labels.get(cid) == 0]
    med = lambda v: round(statistics.median(v), 4) if v else None  # noqa: E731
    mean = lambda v: round(statistics.mean(v), 4) if v else None   # noqa: E731
    return {
        "model": name,
        "clips_scored": len(pers),
        "on_correct_clips": {
            "clips": len(correct), "median_per": med(correct), "mean_per": mean(correct),
            # The share that come back essentially clean is what decides whether
            # the layer above has anything to invent a mistake from.
            "pct_under_10pct_per": round(
                100 * sum(1 for v in correct if v < 0.10) / len(correct), 1) if correct else None,
        },
        "on_incorrect_clips": {
            "clips": len(incorrect), "median_per": med(incorrect), "mean_per": mean(incorrect),
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--limit", type=int, default=None)
    parser.add_argument("--candidate", type=Path, default=CANDIDATE)
    parser.add_argument("--out", type=Path, default=OUT)
    args = parser.parse_args()

    with open(EVALSET / "manifest.csv", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    labels = {r["clip_id"]: int(r["recited_correctly"]) for r in rows}

    if not args.candidate.exists():
        print(f"No candidate predictions at {args.candidate} -- run "
              f"ml/.venv-muaalem/Scripts/python.exe ml/eval/transcribe_with_muaalem.py first")
        return 1

    candidate = {
        r["clip_id"]: r
        for r in (json.loads(l) for l in
                  args.candidate.read_text(encoding="utf-8").splitlines() if l.strip())
    }
    current = current_model_decode(rows, args.limit)

    # Same clips only: a model must not look better for having skipped the hard
    # ones. Anything either model failed to decode is dropped from both.
    shared = set(candidate) & set(current)

    # And the same question only. Where the two references differ the clip is
    # not a comparison at all -- see the module docstring.
    comparable = {c for c in shared
                  if candidate[c]["reference_phonemes"] == current[c]["reference_phonemes"]}
    mismatched = sorted(shared - comparable)

    candidate_pers = {c: per(candidate[c]["predicted_phonemes"],
                             candidate[c]["reference_phonemes"]) for c in comparable}
    current_pers = {c: per(current[c]["predicted_phonemes"],
                           current[c]["reference_phonemes"]) for c in comparable}
    candidate_pers = {k: v for k, v in candidate_pers.items() if v is not None}
    current_pers = {k: v for k, v in current_pers.items() if v is not None}

    summary = {
        "what": "phoneme error rate against the canonical text, same clips, "
                "identical reference string, same rule",
        "clips_compared": len(comparable),
        "clips_excluded_reference_mismatch": len(mismatched),
        "why_excluded": "the app prepends the basmala to ayah 1; the candidate's "
                        "phonetiser does not, so those clips score two different "
                        "questions and cannot be compared",
        "current": summarise("quran-lab zipformer (in production)", current_pers, labels),
        "candidate": summarise("obadx/muaalem-model-v3_2", candidate_pers, labels),
    }

    cur = summary["current"]["on_correct_clips"]
    cand = summary["candidate"]["on_correct_clips"]
    if cur["median_per"] is not None and cand["median_per"] is not None:
        summary["verdict"] = (
            "candidate mishears correct learner recitation LESS"
            if cand["median_per"] < cur["median_per"] else
            "candidate is NOT better on correct learner recitation"
        )

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")

    print()
    print("=" * 68)
    print("RECOGNISER COMPARISON -- phoneme error rate on the same clips")
    print("=" * 68)
    print(f"  clips compared: {len(comparable)}   (excluded, reference mismatch: {len(mismatched)})")
    print()
    print(f"  {'':34} {'median PER':>11} {'clean (<10%)':>13}")
    for key, label in (("current", "current (Quran-Lab)"),
                       ("candidate", "candidate (muaalem)")):
        c = summary[key]["on_correct_clips"]
        print(f"  {label + ', correct clips':34} {str(c['median_per']):>11} "
              f"{str(c['pct_under_10pct_per']) + '%':>13}")
    print()
    for key, label in (("current", "current"), ("candidate", "candidate")):
        c = summary[key]["on_incorrect_clips"]
        print(f"  {label + ', incorrect clips':34} {str(c['median_per']):>11}")
    print()
    print(f"  VERDICT: {summary.get('verdict', 'not enough data')}")
    print(f"\n  written to {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
