"""Does the model's own acoustic confidence separate a false alarm from a real
mistake?

Why this exists
---------------
On professional Qari recordings the detector wrongly flags 1.0% of words. On
773 labelled recordings of ordinary learners it flags 42.8% of *correctly
recited* clips. Same pipeline, same thresholds, same canonical reference -- the
only thing that changed is the audio. So the decision line is not the problem
(threshold calibration was already fitted against this same data and did not
improve on the shipped setting); the problem is that the decision is taken on
evidence that cannot tell "the reciter said something different" from "the
recogniser was unsure".

The upstream authors say so themselves, in
models_cache/quran-lab-zipformer/decode_with_confidence.py:

    "Greedy CTC throws away almost everything the model knows: it keeps the
     argmax and discards the full 251-way posterior. [...] 'the model was
     unsure' and 'the reciter said something different' look identical in a
     plain transcript. With confidence you can treat low-confidence positions
     as neutral and only flag a mistake when the model is confident AND
     disagrees."

The pipeline currently discards that posterior: sherpa-onnx's `ys_probs` is
empty for CTC, and the `confidence` a word verdict carries today is
`1 - edit_distance/len(expected)` -- a rescaled edit distance with no acoustic
content whatsoever.

What this measures
------------------
For every labelled clip: run the real pipeline to get its word verdicts, and
independently recover the 251-way posterior from the same ONNX weights. For
each *flagged* word, take the model's mean acoustic confidence over the frames
that word occupies. Then compare two populations:

    false alarm     clip labelled `correct`,    yet some word was flagged
    true detection  clip labelled `in_correct`, and some word was flagged

If false alarms sit at systematically lower acoustic confidence, then holding
back low-confidence flags removes them while keeping the real ones -- and the
sweep at the end says exactly what that trade costs.

Run from the repo root:
    backend/.venv/Scripts/python.exe ml/eval/measure_confidence_separation.py
"""
from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path

import librosa
import numpy as np
import onnxruntime as ort
import torch
import torchaudio.compliance.kaldi as kaldi

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "backend"))

from app.phoneme_analysis_service import PhonemeAnalysisService  # noqa: E402

MODEL_DIR = REPO / "backend" / "models_cache" / "quran-lab-zipformer"
MODEL = MODEL_DIR / "zipformer_p_arabic_v3.1.int8.onnx"
EVALSET = REPO / "ml" / "data" / "quranic_audio_dataset" / "evalset"
OUT = Path(__file__).resolve().parent / "results" / "confidence_separation.json"

SAMPLE_RATE = 16000
TAIL_PAD_SEC = 1.5      # matches PhonemeAnalysisService._decode
FRAME_SEC = 0.04        # 10 ms fbank hop x 4 subsampling

# `<blank> 250` in tokens.txt. NOT 0 -- id 0 is a real token in this inventory,
# so the usual blank=0 assumption emits blanks and drops a genuine symbol.
BLANK_ID = 250

# Frames of slack on each side of a word before forced alignment. See ctc_gop.
SPAN_PAD_FRAMES = 2


def features(y: np.ndarray) -> np.ndarray:
    """Kaldi fbank with sherpa-onnx's settings, not Kaldi's defaults.

    high_freq is the trap: Kaldi defaults to 0 (Nyquist), sherpa-onnx uses -400
    (Nyquist - 400 Hz). The resulting mel bank is different enough to change the
    decode outright.
    """
    wav = torch.from_numpy(y).float().unsqueeze(0) * 32768.0
    fb = kaldi.fbank(
        wav,
        num_mel_bins=80,
        frame_length=25.0,
        frame_shift=10.0,
        dither=0.0,
        energy_floor=0.0,
        sample_frequency=SAMPLE_RATE,
        snip_edges=False,
        window_type="povey",
        low_freq=20.0,
        high_freq=-400.0,
    )
    return fb.numpy().astype(np.float32)


