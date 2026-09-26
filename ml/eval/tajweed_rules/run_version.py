"""Evaluate the checked-out backend on all three sets and freeze the results.

    backend/.venv/Scripts/python.exe ml/eval/tajweed_rules/run_version.py baseline --make-manifest
    backend/.venv/Scripts/python.exe ml/eval/tajweed_rules/run_version.py c1

Writes results/<name>/ and refuses to overwrite an existing one. Committed:
meta.json (code version, timings), decodes_*.jsonl (the raw recogniser output),
edits.jsonl. Regenerated locally (gitignored): words_*.jsonl, opps_*.jsonl.
Run versions one at a time -- the latency numbers assume nothing else is
competing for the CPU.
"""
import argparse
import hashlib
import json
import random
import statistics as st
import subprocess
import time

import harness as H


def make_manifest(expert_opps: list[dict], items: dict) -> list[dict]:
    """The controlled edits, chosen once from the baseline decode and reused by
    every later version so all versions judge byte-identical audio."""
    usable = [o for o in expert_opps
              if not o["in_prefix"] and o["p_ch"] == o["e_ch"] and o["p_n"] == o["e_n"]
              and o["word_type"] is None and o.get("t_prev") is not None and o.get("t_run")
              and o.get("cv_med") and o["t_run"] - o["t_prev"] > 0.15]
    conditions = {
        # name: (pool filter, target syllable length in tempo units, None = unchanged)
        "control": (lambda o: o["kind"] == "madd", None),
        "madd4_short": (lambda o: o["kind"] == "madd" and o["e_n"] == 4, 0.8),
        "natural_long4": (lambda o: o["kind"] == "madd" and o["e_n"] == 2 and o["context"] == "natural", 3.2),
        "natural_long6": (lambda o: o["kind"] == "madd" and o["e_n"] == 2 and o["context"] == "natural", 10.0),
        "ghunnah_short": (lambda o: o["kind"] == "ghunnah", 1.0),
        "lazim_control": (lambda o: o["kind"] == "madd" and o["e_n"] == 6, None),
        "lazim_to2": (lambda o: o["kind"] == "madd" and o["e_n"] == 6, 0.8),
        "lazim_to4": (lambda o: o["kind"] == "madd" and o["e_n"] == 6, 3.2),
    }
    rng = random.Random(0)
    out = []
    for cond, (keep, target) in conditions.items():
        pool = [o for o in usable if keep(o)]
        rng.shuffle(pool)
        seen = set()
        for o in pool:
            if o["clip"] in seen:
                continue
            r0 = int((o["t_prev"] + 0.08) * H.SR)
            r1 = int((o["t_run"] - 0.02) * H.SR)
            if r1 - r0 < int(0.06 * H.SR):
                continue
            if target is None:
                new_len = r1 - r0
            else:
                new_len = max(int(0.04 * H.SR), int((target * o["cv_med"] - 0.10) * H.SR))
                if (target < 1.5 and new_len >= r1 - r0) or (target >= 1.5 and "long" in cond and new_len <= r1 - r0) \
                        or (cond.startswith("lazim_to") and new_len >= r1 - r0):
                    continue
            it = items[o["clip"]]
            seen.add(o["clip"])
            out.append({"id": len(out), "cond": cond, "clip": o["clip"],
                        "path": str(H.Path(it["path"]).relative_to(H.REPO)).replace("\\", "/"),
                        "surah": it["surah"], "ayah": it["ayah"], "word_i": o["word_i"], "e_off": o["e_off"],
                        "word": o["word"], "kind": o["kind"], "e_n": o["e_n"], "context": o.get("context"),
                        "r0": r0, "r1": r1, "new_len": new_len,
                        "syllable_len_before": H.syllable_len(o)})
            if sum(1 for e in out if e["cond"] == cond) == 40:
                break
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("name")
    ap.add_argument("--make-manifest", action="store_true", help="baseline only: choose the controlled edits")
    ap.add_argument("--limit", type=int, help="smoke test on the first N items of each set")
    args = ap.parse_args()
    out = H.RESULTS / args.name
    if out.exists():
        raise SystemExit(f"{out} exists -- results are never overwritten; pick a new name")
    out.mkdir(parents=True)

    diff = subprocess.run(["git", "diff", "HEAD", "--", "backend/app"], cwd=H.REPO, capture_output=True).stdout
    meta = {"name": args.name, "git_head": H.git_head(), "backend_uncommitted_changes": bool(diff),
            "backend_diff_sha1": hashlib.sha1(diff).hexdigest() if diff else None,
            "started": time.strftime("%Y-%m-%d %H:%M:%S")}
    svc = H.PhonemeAnalysisService()

    sets = {"learners": H.learner_items(), "experts": H.expert_items()}
    all_items = {}
    for name, items in sets.items():
        items = items[: args.limit] if args.limit else items
        decodes, words, opps = [], [], []
        dec_s, score_s, audio_s = [], [], 0.0
        for it in items:
            y = H.load_audio(it["path"])
            audio_s += len(y) / H.SR
            t = time.perf_counter()
            tokens, times = H.decode(svc, y)
            dec_s.append(time.perf_counter() - t)
            t = time.perf_counter()
            w, o = H.analyse_clip(svc, it, tokens, times)
            score_s.append(time.perf_counter() - t)
            decodes.append({"clip": it["clip"], "tokens": tokens, "times": [round(x, 3) for x in times]})
            for r in w:
                r.update(label=it["label"], reciter=it["reciter"], surah=it["surah"], ayah=it["ayah"])
            for r in o:
                r.update(label=it["label"], reciter=it["reciter"], surah=it["surah"], ayah=it["ayah"])
            words += w
            opps += o
            all_items[it["clip"]] = it
        H.jsonl_write(out / f"decodes_{name}.jsonl", decodes)
        H.jsonl_write(out / f"words_{name}.jsonl", words)
        H.jsonl_write(out / f"opps_{name}.jsonl", opps)
        meta[f"latency_{name}"] = {
            "clips": len(items), "audio_sec": round(audio_s, 1),
            "decode_sec_total": round(sum(dec_s), 2), "analysis_sec_total": round(sum(score_s), 3),
            "decode_ms_median": round(1000 * st.median(dec_s), 1), "analysis_ms_median": round(1000 * st.median(score_s), 2),
            "real_time_factor": round((sum(dec_s) + sum(score_s)) / audio_s, 4)}
        print(name, meta[f"latency_{name}"], flush=True)
        if name == "experts" and args.make_manifest:
            manifest = make_manifest(opps, all_items)
            (H.HERE / "edits_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=1),
                                                          encoding="utf-8")

    manifest = json.loads((H.HERE / "edits_manifest.json").read_text(encoding="utf-8"))
    if args.limit:
        manifest = manifest[: args.limit]
    edits = []
    for e in manifest:
        e2 = dict(e, path=str(H.REPO / e["path"]))
        edits.append(H.judge_edit(svc, e2))
    H.jsonl_write(out / "edits.jsonl", edits)
    meta["finished"] = time.strftime("%Y-%m-%d %H:%M:%S")
    (out / "meta.json").write_text(json.dumps(meta, indent=1), encoding="utf-8")
    print("done", out)


if __name__ == "__main__":
    main()
