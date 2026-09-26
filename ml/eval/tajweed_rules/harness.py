"""Shared machinery for the Madd / Ghunnah evaluation.

Everything here calls the production code (PhonemeAnalysisService._decode,
finish_stream, _score, tajweed_diff) rather than re-implementing it, so a
version's results are exactly what the checked-out backend would report.

Three evaluation sets:

  learners  the 773 labelled learner clips (ml/data/quranic_audio_dataset/evalset)
  experts   professional recitation -- correct by construction, so every flag is
            a false alarm with certain ground truth: Sudais (Al-Fatihah, Juz 30 and
            every ayah that contains a 6-count madd), Alafasy, Yasser
  edits     expert audio with ONE madd / ghunnah deliberately shortened or
            lengthened (edits_manifest.json), so the ground truth is the edit
"""
from __future__ import annotations

import csv
import io
import json
import statistics as st
import sys
import time
from pathlib import Path

import librosa
import numpy as np
import soundfile as sf

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "backend"))

from app import tajweed_diff as td  # noqa: E402
from app.phoneme_analysis_service import PhonemeAnalysisService, SAMPLE_RATE as SR  # noqa: E402

HERE = Path(__file__).resolve().parent
RESULTS = HERE / "results"
EVALSET = REPO / "ml" / "data" / "quranic_audio_dataset" / "evalset"
RECITATIONS = REPO / "backend" / "app" / "static" / "recitations"
PHONEMES = REPO / "backend" / "models_cache" / "quran-lab-zipformer" / "ordered_quran_phonemes.json"

SHORT_VOWELS = set("َُِ")
CONSONANTS = set("ءبتثجحخدذرزسشصضطظعغفقكلمنهوي")


# ── sets ──────────────────────────────────────────────────────────────────────

def learner_items() -> list[dict]:
    rows = csv.DictReader(open(EVALSET / "manifest.csv", encoding="utf-8"))
    return [{"clip": r["clip_id"], "path": str(EVALSET / r["file"]), "surah": int(r["surah"]),
             "ayah": int(r["ayah"]), "label": r["label"], "reciter": r["reciter_id"]} for r in rows]


def expert_items() -> list[dict]:
    table = json.load(open(PHONEMES, encoding="utf-8"))
    six = {k for k, v in table.items() if any(ch * 6 in v["aya_phoneme"] for ch in "اۥۦ")}
    items = []
    for qdir in sorted(p for p in RECITATIONS.iterdir() if p.is_dir()):
        for f in sorted(qdir.glob("*.mp3")):
            s, a = int(f.stem[:3]), int(f.stem[3:])
            if qdir.name == "abdurrahmaan_as_sudais" and not (s == 1 or s >= 78 or f"{s}:{a}" in six):
                continue
            items.append({"clip": f"{qdir.name}/{f.stem}", "path": str(f), "surah": s, "ayah": a,
                          "label": "expert", "reciter": qdir.name})
    return items


def load_audio(path: str) -> np.ndarray:
    y, _ = librosa.load(path, sr=SR, mono=True)
    return y.astype(np.float32)


def wav_bytes(y: np.ndarray) -> bytes:
    buf = io.BytesIO()
    sf.write(buf, y, SR, format="WAV", subtype="PCM_16")
    return buf.getvalue()


# ── production decode + verdicts ──────────────────────────────────────────────

def decode(svc: PhonemeAnalysisService, y: np.ndarray):
    """The upload path, unchanged: WAV bytes -> _decode -> finish_stream."""
    return svc._decode(wav_bytes(y))


def score(svc: PhonemeAnalysisService, tokens, times, surah: int, ayah: int):
    pred_chars, tok_idx = svc._flatten(tokens)
    words = svc._range_words(surah, ayah, ayah)
    prefix = svc._mapper.basmala_prefix_len(surah, ayah) if ayah == 1 else 0
    results = svc._score(pred_chars, tok_idx, times, surah, words, prefix_len=prefix).results
    return results, prefix, pred_chars, tok_idx


def cv_median(tokens, times):
    """The recording's tempo: median interval from a consonant+short-vowel unit
    to the next consonant unit. None when there are fewer than 3 such units."""
    iv = [times[k + 1] - times[k] for k in range(len(tokens) - 1)
          if len(tokens[k]) == 2 and tokens[k][0] in CONSONANTS and tokens[k][1] in SHORT_VOWELS
          and tokens[k + 1][:1] in CONSONANTS]
    return st.median(iv) if len(iv) >= 3 else None