class Posterior:
    """The 251-way log-posterior the shipped weights expose but the app drops."""

    def __init__(self, model_path: Path = MODEL):
        self.sess = ort.InferenceSession(str(model_path), providers=["CPUExecutionProvider"])
        meta = self.sess.get_modelmeta().custom_metadata_map
        self.T = int(meta["T"])                     # frames fed per chunk
        self.chunk = int(meta["decode_chunk_len"])  # frames advanced per chunk
        self.inputs = self.sess.get_inputs()
        self.output_names = [o.name for o in self.sess.get_outputs()]

    def _zero_states(self) -> dict[str, np.ndarray]:
        states = {}
        for spec in self.inputs:
            if spec.name == "x":
                continue
            shape = [1 if isinstance(d, str) else d for d in spec.shape]
            dtype = np.int64 if "int64" in spec.type else np.float32
            states[spec.name] = np.zeros(shape, dtype=dtype)
        return states

    def log_probs(self, y: np.ndarray) -> np.ndarray:
        feats = features(y)
        # Pad the tail so the final partial chunk is still decoded; without this
        # up to T-1 frames of the recording are simply never seen.
        short = (len(feats) - self.T) % self.chunk
        if len(feats) < self.T:
            feats = np.pad(feats, ((0, self.T - len(feats)), (0, 0)))
        elif short:
            feats = np.pad(feats, ((0, self.chunk - short), (0, 0)))

        states = self._zero_states()
        out, pos = [], 0
        while pos + self.T <= len(feats):
            named = dict(zip(
                self.output_names,
                self.sess.run(self.output_names, {"x": feats[pos:pos + self.T][None], **states}),
            ))
            out.append(named["log_probs"][0])
            for name in list(states):
                states[name] = named["new_" + name]
            pos += self.chunk
        return np.concatenate(out, axis=0) if out else np.zeros((0, 251), np.float32)


def load_units() -> list[tuple[str, int]]:
    """Token inventory, longest first, for greedy longest-match tokenisation.

    The model's units are multi-character (`ننننَ`, `اااا`), so an expected
    phoneme *string* has to be segmented into them before it can be scored.
    """
    units = []
    for line in (MODEL_DIR / "tokens.txt").read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        sym, idx = line.rsplit(" ", 1)
        if sym != "<blank>":
            units.append((sym, int(idx)))
    return sorted(units, key=lambda su: -len(su[0]))


def tokenise(expected: str, units: list[tuple[str, int]]) -> list[int]:
    ids, i = [], 0
    while i < len(expected):
        for sym, idx in units:
            if expected.startswith(sym, i):
                ids.append(idx)
                i += len(sym)
                break
        else:
            i += 1  # a character the inventory has no unit for
    return ids


def goodness_of_pronunciation(lp: np.ndarray, expected_ids: list[int],
                              start_sec: float, end_sec: float) -> float | None:
    """How much evidence for the *expected* phonemes is actually in the audio.

    This is the question the chosen-unit confidence cannot answer. If the
    reciter said the word correctly but the recogniser picked something else,
    the expected units should still carry real probability mass here. If the
    word was genuinely mispronounced, they should not.
    """
    if lp.shape[0] == 0 or not expected_ids:
        return None
    a = max(int(start_sec / FRAME_SEC), 0)
    b = min(int(round(end_sec / FRAME_SEC)) + 1, lp.shape[0])
    if b <= a:
        b = min(a + 1, lp.shape[0])
    if b <= a:
        return None
    window = np.exp(lp[a:b])                       # frames x 251
    # Best frame for each expected unit anywhere in the word, averaged.
    return float(np.mean([window[:, u].max() for u in expected_ids]))


def _span(lp: np.ndarray, start_sec: float, end_sec: float) -> np.ndarray | None:
    if lp.shape[0] == 0:
        return None
    a = max(int(start_sec / FRAME_SEC), 0)
    b = min(int(round(end_sec / FRAME_SEC)) + 1, lp.shape[0])
    if b <= a:
        b = min(a + 1, lp.shape[0])
    return lp[a:b] if b > a else None


def ctc_forward_logprob(lp: np.ndarray, ids: list[int], blank: int = BLANK_ID) -> float:
    """log P(ids | audio) by the CTC forward algorithm, in log space.

    Unlike the crude score above this respects *order*, and it accounts for the
    blanks and repeated frames a real CTC path has to spend. A unit that shows
    up strongly but in the wrong place no longer counts as evidence.
    """
    T = lp.shape[0]
    ext = [blank]
    for i in ids:
        ext += [i, blank]
    ext_arr = np.asarray(ext)
    S = len(ext)
    NEG = -1e30

    alpha = np.full(S, NEG)
    alpha[0] = lp[0, ext[0]]
    if S > 1:
        alpha[1] = lp[0, ext[1]]

    # A path may skip a blank only between two *different* real units.
    can_skip = np.zeros(S, dtype=bool)
    if S > 2:
        idx = np.arange(2, S)
        can_skip[2:] = (ext_arr[2:] != blank) & (ext_arr[2:] != ext_arr[:-2])

    for t in range(1, T):
        prev = alpha
        stay = prev
        step = np.concatenate(([NEG], prev[:-1]))
        skip = np.where(can_skip, np.concatenate(([NEG, NEG], prev[:-2])), NEG)
        alpha = np.logaddexp(np.logaddexp(stay, step), skip) + lp[t, ext_arr]

    return float(np.logaddexp(alpha[S - 1], alpha[S - 2]) if S > 1 else alpha[0])


