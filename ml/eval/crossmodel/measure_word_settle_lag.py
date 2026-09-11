"""How far behind the voice does a verdict have to sit before it stops changing?

The question
------------
Live per-ayah feedback currently reports one whole ayah behind the cursor,
because an ayah judged the moment it ends reads as full of mistakes that are not
there. But "ayah" was never the real unit -- the instability comes from
`_recited_span`, whose far end has no following text to settle against, so the
tail of the audio gets attributed forward. That is a property of the last few
*words*, not of ayah boundaries.

If a verdict settles two or three words after the word itself, feedback could
follow the cursor almost word by word instead of a whole ayah behind.

The measurement
---------------
Take a reference recitation, whose every word is correct by construction, and
analyse growing prefixes of it. For each word, watch its verdict across prefixes
and find the point after which it never changes again. Then express that as: how
many further words had been recited by the time it settled.

Truncation is the whole mechanism under test, so prefixes are cut at fixed time
steps rather than at word boundaries -- a real reciter is mid-word when the
analyser runs, and cutting neatly at words would hide exactly the effect being
measured.

Run from the repo root:
    backend/.venv/Scripts/python.exe ml/eval/crossmodel/measure_word_settle_lag.py
"""
from __future__ import annotations

import argparse
import io
import json
import sys
from collections import Counter
from pathlib import Path

import librosa
import numpy as np
import soundfile as sf

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "backend"))

from app.phoneme_analysis_service import PhonemeAnalysisService  # noqa: E402
from app.quran_metadata import SURAH_AYAH_COUNTS  # noqa: E402

RECITATIONS = REPO / "backend" / "app" / "static" / "recitations"
OUT = Path(__file__).resolve().parent / "word_settle_lag.json"
SAMPLE_RATE = 16000
GAP_SEC = 0.35
STEP_SEC = 0.5          # how often the analyser would run


def verdict_of(result) -> str:
    if not result.recited:
        return "unread"
    return "ok" if result.correct else f"flag:{result.error_type}"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--surahs", type=int, nargs="*", default=[1, 108, 110, 112, 103])
    parser.add_argument("--out", type=Path, default=OUT)
    args = parser.parse_args()

    print("loading the phoneme model...")
    service = PhonemeAnalysisService()
    qaris = sorted(p.name for p in RECITATIONS.iterdir() if p.is_dir())
    gap = np.zeros(int(GAP_SEC * SAMPLE_RATE), dtype=np.float32)

    lag_counts = Counter()
    never_settled = 0
    words_measured = 0
    per_surah: dict[str, list[int]] = {}

    for qari in qaris:
        for surah in args.surahs:
            count = SURAH_AYAH_COUNTS.get(surah, 0)
            if count < 2:
                continue
            clips = {}
            for ayah in range(1, count + 1):
                mp3 = RECITATIONS / qari / f"{surah:03d}{ayah:03d}.mp3"
                if mp3.is_file():
                    clips[ayah], _ = librosa.load(str(mp3), sr=SAMPLE_RATE, mono=True)
            if len(clips) != count:
                continue

            pieces = []
            for ayah in range(1, count + 1):
                pieces.append(clips[ayah])
                pieces.append(gap)
            audio = np.concatenate(pieces[:-1])

            def analyse(upto_samples: int):
                buffer = io.BytesIO()
                sf.write(buffer, audio[:upto_samples], SAMPLE_RATE,
                         format="WAV", subtype="PCM_16")
                try:
                    return service.analyze_range(buffer.getvalue(), surah, 1, count)
                except Exception:
                    return None

            final = analyse(len(audio))
            if not final:
                continue
            # (ayah, word_index) -> the verdict the complete recitation gives,
            # which is the answer live feedback is trying to reach early.
            truth = {(r.ayah_number, r.word_index): verdict_of(r) for r in final}

            # Walk the prefixes, recording for each word the last prefix at
            # which its verdict disagreed with the truth.
            last_wrong: dict[tuple[int, int], int] = {}
            recited_at: list[tuple[int, int]] = []   # words recited, per prefix
            step = int(STEP_SEC * SAMPLE_RATE)
            prefixes = list(range(step, len(audio) + step, step))
            for pi, upto in enumerate(prefixes):
                results = analyse(min(upto, len(audio)))
                if not results:
                    recited_at.append((pi, 0))
                    continue
                recited = sum(1 for r in results if r.recited)
                recited_at.append((pi, recited))
                for r in results:
                    key = (r.ayah_number, r.word_index)
                    if verdict_of(r) != truth.get(key):
                        last_wrong[key] = pi

            # Words the reciter actually reached, in order.
            order = [(r.ayah_number, r.word_index) for r in final if r.recited]
            recited_by_prefix = dict(recited_at)

            for position, key in enumerate(order, start=1):
                words_measured += 1
                wrong_until = last_wrong.get(key)
                if wrong_until is None:
                    lag_counts[0] += 1          # right from the first prefix
                    per_surah.setdefault(f"S{surah}", []).append(0)
                    continue
                if wrong_until >= len(prefixes) - 1:
                    never_settled += 1
                    continue
                # How many words had been recited by the prefix where it
                # settled, minus this word's own position.
                settled_prefix = wrong_until + 1
                recited_then = recited_by_prefix.get(settled_prefix, position)
                lag = max(recited_then - position, 0)
                lag_counts[lag] += 1
                per_surah.setdefault(f"S{surah}", []).append(lag)

        print(f"  {qari}: {words_measured} words measured")

    total = sum(lag_counts.values())
    ordered = sorted(lag_counts.items())
    cumulative, running = [], 0
    for lag, n in ordered:
        running += n
        cumulative.append({"words_of_lag": lag, "settled_pct": round(100 * running / total, 1)})

    summary = {
        "what": "how many further words must be recited before a word's verdict "
                "matches the one the complete recitation gives",
        "audio": "reference Qari recitations, analysed at growing prefixes",
        "step_seconds": STEP_SEC,
        "words_measured": words_measured,
        "words_that_settled": total,
        "words_never_settled": never_settled,
        "distribution": {str(k): v for k, v in ordered},
        "cumulative": cumulative,
    }
    args.out.write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")

    print()
    print("=" * 62)
    print("HOW MANY WORDS OF LAG BEFORE A VERDICT IS TRUSTWORTHY")
    print("=" * 62)
    print(f"  words measured      : {words_measured}")
    print(f"  never settled       : {never_settled}")
    print()
    print(f"  {'lag (words)':>12}  {'share settled by then':>22}")
    for row in cumulative[:12]:
        print(f"  {row['words_of_lag']:>12}  {row['settled_pct']:>21}%")
    print(f"\n  written to {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
