"""Compare evaluated versions against the first one (the baseline).

    backend/.venv/Scripts/python.exe ml/eval/tajweed_rules/compare.py baseline c1 c1_c2

Writes results/REPORT_<names>.md. What is and is not measurable here:

  * Learner labels are per CLIP (correct / incorrect), never per rule. A clip
    counts as "positive for rule R" when any recited word is reported as R.
    FP / TN / false-positive rate are exact at clip level (up to label noise);
    TP* / FN* / precision* / recall* / F1* only say whether an incorrect clip
    got an R flag somewhere -- its actual mistake may be of another kind -- so
    they are NOT the rule's true precision and recall.
  * Expert recitation is correct by construction: every flag is a false alarm.
  * Controlled edits have certain ground truth: the edit is the error.
"""
import json
import random
import sys
from collections import Counter, defaultdict

import harness as H

RULES = ("madd", "ghunnah", "makhraj", "shaddah")


def load(name):
    d = H.RESULTS / name
    v = {"name": name, "meta": json.loads((d / "meta.json").read_text(encoding="utf-8"))}
    for part in ("words_learners", "opps_learners", "words_experts", "opps_experts", "edits"):
        v[part] = H.jsonl_read(d / f"{part}.jsonl")
    return v


VOTES = json.loads((H.HERE / "evalset_votes.json").read_text(encoding="utf-8"))


def body(words):
    return [w for w in words if w["exp"] and not w["in_prefix"]]


def flagged(w):
    return w["recited"] and not w["correct"]


def clip_sets(v):
    by = defaultdict(list)
    for w in body(v["words_learners"]):
        by[w["clip"]].append(w)
    return by


def rule_confusion(v, clips):
    by = clip_sets(v)
    out = {}
    for rule in RULES:
        pos = {c for c in clips if any(flagged(w) and w["type"] == rule for w in by[c])}
        cor = [c for c in clips if VOTES[c]["label"] == "correct"]
        inc = [c for c in clips if VOTES[c]["label"] == "in_correct"]
        tp, fn = sum(c in pos for c in inc), sum(c not in pos for c in inc)
        fp, tn = sum(c in pos for c in cor), sum(c not in pos for c in cor)
        prec = tp / (tp + fp) if tp + fp else 0.0
        rec = tp / (tp + fn) if tp + fn else 0.0
        out[rule] = {"TP*": tp, "FP": fp, "TN": tn, "FN*": fn, "precision*": prec, "recall*": rec,
                     "F1*": 2 * prec * rec / (prec + rec) if prec + rec else 0.0,
                     "FPR": fp / (fp + tn) if fp + tn else 0.0, "FNR*": fn / (tp + fn) if tp + fn else 0.0}
    return out


def clip_rates(v, clips):
    by = clip_sets(v)
    cor = [c for c in clips if VOTES[c]["label"] == "correct"]
    inc = [c for c in clips if VOTES[c]["label"] == "in_correct"]
    any_flag = lambda c: any(flagged(w) for w in by[c])
    cw = [w for c in cor for w in by[c]]
    return {"correct clips with any flag": sum(map(any_flag, cor)) / len(cor),
            "incorrect clips flagged": sum(map(any_flag, inc)) / len(inc),
            "word flags on correct clips": sum(map(flagged, cw)) / len(cw),
            "madd-flagged correct clips": sum(any(flagged(w) and w["type"] == "madd" for w in by[c]) for c in cor) / len(cor)}


def ikhfa_fp(v, clips):
    cor = {c for c in clips if VOTES[c]["label"] == "correct"}
    hit = {o["clip"] for o in v["opps_learners"] if o["kind"] == "ikhfa" and o["finding"] and o["clip"] in cor}
    return len(hit)


def opp_rates(v):
    out = {}
    for kind in ("madd", "ghunnah", "ikhfa"):
        for group, keep in (("expert", lambda o: o["label"] == "expert"),
                            ("correct(agreed)", lambda o: o["label"] == "correct" and VOTES[o["clip"]]["agreed"]),
                            ("correct(disputed)", lambda o: o["label"] == "correct" and not VOTES[o["clip"]]["agreed"]),
                            ("incorrect", lambda o: o["label"] == "in_correct")):
            xs = [o for o in v["opps_experts"] + v["opps_learners"]
                  if o["kind"] == kind and not o["in_prefix"] and keep(o)]
            if xs:
                out[(kind, group)] = (sum(1 for o in xs if o["finding"]), len(xs))
    return out


