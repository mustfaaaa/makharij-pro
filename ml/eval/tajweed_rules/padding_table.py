"""Compare end-padding strategies (results/pad_*, plus c1_c2_final = -60 dBFS as
committed). Every strategy is scored by the same verdict code; the reference is
pad_zeros (digital silence through the same path).

Columns:
  correct madd FP      correct clips with a word reported as madd
  new regressions      correct-clip words that were ok with digital silence and are now
                       flagged ("ok->flag"); words that were "not recited" and are now
                       flagged are counted separately ("unread->flag")
  fixed final madd     correct-clip LAST words flagged madd with digital silence, ok now
  incorrect clips      share of incorrect clips with any flag
  expert flags         flagged words on professional recitation (+ changed vs silence)
  seed flips           learner word verdicts that differ when only the noise seed changes

    backend/.venv/Scripts/python.exe ml/eval/tajweed_rules/padding_table.py
"""
import json
from pathlib import Path

import harness as H

VOTES = json.loads((H.HERE / "evalset_votes.json").read_text(encoding="utf-8"))
STRATS = [("A digital silence (baseline)", "pad_zeros"), ("B -60 dBFS, 1.5 s (C1)", "c1_c2_final"),
          ("C -70 dBFS, 1.5 s", "pad_n70"), ("C' -80 dBFS, 1.5 s", "pad_n80"),
          ("D recording floor -10 dB", "pad_floor10"), ("E recording's own room tone", "pad_roomtone"),
          ("F -70 dBFS, 1.0 s", "pad_n70_1s")]
SEEDS = {"c1_c2_final": "pad_n60_s1", "pad_n70": "pad_n70_s1", "pad_n80": "pad_n80_s1"}


def words(name, part):
    p = H.RESULTS / name / f"words_{part}.jsonl"
    return {(w["clip"], w["i"]): w for w in H.jsonl_read(p)} if p.exists() else None


def flagged(w):
    return w["recited"] and not w["correct"]


def main():
    ref_l, ref_e = words("pad_zeros", "learners"), words("pad_zeros", "experts")
    rows = []
    for label, name in STRATS:
        wl, we = words(name, "learners"), words(name, "experts")
        if wl is None:
            rows.append(f"| {label} | (not run) | | | | | |")
            continue
        body = {k: w for k, w in wl.items() if w["exp"] and not w["in_prefix"]}
        cor = [c for c in VOTES if VOTES[c]["label"] == "correct"]
        inc = [c for c in VOTES if VOTES[c]["label"] == "in_correct"]
        madd_fp = len({w["clip"] for w in body.values() if w["label"] == "correct" and flagged(w) and w["type"] == "madd"})
        ok_to_flag = unread_to_flag = fixed_final = 0
        last = {}
        for (c, i), w in body.items():
            if w["recited"]:
                last[c] = max(last.get(c, -1), i)
        for k, w in body.items():
            if w["label"] != "correct":
                continue
            o = ref_l[k]
            if flagged(w) and not flagged(o):
                if o["recited"]:
                    ok_to_flag += 1
                else:
                    unread_to_flag += 1
            if o["type"] == "madd" and flagged(o) and not flagged(w) and w["recited"] and k[1] == last.get(k[0]):
                fixed_final += 1
        any_inc = {w["clip"] for w in body.values() if w["label"] == "in_correct" and flagged(w)}
        exp_txt = "–"
        if we is not None:
            eb = [w for w in we.values() if w["exp"] and not w["in_prefix"]]
            ef = sum(flagged(w) for w in eb)
            ch = sum(1 for k, w in we.items() if (w["recited"], w["correct"]) != (ref_e[k]["recited"], ref_e[k]["correct"]))
            exp_txt = f"{ef}/{len(eb)} ({ch} changed)"
        seed_txt = "–"
        if name in SEEDS and (H.RESULTS / SEEDS[name]).exists():
            ws = words(SEEDS[name], "learners")
            seed_txt = str(sum(1 for k, w in wl.items() if (w["recited"], w["correct"], w["type"]) != (ws[k]["recited"], ws[k]["correct"], ws[k]["type"])))
        rows.append(f"| {label} | {madd_fp} | {ok_to_flag} / {unread_to_flag} | {fixed_final} | "
                    f"{100 * len(any_inc) / len(inc):.1f}% | {exp_txt} | {seed_txt} |")
    out = ["| Strategy | Correct madd FP (clips) | New regressions ok→flag / unread→flag | Fixed final madd | "
           "Incorrect clips flagged | Expert flags | Seed flips |", "|---|--:|--:|--:|--:|--:|--:|"] + rows
    text = "\n".join(out)
    (H.RESULTS / "PADDING_STRATEGIES.md").write_text("# End-padding strategies\n\n" + text + "\n", encoding="utf-8")
    print(text)


if __name__ == "__main__":
    main()
