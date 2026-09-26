"""Which way of measuring a madd's length is most robust? (Phase 6, without QDAT-Bench)

Three measurements of the same thing -- how long the syllable holding a madd
lasted, from the timestamp of the unit before it to the unit after it:

  A  absolute seconds
  B  / the recording's median short-syllable interval (whole-recording tempo)
  C  / the median short-syllable interval of the 4 units either side (local tempo)

Judged on what our own data can show (label correlation needs rule-level
learner labels, i.e. QDAT-Bench, which is not used -- licence unverified):
  1. stability across speakers   natural (2-count) madd, spread of per-reciter medians
  2. speed                       |Spearman| with the recording's tempo (0 = speed-free)
  3. recording quality           |Spearman| with learner SNR
  4. separation                  expert natural vs lazim AUC; controlled lazim edits
                                 (unedited vs cut to ~4 counts) AUC

    backend/.venv/Scripts/python.exe ml/eval/tajweed_rules/normalization.py baseline
"""
import json
import statistics as st
import sys
from collections import defaultdict

import numpy as np

import harness as H


def spearman(x, y):
    rx = np.argsort(np.argsort(x))
    ry = np.argsort(np.argsort(y))
    return float(np.corrcoef(rx, ry)[0, 1])


def auc(neg, pos):
    neg, pos = np.asarray(neg), np.asarray(pos)
    return float((pos[:, None] > neg[None, :]).mean() + 0.5 * (pos[:, None] == neg[None, :]).mean())


def local_tempo(tokens, times, k):
    iv = [times[j + 1] - times[j] for j in range(max(0, k - 5), min(len(tokens) - 1, k + 5))
          if j not in (k - 1, k) and len(tokens[j]) == 2 and tokens[j][0] in H.CONSONANTS
          and tokens[j][1] in H.SHORT_VOWELS and tokens[j + 1][:1] in H.CONSONANTS]
    return st.median(iv) if len(iv) >= 2 else None


def measures(o, dec):
    if o.get("t_prev") is None or o.get("t_next") is None or not o.get("cv_med"):
        return None
    tokens, times = dec["tokens"], dec["times"]
    k = min(range(len(times)), key=lambda j: abs(times[j] - o["t_run"]))
    loc = local_tempo(tokens, times, k)
    s = o["t_next"] - o["t_prev"]
    return {"A": s, "B": s / o["cv_med"], "C": s / loc if loc else None, "tempo": o["cv_med"]}


def main():
    name = sys.argv[1] if len(sys.argv) > 1 else "baseline"
    d = H.RESULTS / name
    rows = []
    for part in ("learners", "experts"):
        decs = {x["clip"]: x for x in H.jsonl_read(d / f"decodes_{part}.jsonl")}
        for o in H.jsonl_read(d / f"opps_{part}.jsonl"):
            if o["in_prefix"] or o["p_ch"] != o["e_ch"]:
                continue
            m = measures(o, decs[o["clip"]])
            if m:
                rows.append({**o, **m})
    snr = {}
    diag = H.Path(sys.argv[2]) if len(sys.argv) > 2 else None
    if diag and diag.is_file():
        for l in open(diag, encoding="utf-8"):
            c = json.loads(l)
            snr[c["clip"]] = c.get("snr_db")

    natural = [r for r in rows if r["kind"] == "madd" and r["e_n"] == 2 and r["context"] == "natural"]
    print(f"natural (2-count, inside a word) madds measured: {len(natural)}")
    for meth in ("A", "B", "C"):
        xs = [r for r in natural if r[meth] is not None]
        by = defaultdict(list)
        for r in xs:
            by[r["reciter"]].append(r[meth])
        med = [st.median(v) for v in by.values() if len(v) >= 5]
        spread = (np.percentile(med, 90) / np.percentile(med, 10)) if med else float("nan")
        within = st.median([(np.percentile(v, 75) - np.percentile(v, 25)) / st.median(v) for v in by.values() if len(v) >= 5])
        sp = spearman([r[meth] for r in xs], [r["tempo"] for r in xs])
        lx = [r for r in xs if r["label"] != "expert" and snr.get(r["clip"]) is not None]
        q = spearman([r[meth] for r in lx], [snr[r["clip"]] for r in lx]) if lx else float("nan")
        exp_nat = [r[meth] for r in rows if r["label"] == "expert" and r["kind"] == "madd" and r["e_n"] == 2
                   and r["context"] == "natural" and r[meth] is not None]
        exp_laz = [r[meth] for r in rows if r["label"] == "expert" and r["kind"] == "madd" and r["e_n"] == 6 and r[meth] is not None]
        print(f"  {meth}: speakers(>=5 madds) {len(med)}  P90/P10 of per-speaker medians {spread:.2f}  "
              f"within-speaker IQR/median {within:.2f}  |rho| with tempo {abs(sp):.2f}  "
              f"|rho| with SNR {abs(q):.2f}  expert natural-vs-lazim AUC {auc(exp_nat, exp_laz):.3f}")


if __name__ == "__main__":
    main()