def expert_flags(v):
    ws = body(v["words_experts"])
    f = [w for w in ws if flagged(w)]
    return len(f), len(ws), Counter(w["type"] for w in f)


def edit_detection(v):
    want = {"madd4_short": "madd", "natural_long4": "madd", "natural_long6": "madd", "ghunnah_short": "ghunnah",
            "lazim_to2": "madd", "lazim_to4": "madd", "control": None, "lazim_control": None}
    out = {}
    for cond in want:
        rs = [e for e in v["edits"] if e["cond"] == cond]
        if rs:
            out[cond] = {"n": len(rs), "flagged": sum(not e["word_correct"] for e in rs),
                         "as_rule": sum(e["word_type"] == want[cond] for e in rs) if want[cond] else None,
                         "collateral": sum(e["other_words_flagged"] for e in rs)}
    return out


def bootstrap(base, var, metric, clips, n=1000):
    reciter = {}
    for w in base["words_learners"]:
        reciter[w["clip"]] = w["reciter"]
    groups = defaultdict(list)
    for c in clips:
        groups[reciter[c]].append(c)
    keys = sorted(groups)
    rng = random.Random(0)
    d = []
    for _ in range(n):
        sample = [c for k in (rng.choice(keys) for _ in keys) for c in groups[k]]
        try:
            d.append(metric(var, sample) - metric(base, sample))
        except ZeroDivisionError:
            pass
    d.sort()
    return d[int(0.025 * len(d))], d[int(0.975 * len(d))]


def changes(base, var, part):
    key = lambda w: (w["clip"], w["i"])
    b = {key(w): w for w in base[part]}
    out = defaultdict(list)
    for w in var[part]:
        o = b[key(w)]
        if (o["recited"], o["correct"], o["type"]) == (w["recited"], w["correct"], w["type"]):
            continue
        lab = w["label"]
        if flagged(o) and not flagged(w):
            kind = "cleared"
        elif flagged(w) and not flagged(o):
            kind = "newly flagged"
        elif flagged(o) and flagged(w):
            kind = "type changed"
        else:
            kind = "recited status changed"
        out[(lab, kind)].append((o, w))
    return out


def pct(x):
    return f"{100 * x:.1f}%"