def ctc_gop(lp: np.ndarray, expected_ids: list[int],
            start_sec: float, end_sec: float) -> float | None:
    """The classic GOP, done properly: how much worse is the expected sequence
    than the best explanation the model can find for the same audio?

    Near 0  -> the expected phonemes explain the audio about as well as anything
               else, so the reciter said it and the recogniser merely wandered.
    Very negative -> the audio genuinely does not contain the expected sequence.

    Length-normalised so long and short words are comparable.
    """
    # Widen the span slightly before aligning. The word's frame boundaries come
    # from sherpa's timestamps for *its own* decode -- and a flagged word is by
    # definition one where that decode disagreed with the text, so the boundary
    # marks where the wrong tokens were, not where the expected word sits.
    # Forced alignment has to fit the whole expected sequence inside the span in
    # order, so it collapses on a boundary that is merely a little off, whether
    # or not the reciter was correct. Measured over 60 clips, separation between
    # false alarms and real mistakes: 0.06 at no padding, 0.38 at 2 frames,
    # 0.25 at 4, and -0.01 at 8, where the window is wide enough to swallow the
    # neighbouring words and the signal disappears.
    pad = SPAN_PAD_FRAMES * FRAME_SEC
    window = _span(lp, max(start_sec - pad, 0.0), end_sec + pad)
    if window is None or not expected_ids:
        return None
    # A CTC path needs one frame per unit *plus* a blank between any two
    # identical neighbours. Fewer frames than that and the sequence cannot be
    # realised at all: the forward score stays at the -1e30 sentinel and, once
    # divided by the frame count, poisons any mean it is averaged into.
    min_frames = len(expected_ids) + sum(
        1 for a, b in zip(expected_ids, expected_ids[1:]) if a == b)
    if window.shape[0] < min_frames:
        return None

    forced = ctc_forward_logprob(window, expected_ids)
    if not np.isfinite(forced) or forced < -1e9:
        return None  # infeasible alignment, not a very bad one

    free = float(window.max(axis=1).sum())   # best unconstrained path
    return (forced - free) / window.shape[0]


