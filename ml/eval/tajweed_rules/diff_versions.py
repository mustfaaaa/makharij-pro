"""Every word whose verdict differs between two evaluated versions -- and why.

    backend/.venv/Scripts/python.exe ml/eval/tajweed_rules/diff_versions.py baseline c1_c2_final

For each changed word: the clip and its annotator agreement, where the word
sits (last recited word?), expected / heard phonemes before and after, the
verdict and explanation before and after, and where the recogniser's output
first diverges -- in seconds relative to the END of the recording, so a
change that only touches the recording's boundary is visible at a glance.

Help / hurt is only asserted where the label allows it: on a correct clip a
flag that disappears helped and a new flag hurt; on an incorrect clip the
label does not say which word was wrong, so the change is "unknown".
Writes results/DIFF_<a>_vs_<b>.md.
"""
import json
import sys

import soundfile as sf

import harness as H

VOTES = json.loads((H.HERE / "evalset_votes.json").read_text(encoding="utf-8"))


def durations():
    out = {}
    for it in H.learner_items() + H.expert_items():
        try:
            out[it["clip"]] = sf.info(it["path"]).duration
        except Exception:
            import librosa
            out[it["clip"]] = librosa.get_duration(path=it["path"])
    return out


def divergence(a, b):
    """First token index where two decodes differ, and its time (from whichever has it)."""
    ta, tb = a["tokens"], b["tokens"]
    k = 0
    while k < min(len(ta), len(tb)) and ta[k] == tb[k]:
        k += 1
    if k == len(ta) == len(tb):
        return None, None
    t = min(x for x in (a["times"][k] if k < len(ta) else None, b["times"][k] if k < len(tb) else None) if x is not None)
    return k, t


def verdict(w):
    return w["type"] or ("ok" if w["recited"] else "not recited")


def main():
    va, vb = sys.argv[1], sys.argv[2]
    dur = durations()
    lines = [f"# Changed verdicts: {va} → {vb}", "",
             "Divergence = when the two decodes' tokens first differ, relative to the end of the recording "
             "(negative = before the end). Help/hurt is asserted only on correct clips.", ""]
    for part in ("learners", "experts"):
        wa = {(w["clip"], w["i"]): w for w in H.jsonl_read(H.RESULTS / va / f"words_{part}.jsonl")}
        wb = H.jsonl_read(H.RESULTS / vb / f"words_{part}.jsonl")
        da = {d["clip"]: d for d in H.jsonl_read(H.RESULTS / va / f"decodes_{part}.jsonl")}
        db = {d["clip"]: d for d in H.jsonl_read(H.RESULTS / vb / f"decodes_{part}.jsonl")}
        last_recited = {}
        for w in wb:
            if w["recited"]:
                last_recited[w["clip"]] = max(last_recited.get(w["clip"], -1), w["i"])
        rows = []
        for w in wb:
            o = wa[(w["clip"], w["i"])]
            if (o["recited"], o["correct"], o["type"]) == (w["recited"], w["correct"], w["type"]):
                continue
            label = w["label"]
            flagged_a = o["recited"] and not o["correct"]
            flagged_b = w["recited"] and not w["correct"]
            if label in ("correct", "expert"):
                effect = "helped" if flagged_a and not flagged_b else ("hurt" if flagged_b and not flagged_a else "category only")
            else:
                effect = "unknown (clip label)"
            k, t = divergence(da[w["clip"]], db[w["clip"]])
            rel = f"{t - dur[w['clip']]:+.2f}s" if t is not None else "decodes identical"
            agreed = VOTES[w["clip"]]["agreed"] if w["clip"] in VOTES else True
            rows.append((effect, label, w, o, rel, agreed, w["i"] == last_recited.get(w["clip"])))
        lines += [f"## {part}: {len(rows)} changed", "",
                  "| Effect | Clip | Label (agreed) | Word | Last word? | Expected | Heard before → after | Verdict before → after | Divergence |",
                  "|---|---|---|---|---|---|---|---|---|"]
        for effect, label, w, o, rel, agreed, last in sorted(rows, key=lambda r: (r[0], r[1])):
            lines.append(f"| {effect} | {w['clip'][:8]} | {label} ({'yes' if agreed else 'no'}) | {w['surah']}:{w['ayah']} w{w['i']} {w['word']} | "
                         f"{'yes' if last else 'no'} | `{w['exp']}` | `{o['pred']}` → `{w['pred']}` | {verdict(o)} → {verdict(w)} | {rel} |")
        lines.append("")
    path = H.RESULTS / f"DIFF_{va}_vs_{vb}.md"
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("wrote", path)


if __name__ == "__main__":
    main()
