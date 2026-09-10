"""How often does the analyser mark words the reciter never reached?

The report
----------
"When I recite 3 ayahs it also highlights ayah 4, or colours the word next to
the one I'm on." Both are the same failure: a word past the stop point clears
the heard bar by accident and drags the recited span with it.

Why that can happen (phoneme_analysis_service.py)
-------------------------------------------------
`analyze_range` decides recitation by a SPAN, not per word:

    in_span = first_heard <= i <= last_heard        # everything between counts
    last_heard = heard_idxs[-1]                     # the furthest word that
                                                    # cleared the bar

and the bar is a ratio:

    matched >= min(3, len(expected))  AND  matched / len(expected) >= 0.5

For a six-character word, three matching characters is enough -- and Arabic
phoneme strings share a handful of very common characters, so a word the
reciter never reached can pick up half a match from alignment spill. One such
word past the real stop point pulls `last_heard` forward, and *every* word in
between is then reported as recited.

The module's own comment already documents an instance of this: ٱلضَّآلِّينَ
scored 0.35 off a recitation that stopped two ayahs earlier. The ratio was
raised to 0.5 in response. This measures whether 0.5 was enough.

The measurement
---------------
Reference Qari recitations are per-ayah files, so consecutive ayahs can be
concatenated to build a recording that provably stops at a known ayah. Feed
that to `analyze_range` over the WHOLE surah and count words it reports as
recited beyond the true stop point. Anything past the cut is spill by
construction -- no labelling and no judgement call.

Professional reciters are used deliberately: if the boundary leaks on clean,
well-articulated audio, it will leak worse on a learner.

Run from the repo root:
    backend/.venv/Scripts/python.exe ml/eval/crossmodel/measure_recited_spill.py
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
OUT = Path(__file__).resolve().parent / "spill_report.json"
SAMPLE_RATE = 16000

# A real reciter pauses between ayahs; concatenating with no gap would create
# a join no recitation ever has and invent a difficulty that is not the bug
# under test.
GAP_SEC = 0.35


def main() -> int:
    parser = argparse.ArgumentParser()
    # Swept from here rather than by editing the service, so production code
    # keeps one honest default and the baseline can be reproduced at will.
    # ratio 0.0 / min-chars 0 makes every trailing word "strong", which is
    # exactly the behaviour before the tail bar existed.
    parser.add_argument("--tail-ratio", type=float, default=None)
    parser.add_argument("--tail-min-chars", type=int, default=None)
    parser.add_argument("--out", type=Path, default=OUT)
    args = parser.parse_args()

    import app.phoneme_analysis_service as pas
    if args.tail_ratio is not None:
        pas.TAIL_EXTEND_RATIO = args.tail_ratio
    if args.tail_min_chars is not None:
        pas.TAIL_EXTEND_MIN_CHARS = args.tail_min_chars
    print(f"tail bar: ratio={pas.TAIL_EXTEND_RATIO} "
          f"min_chars={pas.TAIL_EXTEND_MIN_CHARS}")

    print("loading the phoneme model...")
    service = PhonemeAnalysisService()

    qaris = sorted(p.name for p in RECITATIONS.iterdir() if p.is_dir())
    gap = np.zeros(int(GAP_SEC * SAMPLE_RATE), dtype=np.float32)

    # The control. Tightening the tail bar trades over-detection for
    # under-detection, so the harness has to watch both: a fix that stops
    # highlighting words nobody recited is worthless if it also stops
    # highlighting words they did. Here the whole surah is recited, so every
    # word SHOULD come back recited and anything missing is the cost.
    full_cases = 0
    full_missing_words = 0
    full_cases_with_missing = 0

    cases = 0
    cases_with_spill = 0
    spill_words_total = 0
    spill_ayahs_total = 0
    per_surah: dict[str, dict] = {}
    first_spill_distance = Counter()   # how many words past the stop it reached
    examples: list[dict] = []

    for qari in qaris:
        for surah, ayah_count in sorted(SURAH_AYAH_COUNTS.items()):
            if ayah_count < 2:
                continue
            # Load the whole surah once; every stop point reuses these.
            clips = {}
            for ayah in range(1, ayah_count + 1):
                mp3 = RECITATIONS / qari / f"{surah:03d}{ayah:03d}.mp3"
                if mp3.is_file():
                    clips[ayah], _ = librosa.load(str(mp3), sr=SAMPLE_RATE, mono=True)
            if len(clips) != ayah_count:
                continue

            # Control: the entire surah, nothing withheld.
            pieces = []
            for ayah in range(1, ayah_count + 1):
                pieces.append(clips[ayah])
                pieces.append(gap)
            whole = np.concatenate(pieces[:-1])
            buffer = io.BytesIO()
            sf.write(buffer, whole, SAMPLE_RATE, format="WAV", subtype="PCM_16")
            try:
                verdicts = service.analyze_range(buffer.getvalue(), surah, 1, ayah_count)
                full_cases += 1
                missing = [v for v in verdicts if not v.recited]
                if missing:
                    full_cases_with_missing += 1
                    full_missing_words += len(missing)
            except Exception:
                pass

            # Stop after each ayah except the last -- stopping at the last
            # leaves nothing to spill into.
            for stop_ayah in range(1, ayah_count):
                pieces = []
                for ayah in range(1, stop_ayah + 1):
                    pieces.append(clips[ayah])
                    pieces.append(gap)
                audio = np.concatenate(pieces[:-1])

                buffer = io.BytesIO()
                sf.write(buffer, audio, SAMPLE_RATE, format="WAV", subtype="PCM_16")
                try:
                    verdicts = service.analyze_range(
                        buffer.getvalue(), surah, 1, ayah_count)
                except Exception:
                    continue

                cases += 1
                # Every recited word belonging to an ayah after the stop point
                # is spill: that audio does not exist in the file.
                spilled = [v for v in verdicts if v.recited and v.ayah_number > stop_ayah]
                key = f"S{surah}"
                bucket = per_surah.setdefault(key, {"cases": 0, "spilled": 0, "words": 0})
                bucket["cases"] += 1

                if spilled:
                    cases_with_spill += 1
                    spill_words_total += len(spilled)
                    reached = max(v.ayah_number for v in spilled)
                    spill_ayahs_total += reached - stop_ayah
                    bucket["spilled"] += 1
                    bucket["words"] += len(spilled)
                    first = min(v.ayah_number for v in spilled)
                    first_spill_distance[first - stop_ayah] += 1
                    if len(examples) < 12:
                        examples.append({
                            "qari": qari, "surah": surah,
                            "recited_through_ayah": stop_ayah,
                            "highlighted_up_to_ayah": reached,
                            "spilled_words": len(spilled),
                            "first_spilled_word": spilled[0].display_word,
                        })

        print(f"  {qari}: {cases} cases, {cases_with_spill} with spill")

    pct = (100.0 * cases_with_spill / cases) if cases else 0.0
    summary = {
        "what": "words reported as recited beyond the true stop point",
        "audio": "reference Qari recitations, consecutive ayahs concatenated",
        "cases": cases,
        "cases_with_spill": cases_with_spill,
        "cases_with_spill_pct": round(pct, 1),
        "spilled_words_total": spill_words_total,
        "mean_spilled_words_per_affected_case": round(
            spill_words_total / cases_with_spill, 1) if cases_with_spill else 0,
        "ayahs_overrun_total": spill_ayahs_total,
        "first_spill_distance_in_ayahs": dict(sorted(first_spill_distance.items())),
        "per_surah": per_surah,
        "examples": examples,
        "control_full_surah": {
            "cases": full_cases,
            "cases_with_missing_words": full_cases_with_missing,
            "missing_words_total": full_missing_words,
            "note": "whole surah recited; every word should be recited=True, "
                    "so anything here is the cost of the tail bar",
        },
        "thresholds_in_force": {
            "HEARD_MATCH_RATIO": 0.5,
            "HEARD_MATCH_MIN_CHARS": 3,
            "TRAILING_MARGIN_WORDS": 2,
            "TAIL_EXTEND_RATIO": pas.TAIL_EXTEND_RATIO,
            "TAIL_EXTEND_MIN_CHARS": pas.TAIL_EXTEND_MIN_CHARS,
        },
    }
    args.out.write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")

    print()
    print("=" * 64)
    print("RECITED-SPILL: words highlighted that were never recited")
    print("=" * 64)
    print(f"  stop points tested        : {cases}")
    print(f"  cases that over-highlight : {cases_with_spill}  ({pct:.1f}%)")
    print(f"  words wrongly highlighted : {spill_words_total}")
    if cases_with_spill:
        print(f"  mean per affected case    : "
              f"{spill_words_total / cases_with_spill:.1f} words")
        print(f"  how far past the stop     : "
              f"{dict(sorted(first_spill_distance.items()))} (ayahs -> count)")
    print()
    worst = sorted(per_surah.items(),
                   key=lambda kv: -(kv[1]["spilled"] / max(kv[1]["cases"], 1)))[:6]
    print("  worst surahs (share of stop points affected):")
    for name, v in worst:
        share = 100.0 * v["spilled"] / max(v["cases"], 1)
        print(f"    {name:6} {share:5.1f}%   ({v['spilled']}/{v['cases']}, "
              f"{v['words']} words)")
    print(f"\n  written to {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
