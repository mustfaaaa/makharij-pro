"""Does the live highlight run ahead of the voice?

The report
----------
"When recording, sometimes it blacks out the line ahead -- one the user hasn't
recited yet. The result screen doesn't do this any more." The result screen was
fixed separately (see measure_recited_spill.py); this measures the *other* code
path, the live cursor in PhonemeAnalysisService.live_advance.

Why the live path can run ahead
-------------------------------
`live_advance` advances over the contiguous run of words whose match clears
`_heard_flags`, i.e. HEARD_MATCH_RATIO = 0.5. That bar is meant for words in
the *interior* of a finished recitation, where a weak match means the reciter
said the word badly and the cursor should move past it anyway.

At the live frontier it means something else. The word the cursor is about to
claim is, by construction, still being spoken -- only part of its audio has
arrived, so only part of its phonemes match, so a half-spoken word clears a
50% bar and the highlight steps onto a word nobody has said yet. At an ayah
boundary that shows up as a whole line lighting up early.

The measurement
---------------
Reference recitations are per-ayah files, so concatenating them gives audio
whose true position is known exactly at every instant: at elapsed time t the
reciter is provably inside a known ayah. Feed that through the same loop
routers/live.py runs -- same recognizer, same chunking, same cursor
bookkeeping -- and compare each progress update against the truth.

An update is an OVERRUN when it reports an ayah later than the one actually
sounding. Decoding latency works against false positives here: the cursor
naturally lags the audio, so anything that arrives early is real.

Run from the repo root:
    backend/.venv/Scripts/python.exe ml/eval/crossmodel/measure_live_overrun.py
"""
from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from pathlib import Path

import librosa
import numpy as np

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "backend"))

from app.phoneme_analysis_service import PhonemeAnalysisService  # noqa: E402
from app.quran_metadata import SURAH_AYAH_COUNTS  # noqa: E402

RECITATIONS = REPO / "backend" / "app" / "static" / "recitations"
OUT = Path(__file__).resolve().parent / "live_overrun_report.json"
SAMPLE_RATE = 16000
GAP_SEC = 0.35

# Mirrors routers/live.py.
MIN_SECONDS_BETWEEN_UPDATES = 0.35
CHUNK_SEC = 0.1


def _true_ayah(elapsed: float, spans: list[tuple[int, float, float]]) -> int:
    """Which ayah is sounding at `elapsed` -- or the last one that finished."""
    current = spans[0][0]
    for ayah, start, end in spans:
        if elapsed >= start:
            current = ayah
        if start <= elapsed < end:
            return ayah
    return current


def run_one(service, surah: int, clips: dict[int, np.ndarray], from_ayah: int = 1):
    """Stream one whole-surah recitation, returning every progress update."""
    gap = np.zeros(int(GAP_SEC * SAMPLE_RATE), dtype=np.float32)
    pieces, spans, cursor_sec = [], [], 0.0
    for ayah in sorted(clips):
        dur = len(clips[ayah]) / SAMPLE_RATE
        spans.append((ayah, cursor_sec, cursor_sec + dur))
        pieces.append(clips[ayah])
        pieces.append(gap)
        cursor_sec += dur + GAP_SEC
    audio = np.concatenate(pieces[:-1])

    stream = service.recognizer.create_stream()
    samples_seen = 0
    next_update_at = 0.0
    last_token_count = 0
    word_cursor = 0
    chars_consumed = 0
    updates = []

    step_samples = int(CHUNK_SEC * SAMPLE_RATE)
    for start in range(0, len(audio), step_samples):
        chunk = audio[start:start + step_samples]
        if chunk.size == 0:
            continue
        samples_seen += chunk.size
        stream.accept_waveform(SAMPLE_RATE, chunk.astype(np.float32))
        while service.recognizer.is_ready(stream):
            service.recognizer.decode_stream(stream)

        elapsed = samples_seen / SAMPLE_RATE
        if elapsed < next_update_at:
            continue
        next_update_at = elapsed + MIN_SECONDS_BETWEEN_UPDATES

        tokens = service.recognizer.tokens(stream)
        if len(tokens) == last_token_count:
            continue
        last_token_count = len(tokens)

        pred_chars = [c for t in tokens for c in t]
        step = service.live_advance(
            pred_chars[chars_consumed:], surah, word_cursor, from_ayah)
        if step is None:
            continue
        ayah, word_index, global_index, consumed = step
        chars_consumed += consumed
        word_cursor = global_index + 1

        updates.append({
            "elapsed": round(elapsed, 2),
            "reported_ayah": ayah,
            "word_index": word_index,
            "true_ayah": _true_ayah(elapsed, spans),
            "global_index": global_index,
        })
    return updates