def madd_context(exp_word: str, run_start: int, run_len: int, is_last_word: bool) -> str:
    after = exp_word[run_start + run_len:]
    if after[:1] == "ء":
        return "muttasil"
    if not after:
        return "word-final"
    if len(after) >= 2 and after[0] == after[1]:
        return "lazim"
    if is_last_word and all(c not in SHORT_VOWELS for c in after):
        return "aarid"
    return "natural"


def run_finding(kind, e_ch, e_n, p_run):
    """Which classify() branch fires on one expected run (mirrors tajweed_diff.classify)."""
    if p_run is None:
        return f"absent:{kind}" if (kind in (td.MADD, td.GHUNNAH, td.SHADDAH, "ikhfa") or e_ch not in td.MARK_CHARS) else None
    p_ch, p_n = p_run
    if p_ch != e_ch:
        return None if (e_ch in td.MARK_CHARS or p_ch in td.MARK_CHARS) else f"subst:{kind}"
    if p_n == e_n:
        return None
    if kind == td.MADD:
        dropped = p_n < e_n and e_n >= 4 and p_n <= td.MADD_DROPPED_MAX
        return "length:madd" if dropped or abs(p_n - e_n) > td.MADD_COUNT_TOLERANCE else None
    if kind == td.GHUNNAH:
        return "length:ghunnah" if p_n <= td.GHUNNAH_DROPPED_MAX or abs(p_n - e_n) > td.GHUNNAH_COUNT_TOLERANCE else None
    if kind == td.SHADDAH and p_n < e_n:
        return "length:shaddah"
    return None


def analyse_clip(svc, item: dict, tokens, times) -> tuple[list[dict], list[dict]]:
    """Per-word verdicts and per-opportunity (madd / ghunnah / ikhfa) records."""
    results, prefix, pred_chars, tok_idx = score(svc, tokens, times, item["surah"], item["ayah"])
    pred_str = "".join(pred_chars)
    cvm = cv_median(tokens, times)
    n = len(results)
    words, opps = [], []
    cursor = 0
    for wi, r in enumerate(results):
        a = None
        if r.recited and r.predicted_phonemes:
            f = pred_str.find(r.predicted_phonemes, cursor)
            if f >= 0:
                a, cursor = f, f + len(r.predicted_phonemes)
        words.append({"clip": item["clip"], "i": wi, "n": n, "in_prefix": wi < prefix,
                      "word": r.display_word, "exp": r.expected_phonemes, "pred": r.predicted_phonemes,
                      "recited": r.recited, "correct": r.correct, "type": r.error_type})
        if not r.expected_phonemes or not r.recited:
            continue
        e_runs = td.runs(r.expected_phonemes)
        p_runs = td.runs(r.predicted_phonemes)
        pairs = td.align(p_runs, e_runs)[1] if p_runs else [(None, j) for j in range(len(e_runs))]
        e_off, p_off, o = [], [], 0
        for _ch, k in e_runs:
            e_off.append(o)
            o += k
        o = 0
        for _ch, k in p_runs:
            p_off.append(o)
            o += k
        for pi, ei in pairs:
            if ei is None:
                continue
            e_ch, e_n = e_runs[ei]
            kind = td._kind(e_ch, e_n)
            if kind not in (td.MADD, td.GHUNNAH, "ikhfa"):
                continue
            rec = {"clip": item["clip"], "word_i": wi, "n_words": n, "in_prefix": wi < prefix,
                   "word": r.display_word, "exp": r.expected_phonemes, "pred": r.predicted_phonemes,
                   "word_type": r.error_type, "kind": kind, "e_ch": e_ch, "e_n": e_n, "e_off": e_off[ei],
                   "p_ch": None, "p_n": 0, "cv_med": cvm,
                   "finding": run_finding(kind, e_ch, e_n, p_runs[pi] if pi is not None else None)}
            if kind == td.MADD:
                ctx = madd_context(r.expected_phonemes, e_off[ei], e_n, wi == n - 1)
                if ctx == "word-final" and wi + 1 < n and results[wi + 1].expected_phonemes.startswith("ء"):
                    ctx = "munfasil"
                rec["context"] = ctx
            if pi is not None:
                rec["p_ch"], rec["p_n"] = p_runs[pi]
                if a is not None:
                    g = a + p_off[pi]
                    k0, k1 = tok_idx[g], tok_idx[g + p_runs[pi][1] - 1]
                    rec["t_run"] = times[k0]
                    rec["t_prev"] = times[k0 - 1] if k0 > 0 else None
                    rec["t_next"] = times[k1 + 1] if k1 + 1 < len(times) else None
            opps.append(rec)
    return words, opps


