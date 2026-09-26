"""Phase 14: a small, hand-picked set of real cases, read side by side across
versions -- expected Tajweed, what was heard, its timing, and each verdict.

    backend/.venv/Scripts/python.exe ml/eval/tajweed_rules/sanity.py baseline c1 c1_c2

Cases are picked by rule, not by outcome: the first matching opportunity in a
fixed order, so the selection does not depend on which version is better.
Writes results/SANITY_<names>.md.
"""
import json
import sys

import harness as H


def load(name):
    d = H.RESULTS / name
    return {part: H.jsonl_read(d / f"{part}.jsonl")
            for part in ("words_learners", "opps_learners", "words_experts", "opps_experts", "edits")}


VOTES = json.loads((H.HERE / "evalset_votes.json").read_text(encoding="utf-8"))
MANIFEST = {e["id"]: e for e in json.loads((H.HERE / "edits_manifest.json").read_text(encoding="utf-8"))}


def agreed_correct(o):
    return o["label"] == "correct" and VOTES[o["clip"]]["agreed"]


def is_last(o):
    return o["word_i"] == o["n_words"] - 1


# (title, set, predicate on the BASELINE opportunity)
CASES = [
    ("Correct natural madd (expert)", "experts",
     lambda o: o["kind"] == "madd" and o["e_n"] == 2 and o["context"] == "natural" and not o["finding"]),
    ("Munfasil held short (expert, valid qasr)", "experts",
     lambda o: o["kind"] == "madd" and o["context"] == "munfasil" and H.syllable_len(o) and H.syllable_len(o) < 2.2),
    ("Lazim (expert)", "experts", lambda o: o["kind"] == "madd" and o["e_n"] == 6 and not o["finding"]),
    ("Lazim, learner, measured short", "learners",
     lambda o: o["kind"] == "madd" and o["e_n"] == 6 and H.syllable_len(o) and H.syllable_len(o) < 6),
    ("Aarid at the ayah's end (learner, agreed correct)", "learners",
     lambda o: o["kind"] == "madd" and o["context"] == "aarid" and agreed_correct(o) and not o["finding"]),
    ("Final-word madd lost at the end (learner, agreed correct)", "learners",
     lambda o: o["kind"] == "madd" and is_last(o) and agreed_correct(o) and (o["finding"] or "").startswith("absent")),
    ("Correct ghunnah (learner, agreed correct)", "learners",
     lambda o: o["kind"] == "ghunnah" and agreed_correct(o) and not o["finding"]),
    ("Short ghunnah (learner)", "learners", lambda o: o["kind"] == "ghunnah" and o["finding"] == "length:ghunnah"),
    ("Ikhfa said as a plain noon (learner)", "learners", lambda o: o["kind"] == "ikhfa" and o["finding"] == "subst:ikhfa"),
    ("Correct ikhfa (learner)", "learners", lambda o: o["kind"] == "ikhfa" and not o["finding"]),
]
EDIT_CASES = [("Madd cut short (controlled edit of expert audio)", "lazim_to4"),
              ("Natural madd over-stretched (controlled edit)", "natural_long6"),
              ("Ghunnah cut short (controlled edit)", "ghunnah_short")]


def main():
    names = sys.argv[1:]
    vs = {n: load(n) for n in names}
    base = vs[names[0]]
    L = [f"# Sanity check: {' → '.join(names)}", ""]
    for title, part, pick in CASES:
        opps = [o for o in base[f"opps_{part}"] if not o["in_prefix"] and pick(o)]
        L.append(f"## {title}")
        if not opps:
            L += ["(no such case in this set)", ""]
            continue
        for o in opps[:2]:
            s = H.syllable_len(o)
            L.append(f"- **{o['surah']}:{o['ayah']} {o['word']}** ({o['label']}, clip {o['clip'][:18]}) — expected "
                     f"`{o['exp']}` ({o['e_ch']}×{o['e_n']}{', ' + o['context'] if o.get('context') else ''})")
            for n in names:
                w = next(x for x in vs[n][f"words_{part}"] if x["clip"] == o["clip"] and x["i"] == o["word_i"])
                oo = next((x for x in vs[n][f"opps_{part}"] if x["clip"] == o["clip"] and x["word_i"] == o["word_i"]
                           and x["e_off"] == o["e_off"]), None)
                sl = H.syllable_len(oo) if oo else None
                L.append(f"  - {n}: heard `{w['pred']}` · emitted {oo['p_ch'] if oo else '–'}×{oo['p_n'] if oo else '–'} · "
                         f"timing {f'{sl:.2f} tempo units' if sl else 'n/a'} · verdict **{w['type'] or ('correct' if w['recited'] else 'not recited')}**"
                         + (f" — “{w['explanation']}”" if w.get("explanation") else ""))
            _ = s
        L.append("")
    for title, cond in EDIT_CASES:
        L.append(f"## {title}")
        for e in [e for e in base["edits"] if e["cond"] == cond][:2]:
            m = MANIFEST[e["id"]]
            L.append(f"- **{m['surah']}:{m['ayah']} {m['word']}** ({m['clip']}) — {m['kind']} ×{m['e_n']}, "
                     f"timing {m['syllable_len_before']:.2f} before the edit")
            for n in names:
                x = next(y for y in vs[n]["edits"] if y["id"] == e["id"])
                sl = x["syllable_len_after"]
                L.append(f"  - {n}: emitted {x['emitted'][0] if x['emitted'] else '–'}×{x['emitted'][1] if x['emitted'] else '–'} · "
                         f"timing after {f'{sl:.2f}' if sl else 'n/a'} · verdict **{x['word_type'] or 'correct'}**")
        L.append("")
    path = H.RESULTS / f"SANITY_{'_'.join(names)}.md"
    path.write_text("\n".join(L) + "\n", encoding="utf-8")
    print("wrote", path)


if __name__ == "__main__":
    main()
