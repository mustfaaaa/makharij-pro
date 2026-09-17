"""Where do the app's Tajweed verdicts actually come from?

The defect this investigates
----------------------------
82% of the errors the app reports say `makhraj`, which is the residual
category -- the one used when nothing more specific fits. Meanwhile ghunnah is
carried by 23% of Quranic words but is 1% of what we report, and madd by 57%
but only 5%. Either learners overwhelmingly make articulation mistakes, or the
classifier is funnelling named-rule violations into the catch-all.

Guessing which is not useful. `classify()` has seven distinct branches that can
emit a finding; this re-runs it over every word in the learner corpus, tags
each finding with the branch that produced it, and counts.

It needs no audio and no model: ml/eval/results/word_level.jsonl already holds
the expected and predicted phonemes for every word of every clip, so this is a
pure re-analysis of decodes that already happened.

    backend/.venv/Scripts/python.exe ml/eval/attribution_breakdown.py
"""
from __future__ import annotations

import argparse
import collections
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "backend"))

WORD_LEVEL = REPO / "ml" / "eval" / "results" / "word_level.jsonl"
OUT = REPO / "ml" / "eval" / "results" / "attribution_breakdown.json"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--words", type=Path, default=WORD_LEVEL)
    parser.add_argument("--out", type=Path, default=OUT)
    args = parser.parse_args()

    from app import tajweed_diff
    from app.tajweed_diff import MAKHRAJ, align, runs

    MARK_CHARS = tajweed_diff.MARK_CHARS
    ELONGATION_CHARS = tajweed_diff.ELONGATION_CHARS

    def branches(expected: str, predicted: str) -> list[tuple[str, str]]:
        """Re-walk classify()'s decisions, naming the branch each one took.

        Mirrors classify() rather than importing it, because the branch a
        finding came from is exactly the information classify() throws away.
        Kept adjacent to it so the two can be diffed by eye.
        """
        if not expected:
            return []
        if not predicted.strip():
            return [("skipped", "word not heard at all")]

        exp_runs, pred_runs = runs(expected), runs(predicted)
        _dist, pairs = align(pred_runs, exp_runs)
        out: list[tuple[str, str]] = []

        for pi, ei in pairs:
            p_ch, p_n = pred_runs[pi] if pi is not None else (None, 0)
            e_ch, e_n = exp_runs[ei] if ei is not None else (None, 0)

            if ei is None:
                if (p_ch not in MARK_CHARS and p_ch not in ELONGATION_CHARS
                        and p_n >= 2):
                    out.append(("extra_sound", MAKHRAJ))
                continue

            kind = tajweed_diff._kind(e_ch, e_n)

            if p_ch is None:
                if kind in (tajweed_diff.MADD, tajweed_diff.GHUNNAH,
                            tajweed_diff.SHADDAH, "ikhfa"):
                    out.append((f"run_absent:{kind}", kind))
                elif e_ch not in MARK_CHARS:
                    out.append(("run_absent:other", MAKHRAJ))
                continue

            if p_ch != e_ch:
                if e_ch in MARK_CHARS or p_ch in MARK_CHARS:
                    continue
                # The branch under suspicion: whatever rule the expected run
                # carried, a substituted letter is reported as makhraj.
                out.append((f"substituted_over:{kind}", MAKHRAJ))
                continue

            if p_n == e_n:
                continue
            if kind == tajweed_diff.MADD:
                dropped = (p_n < e_n and e_n >= 4
                           and p_n <= tajweed_diff.MADD_DROPPED_MAX)
                if dropped or abs(p_n - e_n) > tajweed_diff.MADD_COUNT_TOLERANCE:
                    out.append(("length:madd", tajweed_diff.MADD))
            elif kind == tajweed_diff.GHUNNAH:
                if (p_n <= tajweed_diff.GHUNNAH_DROPPED_MAX
                        or abs(p_n - e_n) > tajweed_diff.GHUNNAH_COUNT_TOLERANCE):
                    out.append(("length:ghunnah", tajweed_diff.GHUNNAH))
            elif kind == tajweed_diff.SHADDAH and p_n < e_n:
                out.append(("length:shaddah", tajweed_diff.SHADDAH))
        return out

    rows = [json.loads(l) for l in
            args.words.read_text(encoding="utf-8").splitlines() if l.strip()]

    by_branch = collections.Counter()
    by_reported = collections.Counter()
    # What the expected run carried, on the findings the catch-all swallowed.
    swallowed = collections.Counter()
    words_seen = words_flagged = 0

    for row in rows:
        for word in row.get("words", []):
            expected, predicted = word.get("expected", ""), word.get("predicted", "")
            if not expected:
                continue
            words_seen += 1
            found = branches(expected, predicted)
            if not found:
                continue
            words_flagged += 1
            for branch, reported in found:
                by_branch[branch] += 1
                by_reported[reported] += 1
                if branch.startswith("substituted_over:"):
                    swallowed[branch.split(":", 1)[1]] += 1

    total = sum(by_branch.values()) or 1
    summary = {
        "what": "which branch of classify() produced each finding, over the "
                "learner corpus",
        "clips": len(rows),
        "words_with_an_expectation": words_seen,
        "words_producing_at_least_one_finding": words_flagged,
        "findings_total": sum(by_branch.values()),
        "by_branch": {k: {"count": v, "pct": round(100 * v / total, 1)}
                      for k, v in by_branch.most_common()},
        "by_reported_type": {k: {"count": v, "pct": round(100 * v / total, 1)}
                             for k, v in by_reported.most_common()},
        "rule_the_substitution_branch_swallowed": dict(swallowed.most_common()),
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, ensure_ascii=False),
                        encoding="utf-8")

    print(f"clips {len(rows)}   words {words_seen}   "
          f"words with a finding {words_flagged}")
    print(f"\nfindings by branch ({total} total)")
    for branch, count in by_branch.most_common():
        print(f"  {branch:32} {count:6}  {100 * count / total:5.1f}%")
    print("\nreported as")
    for kind, count in by_reported.most_common():
        print(f"  {kind:32} {count:6}  {100 * count / total:5.1f}%")
    if swallowed:
        print("\nwhat the expected run carried when a substitution was "
              "reported as makhraj")
        for kind, count in swallowed.most_common():
            print(f"  {kind:32} {count:6}")
    print(f"\n  -> {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