def word_confidence(lp: np.ndarray, start_sec: float, end_sec: float) -> float | None:
    """Mean probability of whatever the model chose, over a word's own frames.

    Deliberately the chosen unit's probability rather than the expected unit's:
    this asks "was the model sure of what it heard", which is the question that
    separates a misrecognition from a mispronunciation.
    """
    if lp.shape[0] == 0:
        return None
    a = max(int(start_sec / FRAME_SEC), 0)
    b = min(int(round(end_sec / FRAME_SEC)) + 1, lp.shape[0])
    if b <= a:
        b = min(a + 1, lp.shape[0])
    if b <= a:
        return None
    window = lp[a:b]
    return float(np.exp(window.max(axis=1)).mean())


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--limit", type=int, default=None)
    parser.add_argument("--evalset", type=Path, default=EVALSET)
    parser.add_argument("--out", type=Path, default=OUT)
    args = parser.parse_args()

    manifest = args.evalset / "manifest.csv"
    if not manifest.exists():
        print(f"No manifest at {manifest} -- run ml/eval/build_manifest.py first")
        return 1
    with open(manifest, encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    if args.limit:
        rows = rows[:args.limit]

    print(f"loading the model ({len(rows)} clips)...")
    service = PhonemeAnalysisService()
    posterior = Posterior()
    units = load_units()

    records = []
    for i, row in enumerate(rows, 1):
        path = args.evalset / row["file"]
        try:
            audio = path.read_bytes()
            verdicts = service.analyze_range(audio, int(row["surah"]), int(row["ayah"]),
                                             int(row["ayah"]))
            y, _ = librosa.load(str(path), sr=SAMPLE_RATE, mono=True)
            padded = np.concatenate(
                [y, np.zeros(int(TAIL_PAD_SEC * SAMPLE_RATE), dtype=np.float32)])
            lp = posterior.log_probs(padded)
        except Exception as exc:
            records.append({"clip_id": row["clip_id"], "error": str(exc)})
            continue

        flagged, clean, flagged_gop, flagged_ctc = [], [], [], []
        for v in verdicts:
            if not v.recited:
                continue
            conf = word_confidence(lp, v.start_sec, v.end_sec)
            if conf is None:
                continue
            if v.correct:
                clean.append(conf)
            else:
                flagged.append(conf)
                ids = tokenise(v.expected_phonemes, units)
                gop = goodness_of_pronunciation(lp, ids, v.start_sec, v.end_sec)
                if gop is not None:
                    flagged_gop.append(gop)
                cg = ctc_gop(lp, ids, v.start_sec, v.end_sec)
                if cg is not None:
                    flagged_ctc.append(cg)

        records.append({
            "clip_id": row["clip_id"],
            # Carried so a held-out split can be made speaker-disjoint: every
            # real user is an unseen voice, so a threshold that only works on
            # reciters it was fitted to is worth nothing.
            "reciter_id": row.get("reciter_id", ""),
            "recited_correctly": int(row["recited_correctly"]),
            "flagged": bool(flagged),
            "flagged_confs": flagged,
            "flagged_gop": flagged_gop,
            "flagged_ctc_gop": flagged_ctc,
            "clean_confs": clean,
            # The weakest flag is what a suppression rule would act on first.
            "min_flag_conf": min(flagged) if flagged else None,
        })
        if i % 25 == 0 or i == len(rows):
            print(f"  {i}/{len(rows)}")

    ok = [r for r in records if "error" not in r]
    false_alarm = [r for r in ok if r["recited_correctly"] == 1 and r["flagged"]]
    true_detect = [r for r in ok if r["recited_correctly"] == 0 and r["flagged"]]
    correct_clips = [r for r in ok if r["recited_correctly"] == 1]
    incorrect_clips = [r for r in ok if r["recited_correctly"] == 0]

    fa_conf = [c for r in false_alarm for c in r["flagged_confs"]]
    td_conf = [c for r in true_detect for c in r["flagged_confs"]]
    fa_gop = [g for r in false_alarm for g in r["flagged_gop"]]
    td_gop = [g for r in true_detect for g in r["flagged_gop"]]
    fa_ctc = [g for r in false_alarm for g in r["flagged_ctc_gop"]]
    td_ctc = [g for r in true_detect for g in r["flagged_ctc_gop"]]
    mean = lambda v: round(float(np.mean(v)), 4) if v else None  # noqa: E731

    # What suppressing low-confidence flags would actually cost. A clip counts
    # as flagged only if at least one of its flags survives the bar.
    sweep = []
    for th in [0.0, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9]:
        fa = sum(1 for r in correct_clips if any(c >= th for c in r["flagged_confs"]))
        td = sum(1 for r in incorrect_clips if any(c >= th for c in r["flagged_confs"]))
        # The GOP rule is the opposite direction: keep a flag only when the
        # expected phonemes are NOT well supported by the audio.
        fa_g = sum(1 for r in correct_clips if any(g <= th for g in r["flagged_gop"]))
        td_g = sum(1 for r in incorrect_clips if any(g <= th for g in r["flagged_gop"]))
        sweep.append({
            "threshold": th,
            "by_chosen_confidence": {
                "false_alarm_rate_pct": round(100 * fa / max(len(correct_clips), 1), 1),
                "true_detection_rate_pct": round(100 * td / max(len(incorrect_clips), 1), 1),
            },
            "by_gop": {
                "false_alarm_rate_pct": round(100 * fa_g / max(len(correct_clips), 1), 1),
                "true_detection_rate_pct": round(100 * td_g / max(len(incorrect_clips), 1), 1),
            },
        })

    ctc_sweep = []
    for th in [-0.05, -0.1, -0.2, -0.3, -0.5, -0.75, -1.0, -1.5, -2.0]:
        # Keep a flag only when the expected sequence explains the audio *worse*
        # than this -- i.e. the phonemes really are not there.
        fa_c = sum(1 for r in correct_clips if any(g <= th for g in r["flagged_ctc_gop"]))
        td_c = sum(1 for r in incorrect_clips if any(g <= th for g in r["flagged_ctc_gop"]))
        ctc_sweep.append({
            "max_ctc_gop_to_keep_flag": th,
            "false_alarm_rate_pct": round(100 * fa_c / max(len(correct_clips), 1), 1),
            "true_detection_rate_pct": round(100 * td_c / max(len(incorrect_clips), 1), 1),
        })

    summary = {
        "what": "does the model's acoustic confidence separate false alarms from real mistakes",
        "clips_scored": len(ok),
        "correct_clips": len(correct_clips),
        "incorrect_clips": len(incorrect_clips),
        "flagged_word_confidence": {
            "on_correctly_recited_clips (false alarms)": {
                "words": len(fa_conf), "mean": mean(fa_conf)},
            "on_incorrectly_recited_clips (true detections)": {
                "words": len(td_conf), "mean": mean(td_conf)},
        },
        "gop_at_flagged_words": {
            "on_correctly_recited_clips (false alarms)": {
                "words": len(fa_gop), "mean": mean(fa_gop)},
            "on_incorrectly_recited_clips (true detections)": {
                "words": len(td_gop), "mean": mean(td_gop)},
        },
        "ctc_gop_at_flagged_words": {
            "on_correctly_recited_clips (false alarms)": {
                "words": len(fa_ctc), "mean": mean(fa_ctc)},
            "on_incorrectly_recited_clips (true detections)": {
                "words": len(td_ctc), "mean": mean(td_ctc)},
        },
        "suppression_sweep": sweep,
        "ctc_forced_alignment_sweep": ctc_sweep,
        "note": "confidence is the model's own posterior for the unit it chose, "
                "recovered from log_probs; the pipeline's existing `confidence` "
                "field is a rescaled edit distance and carries no acoustic information",
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")

    # Per-clip records, so threshold selection can be re-run on any split
    # without paying for the decode again.
    records_path = args.out.with_name("confidence_records.jsonl")
    with open(records_path, "w", encoding="utf-8") as fh:
        for r in ok:
            fh.write(json.dumps(r, ensure_ascii=False) + "\n")
    print(f"  per-clip records -> {records_path}")

    print()
    print("=" * 66)
    print("ACOUSTIC CONFIDENCE AT FLAGGED WORDS")
    print("=" * 66)
    print(f"  clips scored                     : {len(ok)}")
    print(f"  flagged words on CORRECT clips   : {len(fa_conf):5}  mean conf {mean(fa_conf)}")
    print(f"  flagged words on INCORRECT clips : {len(td_conf):5}  mean conf {mean(td_conf)}")
    print(f"  GOP at flagged words, CORRECT clips   : mean {mean(fa_gop)}  ({len(fa_gop)} words)")
    print(f"  GOP at flagged words, INCORRECT clips : mean {mean(td_gop)}  ({len(td_gop)} words)")
    print()
    print("  two candidate rules for holding a flag back:")
    print(f"  {'thresh':>7} | {'chosen-confidence rule':>27} | {'GOP rule':>27}")
    print(f"  {'':>7} | {'false alarm':>13}{'caught':>14} | {'false alarm':>13}{'caught':>14}")
    for s_ in sweep:
        c, g = s_["by_chosen_confidence"], s_["by_gop"]
        print(f"  {s_['threshold']:>7} | {c['false_alarm_rate_pct']:>12}%"
              f"{c['true_detection_rate_pct']:>13}% | {g['false_alarm_rate_pct']:>12}%"
              f"{g['true_detection_rate_pct']:>13}%")
    print()
    print(f"  CTC-GOP at flagged words, CORRECT clips   : mean {mean(fa_ctc)}  ({len(fa_ctc)} words)")
    print(f"  CTC-GOP at flagged words, INCORRECT clips : mean {mean(td_ctc)}  ({len(td_ctc)} words)")
    print()
    print("  proper CTC forced-alignment rule (keep a flag only when the")
    print("  expected sequence explains the audio worse than the bar):")
    print(f"  {'keep flag if <=':>16}  {'false alarm':>12}  {'caught':>10}")
    for c_ in ctc_sweep:
        print(f"  {c_['max_ctc_gop_to_keep_flag']:>16}  "
              f"{c_['false_alarm_rate_pct']:>11}%  {c_['true_detection_rate_pct']:>9}%")
    print(f"\n  written to {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
