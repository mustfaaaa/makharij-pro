"""Discriminator: slice the reference Qari recitations exactly as the learner
clips were sliced, so the Makhraj head can be scored with the voice as the only
thing that changed.

What this separates
-------------------
The Makhraj head scores 96.6% on Quran-MD (isolated words, one reciter) and
10.8% on learner audio sliced out of continuous recitation. Two things changed
at once between those runs, and the learner test cannot tell them apart:

  1. the VOICE      -- learners, accented, hesitant, some children
  2. the SLICING    -- words cut from connected speech carry coarticulation
                       and boundary error that isolated recordings never had

This script holds (1) fixed at "professional reciter" while keeping (2)
identical to the learner run: same Zipformer timings, same 0.12 s padding, same
0.1-3.0 s usable window, same Basmala offset, same output schema.

  Qari-sliced stays high  ->  slicing is fine; the problem is learner voices,
                              and the fix is a labelled learner corpus
  Qari-sliced collapses   ->  the problem is slicing from continuous speech,
                              which is an engineering problem and fixable

Every word is labelled "correct" because a reference Qari reciting their own
recitation is correct by construction -- that also lets the same scoring
script, makhraj_head_on_learners.py, consume this index unchanged.

Run from the repo root:
    backend/.venv/Scripts/python.exe ml/eval/crossmodel/stage1_slice_qari.py
"""
from __future__ import annotations

import json
import sys
import time
from pathlib import Path

import librosa
import numpy as np
import soundfile as sf

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "backend"))

from app.phoneme_analysis_service import PhonemeAnalysisService  # noqa: E402
from app.quran_metadata import SURAH_AYAH_COUNTS  # noqa: E402

RECITATIONS = REPO / "backend" / "app" / "static" / "recitations"
OUT = Path(__file__).resolve().parent / "out_qari"
SLICES = OUT / "slices"
INDEX = OUT / "slices_index.jsonl"

SAMPLE_RATE = 16000
# Identical to stage1_slice_words.py -- changing either would make this a
# different experiment rather than a controlled comparison.
PADDING_SEC = 0.12
MIN_USABLE_SEC = 0.10
MAX_USABLE_SEC = 3.00


def main() -> int:
    if not RECITATIONS.is_dir():
        print(f"no reference recitations at {RECITATIONS}", file=sys.stderr)
        return 1

    print("loading the phoneme model...")
    try:
        service = PhonemeAnalysisService()
    except Exception as exc:
        print(f"phoneme model unavailable: {exc}", file=sys.stderr)
        return 1

    mapper = service._mapper
    qaris = sorted(p.name for p in RECITATIONS.iterdir() if p.is_dir())
    print(f"qaris: {qaris}")
    print(f"surahs with reference audio: {sorted(SURAH_AYAH_COUNTS)}")

    SLICES.mkdir(parents=True, exist_ok=True)
    written = clips = basmala_words = too_long = too_short = not_recited = 0
    started = time.time()

    with INDEX.open("w", encoding="utf-8") as index_fh:
        for qari in qaris:
            for surah, ayah_count in sorted(SURAH_AYAH_COUNTS.items()):
                for ayah in range(1, ayah_count + 1):
                    mp3 = RECITATIONS / qari / f"{surah:03d}{ayah:03d}.mp3"
                    if not mp3.is_file():
                        continue

                    audio_bytes = mp3.read_bytes()
                    try:
                        verdicts = service.analyze_range(audio_bytes, surah, ayah, ayah)
                    except Exception:
                        continue
                    clips += 1

                    y, _ = librosa.load(str(mp3), sr=SAMPLE_RATE, mono=True)

                    prefix = mapper.basmala_prefix_len(surah, ayah)
                    n_reference_words = len(mapper.words(surah, ayah)) - prefix

                    clip_id = f"{qari}_{surah:03d}{ayah:03d}"
                    clip_dir = SLICES / clip_id
                    made_any = False

                    for v in verdicts:
                        if not v.recited:
                            not_recited += 1
                            continue

                        reference_index = v.word_index - prefix + 1
                        if reference_index < 1 or reference_index > n_reference_words:
                            basmala_words += 1
                            continue

                        start = max(0, int((v.start_sec - PADDING_SEC) * SAMPLE_RATE))
                        end = min(len(y), int((v.end_sec + PADDING_SEC) * SAMPLE_RATE))
                        if end <= start:
                            continue
                        duration = (end - start) / SAMPLE_RATE

                        usable = MIN_USABLE_SEC <= duration <= MAX_USABLE_SEC
                        if duration < MIN_USABLE_SEC:
                            too_short += 1
                        elif duration > MAX_USABLE_SEC:
                            too_long += 1

                        if not made_any:
                            clip_dir.mkdir(parents=True, exist_ok=True)
                            made_any = True

                        slice_path = clip_dir / f"w{v.word_index:02d}.wav"
                        sf.write(slice_path, np.clip(y[start:end], -1.0, 1.0),
                                 SAMPLE_RATE, format="WAV", subtype="PCM_16")

                        index_fh.write(json.dumps({
                            "clip_id": clip_id,
                            # Correct by construction -- a reference Qari
                            # reciting their own recitation.
                            "label": "correct",
                            "reciter_id": qari,
                            "gender": "qari",
                            "surah": surah,
                            "ayah": ayah,
                            "word_index_zipformer": v.word_index,
                            "word_index_reference": reference_index,
                            "display_word": v.display_word,
                            "start_sec": round(v.start_sec, 4),
                            "end_sec": round(v.end_sec, 4),
                            "duration_sec": round(duration, 4),
                            "usable": usable,
                            "zipformer_flagged": (not v.correct),
                            "zipformer_rule": v.error_type,
                            "slice": str(slice_path.relative_to(OUT)).replace("\\", "/"),
                        }, ensure_ascii=False) + "\n")
                        written += 1

            print(f"  {qari}: {written} words so far "
                  f"({time.time() - started:.0f}s)")

    print()
    print(f"clips        : {clips}")
    print(f"word slices  : {written}")
    print(f"  under {MIN_USABLE_SEC}s : {too_short}")
    print(f"  over  {MAX_USABLE_SEC}s : {too_long}")
    print(f"  not recited: {not_recited}")
    print(f"  Basmala/oob: {basmala_words}")
    print(f"index        : {INDEX}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