def syllable_len(o: dict) -> float | None:
    """(next unit's timestamp - previous unit's timestamp) / recording tempo."""
    if o.get("t_prev") is None or o.get("t_next") is None or not o.get("cv_med"):
        return None
    return (o["t_next"] - o["t_prev"]) / o["cv_med"]


# ── controlled edits ──────────────────────────────────────────────────────────

XFADE = int(0.015 * SR)


def xfade_join(a: np.ndarray, b: np.ndarray) -> np.ndarray:
    if len(a) < XFADE or len(b) < XFADE:
        return np.concatenate([a, b])
    w = np.linspace(0, 1, XFADE, dtype=np.float32)
    return np.concatenate([a[:-XFADE], a[-XFADE:] * (1 - w) + b[:XFADE] * w, b[XFADE:]])


def apply_edit(y: np.ndarray, r0: int, r1: int, new_len: int) -> np.ndarray:
    """Make [r0, r1) last new_len samples: cut its middle, loop its middle, or
    (new_len == r1 - r0) cut and re-join it unchanged -- the control."""
    cur = r1 - r0
    if new_len == cur:
        m = (r0 + r1) // 2
        return xfade_join(y[:m], y[m:])
    if new_len < cur:
        cut = cur - new_len
        m = r0 + (cur - cut) // 2
        return xfade_join(y[:m], y[m + cut:])
    ch = int(0.08 * SR)
    m = r0 + cur // 2 - ch // 2
    chunk, out, add = y[m:m + ch], y[:m + ch], new_len - cur
    while add > 0:
        out = xfade_join(out, chunk)
        add -= ch - XFADE
    return xfade_join(out, y[m + ch:])


def judge_edit(svc, edit: dict) -> dict:
    """Production verdict on the edited audio, for the edited run."""
    y = apply_edit(load_audio(edit["path"]), edit["r0"], edit["r1"], edit["new_len"])
    tokens, times = decode(svc, y)
    item = {"clip": edit["clip"], "surah": edit["surah"], "ayah": edit["ayah"]}
    words, opps = analyse_clip(svc, item, tokens, times)
    w = words[edit["word_i"]]
    target = next((o for o in opps if o["word_i"] == edit["word_i"] and o["e_off"] == edit["e_off"]), None)
    return {"id": edit["id"], "cond": edit["cond"], "word_type": w["type"] if w["recited"] else "not-recited",
            "word_correct": w["correct"] and w["recited"],
            "emitted": [target["p_ch"], target["p_n"]] if target else None,
            "finding": target["finding"] if target else None,
            "syllable_len_after": syllable_len(target) if target else None,
            "other_words_flagged": sum(1 for x in words if x["i"] != edit["word_i"] and x["recited"] and not x["correct"])}


# ── versions ──────────────────────────────────────────────────────────────────

def git_head() -> str:
    import subprocess
    return subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=REPO, capture_output=True,
                          text=True).stdout.strip()


def git_dirty_backend() -> bool:
    import subprocess
    out = subprocess.run(["git", "status", "--porcelain", "backend/app"], cwd=REPO, capture_output=True,
                         text=True).stdout.strip()
    return bool(out)


def jsonl_write(path: Path, rows) -> None:
    with open(path, "w", encoding="utf-8") as f:
        for r in rows:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")


def jsonl_read(path: Path) -> list[dict]:
    return [json.loads(l) for l in open(path, encoding="utf-8")]


class Timer:
    def __init__(self):
        self.decode = 0.0
        self.score = 0.0
        self.audio = 0.0

    def run(self, fn, *a):
        t = time.perf_counter()
        out = fn(*a)
        return out, time.perf_counter() - t
