"""On the drill phrase, which model should judge each rule: v1, or the app's own?

Why this was needed
-------------------
The Tajweed Drill was going to be model v1's job -- it was trained on exactly
this phrase (the close of 5:109), so it is the one place v1 is valid. Then a
QDAT clip whose three mistakes are plainly audible in the production
recogniser's phonemes -- madd cut short (لَنَاا for لَنَاااا), ghunnah clipped
(ءِننَكَ for ءِننننَكَ), no ikhfa (ءَنتَ for ءَںںںتَ) -- came back from v1 as correct
on all three rules. A drill that praises a reciter for the mistake it exists to
catch is worse than no drill, so the two were measured against each other
before building on either.

The contest
-----------
QDAT's test split: the 206 clips from speakers v1 never trained on (speaker-
grouped split, row indices in v1's own manifest). For each clip and rule:

  v1          its calibrated verdict for that rule's head
  app         what the app itself would say about the word the rule lives on:
              the production recogniser's phonemes, aligned to the phrase, and
              tajweed_diff's verdict for that word -- the same code the results
              screen uses

scored against QDAT's human label. Balanced accuracy is the headline because
the classes are uneven; recall on *incorrect* is reported separately because
missing a mistake is the failure that matters most in a drill.

One caveat stated up front: Quran-Lab's recogniser may have seen QDAT audio in
training (its training data is not published), which would flatter the app
column. v1 was trained on QDAT's train split by us, so its test numbers are
clean. Treat an app win as a strong hint, not proof.

    backend/.venv/Scripts/python.exe ml/eval/compare_drill_models.py
"""
from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "backend"))

MANIFEST = REPO / "ml" / "models" / "makharijpro_tajweed_model_v1" / "qdat_manifest.csv"
OUT = REPO / "ml" / "eval" / "results" / "drill_model_comparison.json"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--split", default="test")
    args = parser.parse_args()

    from datasets import Audio, load_dataset
    from app import tajweed_diff
    from app import tajweed_drill as drill
    from app.model_service import TajweedModelService
    from app.phoneme_analysis_service import PhonemeAnalysisService

    v1 = TajweedModelService()
    svc = PhonemeAnalysisService()
    ds = load_dataset("obadx/qdat")["train"].cast_column("audio", Audio(decode=False))

    rows = [r for r in csv.DictReader(open(MANIFEST, encoding="utf-8"))
            if r["split"] == args.split]

    words = svc._mapper.words(drill.SURAH, drill.AYAH)
    phrase = [(drill.AYAH, i, disp, ph)
              for i, (disp, ph) in enumerate(words)
              if drill.FIRST_WORD <= i <= drill.LAST_WORD and ph]
    position = {w[1]: k for k, w in enumerate(phrase)}

    def app_verdicts(audio_bytes: bytes) -> dict[int, bool]:
        """word_index -> app says correct, using the results screen's own code."""
        tokens, _ = svc._decode(audio_bytes)
        pred_chars = list("".join(tokens))
        word_pred, _matched, _errors = svc._attribute(pred_chars, phrase)
        out = {}
        for rule in drill.RULES:
            k = position[rule.word_index]
            _a, _i, display, expected = phrase[k]
            predicted = "".join(pred_chars[j] for j in word_pred[k])
            verdict = tajweed_diff.summarize(
                display, tajweed_diff.classify(display, expected, predicted))
            out[rule.word_index] = verdict is None
        return out

    scores = {r.task: {"v1": [], "app": []} for r in drill.RULES}
    skipped = 0
    for n, row in enumerate(rows, 1):
        # A label QDAT's own annotators disagreed on is not ground truth.
        audio = ds[int(row["row_index"])]["audio"]["bytes"]
        v1_out = v1.predict_from_audio_bytes(audio)
        app_out = app_verdicts(audio)
        for rule in drill.RULES:
            label = row[rule.task]
            if label == "" or row.get(f"{rule.task}_had_conflict") == "True":
                skipped += 1
                continue
            truth = int(float(label)) == 1
            scores[rule.task]["v1"].append((truth, v1_out[rule.task]["correct"]))
            scores[rule.task]["app"].append((truth, app_out[rule.word_index]))
        if n % 25 == 0:
            print(f"  {n}/{len(rows)}")

    def metrics(pairs):
        tp = sum(1 for t, p in pairs if t and p)
        tn = sum(1 for t, p in pairs if not t and not p)
        pos = sum(1 for t, _ in pairs if t)
        neg = len(pairs) - pos
        rec_ok = tp / pos if pos else None
        rec_bad = tn / neg if neg else None
        return {
            "n": len(pairs),
            "accuracy": round((tp + tn) / len(pairs), 3),
            "balanced_accuracy": round((rec_ok + rec_bad) / 2, 3) if pos and neg else None,
            "mistakes_caught": round(rec_bad, 3) if neg else None,
            "correct_confirmed": round(rec_ok, 3) if pos else None,
            "n_incorrect": neg,
        }

    result = {"split": args.split, "clips": len(rows), "labels_skipped": skipped, "rules": {}}
    print(f"\nQDAT {args.split} split, {len(rows)} clips (speakers v1 never trained on)\n")
    print(f"  {'rule':28} {'model':5} {'balanced':>9} {'mistakes caught':>16} {'correct confirmed':>18}")
    for rule in drill.RULES:
        result["rules"][rule.task] = {"name": rule.name}
        for who in ("v1", "app"):
            m = metrics(scores[rule.task][who])
            result["rules"][rule.task][who] = m
            print(f"  {rule.name:28} {who:5} {m['balanced_accuracy']:>9} "
                  f"{m['mistakes_caught']:>16} {m['correct_confirmed']:>18}")
        a, b = result["rules"][rule.task]["v1"], result["rules"][rule.task]["app"]
        result["rules"][rule.task]["better"] = (
            "v1" if a["balanced_accuracy"] > b["balanced_accuracy"] else "app")
        print()

    OUT.write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"  -> {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
