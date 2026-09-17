"""Should a word be flagged when the only evidence is letters that went missing?

The idea under test
-------------------
attribution_breakdown.py found that 47.6% of everything the app reports is the
recogniser not hearing something -- 500 whole words it missed, and 479 single
letters it emitted nothing for -- rather than the reciter saying something
wrong. The 479 are the interesting half: the word *was* heard, but one expected
letter has no aligned prediction, and that alone is enough to flag it today.

Those are weaker evidence than a substitution. When the model reports a
different letter it heard something and judged it; when it reports nothing it
may simply have missed a short, unstressed consonant. So: require more than one
missing letter before flagging a word on missing letters alone, while leaving
a substitution enough to flag on its own.

`MAKHRAJ_MIN_FINDINGS = 1` means today's threshold does nothing at all --
`len(findings) < 1` is never true -- so this is the first bar of its kind
rather than a tightening of an existing one.

What it must not do
-------------------
Raise the bar far enough and false alarms fall to zero because nothing is ever
flagged. So both sides are measured at every setting: words wrongly flagged on
clips a human marked correct, and clips caught on those marked incorrect. A
setting only counts if the first falls while the second holds.

Result: it does not. REJECTED.
------------------------------
      bar   wrongly flagged   incorrect clips caught
        1            19.27%                   73.81%   <- today
        2            15.44%                   64.52%
        3             14.90%                   63.57%
        4+           14.74%                   63.10%

Moving from 1 to 2 buys 3.8 points of precision for 9.3 points of recall --
2.4 points of real mistakes missed for every point of false alarm removed, and
everything above 2 is worse still. For an app whose purpose is catching
mistakes, that is the wrong direction, so nothing in the classifier was
changed.

The reasoning was sound and the measurement refused it: a letter the recogniser
emitted nothing for is weaker evidence than a substitution, but it is not
*noise* -- it carries most of what the detector finds, and discounting it
throws away real errors along with false ones. Kept as a runnable record so the
idea is not re-tried from scratch.

No audio and no model: word_level.jsonl already holds the expected and
predicted phonemes per word, so this re-scores decodes that already happened.

    backend/.venv/Scripts/python.exe ml/eval/sweep_absent_letter_bar.py
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "backend"))

WORD_LEVEL = REPO / "ml" / "eval" / "results" / "word_level.jsonl"
OUT = REPO / "ml" / "eval" / "results" / "absent_letter_bar.json"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--words", type=Path, default=WORD_LEVEL)
    parser.add_argument("--out", type=Path, default=OUT)
    args = parser.parse_args()

    from app import tajweed_diff
    from app.tajweed_diff import MAKHRAJ, align, runs

    MARK_CHARS = tajweed_diff.MARK_CHARS
    ELONGATION_CHARS = tajweed_diff.ELONGATION_CHARS

    def evidence(expected: str, predicted: str) -> tuple[int, int, int]:
        """(findings that are absent-letter makhraj, other makhraj, named-rule).

        Mirrors classify()'s walk. Split this way because the question is
        whether the absent-letter kind should carry less weight than the rest.
        """
        if not expected or not predicted.strip():
            return (0, 0, 0)

        exp_runs, pred_runs = runs(expected), runs(predicted)
        _dist, pairs = align(pred_runs, exp_runs)
        absent = other = named = 0

        for pi, ei in pairs:
            p_ch, p_n = pred_runs[pi] if pi is not None else (None, 0)
            e_ch, e_n = exp_runs[ei] if ei is not None else (None, 0)

            if ei is None:
                if (p_ch not in MARK_CHARS and p_ch not in ELONGATION_CHARS
                        and p_n >= 2):
                    other += 1
                continue

            kind = tajweed_diff._kind(e_ch, e_n)

            if p_ch is None:
                if kind in (tajweed_diff.MADD, tajweed_diff.GHUNNAH,
                            tajweed_diff.SHADDAH, "ikhfa"):
                    named += 1
                elif e_ch not in MARK_CHARS:
                    absent += 1
                continue

            if p_ch != e_ch:
                if e_ch in MARK_CHARS or p_ch in MARK_CHARS:
                    continue
                other += 1
                continue

            if p_n == e_n:
                continue
            if kind == tajweed_diff.MADD:
                dropped = (p_n < e_n and e_n >= 4
                           and p_n <= tajweed_diff.MADD_DROPPED_MAX)
                if dropped or abs(p_n - e_n) > tajweed_diff.MADD_COUNT_TOLERANCE:
                    named += 1
            elif kind == tajweed_diff.GHUNNAH:
                if (p_n <= tajweed_diff.GHUNNAH_DROPPED_MAX
                        or abs(p_n - e_n) > tajweed_diff.GHUNNAH_COUNT_TOLERANCE):
                    named += 1
            elif kind == tajweed_diff.SHADDAH and p_n < e_n:
                named += 1
        return (absent, other, named)

    def flagged(absent: int, other: int, named: int, bar: int) -> bool:
        """Today's behaviour at bar == 1."""
        if named or other:
            return True
        return absent >= bar

    rows = [json.loads(l) for l in
            args.words.read_text(encoding="utf-8").splitlines() if l.strip()]

    # Pre-compute the evidence once; only the bar changes per setting.
    correct_words: list[tuple[int, int, int]] = []
    incorrect_clips: list[list[tuple[int, int, int]]] = []
    for row in rows:
        per_word = []
        for word in row.get("words", []):
            if not word.get("expected") or not word.get("recited", True):
                continue
            if not (word.get("predicted") or "").strip():
                continue  # "not heard at all" is a separate verdict, not this bar
            per_word.append(evidence(word["expected"], word["predicted"]))
        if row.get("recited_correctly") == 1:
            correct_words.extend(per_word)
        else:
            incorrect_clips.append(per_word)

    settings = []
    for bar in range(1, 7):
        wrongly = sum(1 for e in correct_words if flagged(*e, bar))
        caught = sum(1 for clip in incorrect_clips
                     if any(flagged(*e, bar) for e in clip))
        settings.append({
            "bar": bar,
            "words_wrongly_flagged": wrongly,
            "pct_words_wrongly_flagged": round(
                100 * wrongly / len(correct_words), 2) if correct_words else None,
            "incorrect_clips_caught": caught,
            "pct_incorrect_clips_caught": round(
                100 * caught / len(incorrect_clips), 2) if incorrect_clips else None,
        })

    summary = {
        "what": "how many missing letters it should take to flag a word when "
                "nothing else is wrong with it",
        "words_on_correctly_recited_clips": len(correct_words),
        "incorrect_clips": len(incorrect_clips),
        "today": "bar = 1 (MAKHRAJ_MIN_FINDINGS = 1 never suppresses anything)",
        "settings": settings,
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2), encoding="utf-8")

    print(f"words on correctly-recited clips : {len(correct_words)}")
    print(f"clips marked incorrect           : {len(incorrect_clips)}")
    print()
    print(f"  {'bar':>4} {'wrongly flagged':>17} {'incorrect clips caught':>24}")
    for s in settings:
        mark = "  <- today" if s["bar"] == 1 else ""
        print(f"  {s['bar']:>4} {str(s['pct_words_wrongly_flagged']) + '%':>17} "
              f"{str(s['pct_incorrect_clips_caught']) + '%':>24}{mark}")
    print(f"\n  -> {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