def main():
    names = sys.argv[1:]
    vs = [load(n) for n in names]
    base = vs[0]
    all_clips = sorted(VOTES)
    agreed = [c for c in all_clips if VOTES[c]["label"] == "in_correct" or VOTES[c]["agreed"]]
    L = [f"# Madd / Ghunnah evaluation: {' vs '.join(names)}", ""]
    for v in vs:
        m = v["meta"]
        L.append(f"- **{v['name']}**: code {m['git_head']}"
                 + (f" + uncommitted backend diff {m['backend_diff_sha1'][:10]}" if m["backend_uncommitted_changes"] else "")
                 + f", run {m['started']}")
    L += ["", "Learner labels are per clip. FP/TN/FPR are exact at clip level; TP*/FN*/precision*/recall*/F1* only say "
          "whether an incorrect clip got that rule's flag somewhere (its real mistake may be another kind), so they are "
          "not the rule's true precision/recall.", ""]

    for title, clips in (("All 773 clips", all_clips),
                         ("Correct clips restricted to those every annotator agreed on (+ all incorrect)", agreed)):
        L += [f"## Per-rule clip-level confusion — {title}", "",
              "| Rule | Version | TP* | FP | TN | FN* | precision* | recall* | F1* | FPR | FNR* |",
              "|---|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|"]
        conf = [rule_confusion(v, clips) for v in vs]
        for rule in RULES:
            for v, c in zip(vs, conf):
                r = c[rule]
                L.append(f"| {rule} | {v['name']} | {r['TP*']} | {r['FP']} | {r['TN']} | {r['FN*']} | {r['precision*']:.2f} | "
                         f"{r['recall*']:.2f} | {r['F1*']:.2f} | {pct(r['FPR'])} | {pct(r['FNR*'])} |")
        L += ["", f"Ikhfa FP (correct clips with an ikhfa finding): " +
              ", ".join(f"{v['name']} {ikhfa_fp(v, clips)}" for v in vs), ""]
        L += ["| Clip-level rate | " + " | ".join(v["name"] for v in vs) + " | Δ vs baseline (95% CI, reciter bootstrap) |",
              "|---|" + "--:|" * len(vs) + "---|"]
        rates = [clip_rates(v, clips) for v in vs]
        for k in rates[0]:
            cis = []
            for v in vs[1:]:
                lo, hi = bootstrap(base, v, lambda vv, cc, k=k: clip_rates(vv, cc)[k], clips)
                cis.append(f"{v['name']}: {100 * (clip_rates(v, clips)[k] - rates[0][k]):+.1f} pts [{100 * lo:+.1f}, {100 * hi:+.1f}]")
            L.append(f"| {k} | " + " | ".join(pct(r[k]) for r in rates) + " | " + "; ".join(cis) + " |")
        L.append("")

    L += ["## Per-opportunity findings (finding fired / opportunities)", "",
          "| Opportunity | Group | " + " | ".join(v["name"] for v in vs) + " |", "|---|---|" + "--:|" * len(vs)]
    ors = [opp_rates(v) for v in vs]
    for key in ors[0]:
        L.append(f"| {key[0]} | {key[1]} | " + " | ".join(f"{o[key][0]}/{o[key][1]} ({100 * o[key][0] / o[key][1]:.1f}%)" for o in ors) + " |")
    L += ["", "## Expert recitation (every flag is a false alarm)", "",
          "| Version | flagged words | by type |", "|---|--:|---|"]
    for v in vs:
        f, n, t = expert_flags(v)
        L.append(f"| {v['name']} | {f}/{n} ({100 * f / n:.2f}%) | {dict(t)} |")
    L += ["", "## Controlled edits (ground truth = the edit)", "",
          "| Condition | " + " | ".join(f"{v['name']} flagged / as intended rule / collateral" for v in vs) + " |",
          "|---|" + "---|" * len(vs)]
    eds = [edit_detection(v) for v in vs]
    for cond in eds[0]:
        L.append(f"| {cond} (n={eds[0][cond]['n']}) | " + " | ".join(
            f"{e[cond]['flagged']} / {e[cond]['as_rule'] if e[cond]['as_rule'] is not None else '–'} / {e[cond]['collateral']}"
            for e in eds) + " |")
    L += ["", "## Latency (this machine, one process)", "",
          "| Version | set | clips | audio s | decode s | analysis s | real-time factor |", "|---|---|--:|--:|--:|--:|--:|"]
    for v in vs:
        for s in ("learners", "experts"):
            lt = v["meta"].get(f"latency_{s}")
            if lt:
                L.append(f"| {v['name']} | {s} | {lt['clips']} | {lt['audio_sec']} | {lt['decode_sec_total']} | "
                         f"{lt['analysis_sec_total']} | {lt['real_time_factor']} |")

    for v in vs[1:]:
        L += ["", f"## Every verdict that changed: {base['name']} → {v['name']}", ""]
        for part in ("words_learners", "words_experts"):
            ch = changes(base, v, part)
            L.append(f"**{part.split('_')[1]}**: " + (", ".join(f"{lab} / {k}: {len(x)}" for (lab, k), x in sorted(ch.items())) or "none"))
            L.append("")
            for (lab, k), xs in sorted(ch.items()):
                for o, w in xs:
                    L.append(f"- {lab} · {k} · {w['surah']}:{w['ayah']} word {w['i']} {w['word']} · "
                             f"{o['type'] or ('ok' if o['recited'] else 'not recited')} → {w['type'] or ('ok' if w['recited'] else 'not recited')} · "
                             f"heard `{o['pred']}` → `{w['pred']}` · expected `{w['exp']}` · clip {w['clip'][:8]}")
            L.append("")
    path = H.RESULTS / f"REPORT_{'_vs_'.join(names)}.md"
    path.write_text("\n".join(L) + "\n", encoding="utf-8")
    print("wrote", path)


if __name__ == "__main__":
    main()
