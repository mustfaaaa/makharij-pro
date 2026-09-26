"""Two questions about live feedback, both answerable from reference audio.

1. Is a word's verdict ready when its *audio* is complete?
---------------------------------------------------------
Feedback currently waits a fixed five words behind the cursor. That number was
measured, but it is a proxy for the thing that actually matters: has all of this
word's audio arrived yet? A fast reciter covers five words in a second and a
slow one takes ten, so a word count is the wrong unit -- and the analyser
already knows each word's end timestamp.

So: at the moment a word's verdict stops changing, how much audio had arrived
after that word ended? If there is a clean margin in seconds, it replaces the
word count with something adaptive and usually quicker.

2. How far behind the voice does the cursor actually sit?
---------------------------------------------------------
"The cursor lags" is measurable. Reference recitations are per-ayah files, so
the true position at any instant is known; this records, for every update, how
far the reported word is from where the reciter really was.

Both are measured on professional recitation, where every word is correct, so
any verdict that is not "correct" is the analyser still making up its mind.

    backend/.venv/Scripts/python.exe ml/eval/crossmodel/measure_live_latency.py
"""
from __future__ import annotations

import argparse
import asyncio
import json
import statistics
import sys
from pathlib import Path

import librosa
import numpy as np

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "backend"))

from app.phoneme_analysis_service import PhonemeAnalysisService, SpanWords  # noqa: E402
from app.routers import live as L  # noqa: E402

RECITATIONS = REPO / "backend" / "app" / "static" / "recitations"
OUT = Path(__file__).resolve().parent / "live_latency.json"
SAMPLE_RATE = 16000
GAP_SEC = 0.35
CHUNK_SEC = 0.1