def main() -> int:
    parser = argparse.ArgumentParser()
    # Swept from here rather than by editing the service, so production keeps
    # one honest default. ratio 0.0 / min-chars 0 makes every heard word a
    # valid frontier, which is exactly the behaviour before the bar existed.
    parser.add_argument("--frontier-ratio", type=float, default=None)
    parser.add_argument("--frontier-min-chars", type=int, default=None)
    parser.add_argument("--out", type=Path, default=OUT)
    args = parser.parse_args()

    import app.phoneme_analysis_service as pas
    if args.frontier_ratio is not None:
        pas.LIVE_FRONTIER_RATIO = args.frontier_ratio
    if args.frontier_min_chars is not None:
        pas.LIVE_FRONTIER_MIN_CHARS = args.frontier_min_chars
    print(f"frontier bar: ratio={pas.LIVE_FRONTIER_RATIO} "
          f"min_chars={pas.LIVE_FRONTIER_MIN_CHARS}")

    print("loading the phoneme model...")
    service = PhonemeAnalysisService()

    qaris = sorted(p.name for p in RECITATIONS.iterdir() if p.is_dir())

    recitations = 0
    recitations_with_overrun = 0
    # The control. Holding the frontier back trades over-highlighting for
    # under-highlighting, so this has to watch both: a cursor that never runs
    # ahead because it barely moves is not a fix. Coverage is how far through
    # the surah's words the highlight actually got by the end.
    coverage_ratios = []
    total_updates = 0
    overrun_updates = 0
    overrun_by_ayahs = Counter()
    per_surah: dict[str, dict] = {}
    examples: list[dict] = []

    for qari in qaris:
        for surah, ayah_count in sorted(SURAH_AYAH_COUNTS.items()):
            if ayah_count < 2:
                continue
            clips = {}
            for ayah in range(1, ayah_count + 1):
                mp3 = RECITATIONS / qari / f"{surah:03d}{ayah:03d}.mp3"
                if mp3.is_file():
                    clips[ayah], _ = librosa.load(
                        str(mp3), sr=SAMPLE_RATE, mono=True)
            if len(clips) != ayah_count:
                continue

            try:
                updates = run_one(service, surah, clips)
            except Exception:
                continue

            recitations += 1
            total_words = len(service._range_words(
                surah, 1, service.ayah_count(surah)))
            reached = (max(u["global_index"] for u in updates) + 1) if updates else 0
            coverage_ratios.append(reached / max(total_words, 1))
            key = f"S{surah}"
            bucket = per_surah.setdefault(
                key, {"recitations": 0, "updates": 0, "overruns": 0})
            bucket["recitations"] += 1
            bucket["updates"] += len(updates)
            total_updates += len(updates)

            ahead = [u for u in updates if u["reported_ayah"] > u["true_ayah"]]
            if ahead:
                recitations_with_overrun += 1
                overrun_updates += len(ahead)
                bucket["overruns"] += len(ahead)
                for u in ahead:
                    overrun_by_ayahs[u["reported_ayah"] - u["true_ayah"]] += 1
                if len(examples) < 12:
                    worst = max(ahead, key=lambda u: u["reported_ayah"] - u["true_ayah"])
                    examples.append({
                        "qari": qari, "surah": surah,
                        "at_second": worst["elapsed"],
                        "reciter_was_on_ayah": worst["true_ayah"],
                        "highlight_jumped_to_ayah": worst["reported_ayah"],
                        "updates_ahead_in_this_recitation": len(ahead),
                    })
        print(f"  {qari}: {recitations} recitations, "
              f"{recitations_with_overrun} with the highlight ahead")

    mean_coverage = (sum(coverage_ratios) / len(coverage_ratios)) if coverage_ratios else 0.0
    poor = sum(1 for c in coverage_ratios if c < 0.9)
    pct_updates = (100.0 * overrun_updates / total_updates) if total_updates else 0.0
    pct_recs = (100.0 * recitations_with_overrun / recitations) if recitations else 0.0
    summary = {
        "what": "live cursor reporting an ayah later than the one being recited",
        "audio": "reference Qari recitations streamed through the live loop",
        "recitations": recitations,
        "recitations_with_overrun": recitations_with_overrun,
        "recitations_with_overrun_pct": round(pct_recs, 1),
        "progress_updates": total_updates,
        "overrun_updates": overrun_updates,
        "overrun_updates_pct": round(pct_updates, 1),
        "how_far_ahead_in_ayahs": dict(sorted(overrun_by_ayahs.items())),
        "per_surah": per_surah,
        "examples": examples,
        "control_coverage": {
            "mean_share_of_surah_highlighted": round(mean_coverage, 3),
            "recitations_below_90pct": poor,
            "recitations": len(coverage_ratios),
            "note": "whole surah recited, so the cursor should reach the last "
                    "word; anything short is the cost of holding the frontier",
        },
        "thresholds_in_force": {
            "HEARD_MATCH_RATIO": 0.5,
            "LIVE_LOOKAHEAD_WORDS": pas.LIVE_LOOKAHEAD_WORDS,
            "LIVE_FRONTIER_RATIO": pas.LIVE_FRONTIER_RATIO,
            "LIVE_FRONTIER_MIN_CHARS": pas.LIVE_FRONTIER_MIN_CHARS,
        },
    }
    args.out.write_text(
        json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")

    print()
    print("=" * 64)
    print("LIVE OVERRUN: highlight ahead of the voice")
    print("=" * 64)
    print(f"  recitations streamed      : {recitations}")
    print(f"  with the highlight ahead  : {recitations_with_overrun}  ({pct_recs:.1f}%)")
    print(f"  progress updates          : {total_updates}")
    print(f"  updates ahead of the voice: {overrun_updates}  ({pct_updates:.1f}%)")
    if overrun_by_ayahs:
        print(f"  how far ahead             : "
              f"{dict(sorted(overrun_by_ayahs.items()))} (ayahs -> count)")
    print()
    worst = sorted(per_surah.items(),
                   key=lambda kv: -(kv[1]["overruns"] / max(kv[1]["updates"], 1)))[:6]
    print("  worst surahs (share of updates ahead):")
    for name, v in worst:
        share = 100.0 * v["overruns"] / max(v["updates"], 1)
        print(f"    {name:6} {share:5.1f}%   ({v['overruns']}/{v['updates']} updates)")
    print()
    print(f"  CONTROL mean surah highlighted : {100 * mean_coverage:.1f}%")
    print(f"  CONTROL recitations below 90%  : {poor}/{len(coverage_ratios)}")
    print(f"\n  written to {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