async def run_surah(service, qari: str, surah: int, ayah_count: int):
    gap = np.zeros(int(GAP_SEC * SAMPLE_RATE), dtype=np.float32)
    pieces, spans, cursor_sec = [], [], 0.0
    for ayah in range(1, ayah_count + 1):
        mp3 = RECITATIONS / qari / f"{surah:03d}{ayah:03d}.mp3"
        if not mp3.is_file():
            return None
        y, _ = librosa.load(str(mp3), sr=SAMPLE_RATE, mono=True)
        dur = len(y) / SAMPLE_RATE
        spans.append((ayah, cursor_sec, cursor_sec + dur))
        pieces += [y, gap]
        cursor_sec += dur + GAP_SEC
    audio = np.concatenate(pieces[:-1])

    # Word-level truth: where each word really is, from the complete recording.
    import io as _io
    import soundfile as sf
    buf = _io.BytesIO()
    sf.write(buf, audio, SAMPLE_RATE, format="WAV", subtype="PCM_16")
    final = service.analyze_range(buf.getvalue(), surah, 1, ayah_count)
    truth = {(r.ayah_number, r.word_index): (r.correct, r.end_sec)
             for r in final if r.recited}

    stream = service.recognizer.create_stream()
    buffered: list[np.ndarray] = []
    seen = 0
    next_at = 0.0
    last_tokens = 0
    word_cursor = 0
    chars_consumed = 0
    reported = -1
    firsts: dict[int, int] = {}
    busy = False

    cursor_lag: list[float] = []
    # (ayah, word) -> margin in seconds when the verdict first matched the truth
    settled_margin: dict[tuple[int, int], float] = {}
    wrong_at_margin: list[tuple[float, bool]] = []

    step = int(CHUNK_SEC * SAMPLE_RATE)
    for i in range(0, len(audio), step):
        chunk = audio[i:i + step]
        if chunk.size == 0:
            continue
        seen += chunk.size
        buffered.append(chunk)
        stream.accept_waveform(SAMPLE_RATE, chunk)
        while service.recognizer.is_ready(stream):
            service.recognizer.decode_stream(stream)

        elapsed = seen / SAMPLE_RATE
        if elapsed < next_at:
            continue
        next_at = elapsed + L.MIN_SECONDS_BETWEEN_UPDATES
        tokens = service.recognizer.tokens(stream)
        if len(tokens) == last_tokens:
            continue
        last_tokens = len(tokens)

        pred = [c for t in tokens for c in t]
        step_out = service.live_advance(pred[chars_consumed:], surah, word_cursor, 1)
        if step_out is None:
            continue
        ayah, word_index, global_index, consumed = step_out
        chars_consumed += consumed
        word_cursor = global_index + 1
        firsts.setdefault((surah, ayah), seen)

        # How far behind is the cursor? Compare where the reported word really
        # ended against how much audio the reciter has produced by now.
        end_of_reported = truth.get((ayah, word_index), (None, None))[1]
        if end_of_reported is not None:
            cursor_lag.append(elapsed - end_of_reported)

        # Run the analyser over everything so far and see which verdicts are
        # already right, and what audio margin each of those words had.
        if not busy:
            busy = True
            # Only words still inside the analysis window. Asking for older
            # ones measures the window's edge, not the verdict's readiness.
            # The socket keeps its recent audio with the absolute index of its
            # first sample; this harness keeps all of it, from sample 0.
            verdicts = await L._settled_word_verdicts(
                service, (np.concatenate(buffered), 0), SpanWords(service, surah, 1, surah, None),
                (surah, 1), (surah, ayah), max(0, global_index - 12), global_index, firsts)
            busy = False
            for msg in verdicts:
                for w in msg["words"]:
                    key = (msg["ayah"], w["word_index"])
                    if key not in truth:
                        continue
                    want_correct, word_end = truth[key]
                    margin = elapsed - word_end
                    agrees = (w["correct"] == want_correct)
                    wrong_at_margin.append((margin, agrees))
                    if agrees and key not in settled_margin:
                        settled_margin[key] = margin
                    elif not agrees:
                        settled_margin.pop(key, None)
        reported = global_index

    return cursor_lag, settled_margin, wrong_at_margin


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--surahs", type=int, nargs="*", default=[1, 103, 108, 110, 112])
    parser.add_argument("--out", type=Path, default=OUT)
    args = parser.parse_args()

    sys.path.insert(0, str(REPO / "backend"))
    from app.quran_metadata import SURAH_AYAH_COUNTS

    print("loading the phoneme model...")
    service = PhonemeAnalysisService()
    qaris = sorted(p.name for p in RECITATIONS.iterdir() if p.is_dir())

    all_lag: list[float] = []
    all_margin: list[float] = []
    agree_by_bucket: dict[str, list[bool]] = {}

    for qari in qaris:
        for surah in args.surahs:
            count = SURAH_AYAH_COUNTS.get(surah, 0)
            if count < 2:
                continue
            out = asyncio.run(run_surah(service, qari, surah, count))
            if out is None:
                continue
            lag, settled, at_margin = out
            all_lag += lag
            all_margin += list(settled.values())
            for margin, agrees in at_margin:
                bucket = ("<0.5s" if margin < 0.5 else
                          "0.5-1s" if margin < 1.0 else
                          "1-2s" if margin < 2.0 else
                          "2-3s" if margin < 3.0 else ">=3s")
                agree_by_bucket.setdefault(bucket, []).append(agrees)
        print(f"  {qari}: {len(all_lag)} cursor samples, {len(all_margin)} settled words")

    order = ["<0.5s", "0.5-1s", "1-2s", "2-3s", ">=3s"]
    by_margin = {
        b: {"verdicts": len(v), "agree_with_final_pct": round(100 * sum(v) / len(v), 1)}
        for b in order if (v := agree_by_bucket.get(b))
    }
    summary = {
        "cursor_lag_seconds": {
            "samples": len(all_lag),
            "median": round(statistics.median(all_lag), 2) if all_lag else None,
            "mean": round(statistics.mean(all_lag), 2) if all_lag else None,
            "p90": round(sorted(all_lag)[int(0.9 * len(all_lag))], 2) if all_lag else None,
        },
        "audio_margin_when_verdict_settles": {
            "words": len(all_margin),
            "median": round(statistics.median(all_margin), 2) if all_margin else None,
            "p90": round(sorted(all_margin)[int(0.9 * len(all_margin))], 2) if all_margin else None,
        },
        "verdict_agreement_by_audio_margin": by_margin,
    }
    args.out.write_text(json.dumps(summary, indent=2), encoding="utf-8")

    print()
    print("=" * 62)
    print("LIVE LATENCY")
    print("=" * 62)
    c = summary["cursor_lag_seconds"]
    print(f"  cursor sits behind the voice by: median {c['median']}s, "
          f"mean {c['mean']}s, p90 {c['p90']}s")
    print()
    print("  is a verdict right once this much audio has followed the word?")
    print(f"  {'margin':>8} {'verdicts':>10} {'agrees with final':>19}")
    for b in order:
        if b in by_margin:
            v = by_margin[b]
            print(f"  {b:>8} {v['verdicts']:>10} {v['agree_with_final_pct']:>18}%")
    print(f"\n  written to {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
