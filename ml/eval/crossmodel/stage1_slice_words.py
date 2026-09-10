"""Stage 1 of the cross-model comparison: cut the 773 labelled learner clips
into individual words, using the shipped Zipformer's own word timings.

Why this stage exists
---------------------
`makharijpro_v1` (C:/makharij_dataset) judges ONE word of audio at a time --
it was trained on Quran-MD's isolated word recordings and takes at most 3.0 s
per input. The 773 evaluation clips are continuous ayah recitations. Something
has to find the word boundaries, and the only thing in this project that can is
the Zipformer: `analyze_range` already returns a per-word start/end in seconds,
and `reference_words.word_wav` already cuts audio on exactly those timings for
the "hear a Qari" feature.

So this stage reuses the app's real segmentation rather than inventing a second
one. That matters for the comparison's fairness: both systems then see the same
word boundaries, and any difference in verdicts is a difference in *judgement*,
not in where the words were cut.

Why it is a separate process
----------------------------
The two models were validated in different environments -- this repo runs
Python 3.12 / librosa 0.11, makharij_dataset runs Python 3.14 / librosa 1.0 --
and a speech model's front end is exactly where a silent version drift destroys
a measurement. Each model therefore runs in the environment it was validated
in, and they communicate through the slice files this script writes. Nothing is
shared but WAV data.

Output
------
  out/slices/<clip_id>/w<NN>.wav     one recited word each, 16 kHz mono
  out/slices_index.jsonl             one row per word, with the clip's human
                                     label carried through

Run from the repo root, with the backend venv:

    backend/.venv/Scripts/python.exe ml/eval/crossmodel/stage1_slice_words.py
"""
from __future__ import annotations

import csv
import io
import json
import sys
import time
from pathlib import Path

import numpy as np
import soundfile as sf

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "backend"))

from app.phoneme_analysis_service import PhonemeAnalysisService  # noqa: E402

EVALSET = REPO / "ml" / "data" / "quranic_audio_dataset" / "evalset"
MANIFEST = EVALSET / "manifest.csv"
OUT = Path(__file__).resolve().parent / "out"
SLICES = OUT / "slices"
INDEX = OUT / "slices_index.jsonl"

SAMPLE_RATE = 16000

# The same padding reference_words.py uses, for the same reason: a word timing
# marks where sound was *detected*, and cutting exactly on that boundary clips
# the onset of a stop and the fade of a madd -- both of which are the signal
# makharijpro_v1 is being asked to judge.
PADDING_SEC = 0.12

# makharijpro_v1 centre-crops at 300 frames (3.0 s) and refuses input under
# 0.1 s (models/makharijpro_v1/config.json). Slices outside that range are
# written anyway but marked, so stage 2 can report how many it had to skip
# rather than silently dropping them from the denominator.
MIN_USABLE_SEC = 0.10
MAX_USABLE_SEC = 3.00


def main() -> int:
    if not MANIFEST.is_file():
        print(f"manifest not found: {MANIFEST}", file=sys.stderr)
        return 1

    print("loading the phoneme model...")
    try:
        service = PhonemeAnalysisService()
    except Exception as exc:
        print(f"phoneme model unavailable -- cannot segment: {exc}", file=sys.stderr)
        return 1

    mapper = service._mapper
    rows = list(csv.DictReader(MANIFEST.open(encoding="utf-8")))
    SLICES.mkdir(parents=True, exist_ok=True)

    written = skipped_clip = 0
    too_short = too_long = not_recited = basmala_words = 0
    started = time.time()

    with INDEX.open("w", encoding="utf-8") as index_fh:
        for n, row in enumerate(rows, 1):
            clip_id = row["clip_id"]
            surah, ayah = int(row["surah"]), int(row["ayah"])
            wav_path = EVALSET / row["file"]
            if not wav_path.is_file():
                skipped_clip += 1
                continue

            audio_bytes = wav_path.read_bytes()
            try:
                verdicts = service.analyze_range(audio_bytes, surah, ayah, ayah)
            except Exception as exc:  # a clip the recogniser cannot handle at all
                print(f"  {clip_id}: analyze_range failed ({type(exc).__name__})")
                skipped_clip += 1
                continue

            y, sr = sf.read(io.BytesIO(audio_bytes), dtype="float32", always_2d=False)
            if y.ndim > 1:
                y = y.mean(axis=int(np.argmin(y.shape)))
            if sr != SAMPLE_RATE:
                import librosa
                y = librosa.resample(y, orig_sr=sr, target_sr=SAMPLE_RATE)

            # The app prepends the Basmala to every surah's ayah 1 (except
            # the surahs that carry none, and Al-Fatihah where it *is* ayah 1),
            # so the Zipformer's word list is offset from the reference store's
            # by that many words. Verified: S108:A1 has 7 displayed words with
            # a 4-word Basmala prefix, while the reference store holds 3 --
            # so its word 1 is the Zipformer's index 4.
            prefix = mapper.basmala_prefix_len(surah, ayah)
            n_reference_words = len(mapper.words(surah, ayah)) - prefix

            clip_dir = SLICES / clip_id
            made_any = False

            for v in verdicts:
                # The Zipformer indexes words within an ayah from 0; the
                # makharijpro_v1 reference store indexes them from 1 (verified:
                # word_index min=1, max=128 across all 77,429 positions). The
                # +1 lives here, once, rather than in stage 2 where a silent
                # off-by-one would mismatch every word in the experiment.
                word_index = v.word_index
                # Words the reciter never reached carry no audio to judge. They
                # are not mistakes here and must not become denominator either.
                if not v.recited:
                    not_recited += 1
                    continue

                # Basmala words belong to no ayah of this surah in the
                # reference store, and words past the ayah's real length have
                # no reference either. Both are excluded and counted rather
                # than silently mapped onto the wrong word.
                reference_index = word_index - prefix + 1
                if reference_index < 1 or reference_index > n_reference_words:
                    basmala_words += 1
                    continue

                start = max(0, int((v.start_sec - PADDING_SEC) * SAMPLE_RATE))
                end = min(len(y), int((v.end_sec + PADDING_SEC) * SAMPLE_RATE))
                duration = (end - start) / SAMPLE_RATE
                if end <= start:
                    continue

                usable = MIN_USABLE_SEC <= duration <= MAX_USABLE_SEC
                if duration < MIN_USABLE_SEC:
                    too_short += 1
                elif duration > MAX_USABLE_SEC:
                    too_long += 1

                if not made_any:
                    clip_dir.mkdir(parents=True, exist_ok=True)
                    made_any = True

                slice_path = clip_dir / f"w{word_index:02d}.wav"
                sf.write(slice_path, np.clip(y[start:end], -1.0, 1.0), SAMPLE_RATE,
                         format="WAV", subtype="PCM_16")

                index_fh.write(json.dumps({
                    "clip_id": clip_id,
                    "label": row["label"],                 # correct | in_correct
                    "reciter_id": row["reciter_id"],
                    "gender": row.get("gender", ""),
                    "surah": surah,
                    "ayah": ayah,
                    "word_index_zipformer": word_index,          # 0-based, incl. Basmala
                    "word_index_reference": reference_index,     # 1-based, Basmala removed
                    "display_word": v.display_word,
                    "start_sec": round(v.start_sec, 4),
                    "end_sec": round(v.end_sec, 4),
                    "duration_sec": round(duration, 4),
                    "usable": usable,
                    # What the Zipformer itself concluded about this word, so
                    # stage 3 can compare the two systems word by word and not
                    # merely clip by clip.
                    # WordPhonemeResult carries `correct`, not `flagged`, and
                    # `error_type` is already the wire string.
                    "zipformer_flagged": (not v.correct),
                    "zipformer_rule": v.error_type,
                    "slice": str(slice_path.relative_to(OUT)).replace("\\", "/"),
                }, ensure_ascii=False) + "\n")
                written += 1

            if n % 50 == 0:
                rate = n / max(time.time() - started, 1e-9)
                print(f"  {n}/{len(rows)} clips  ({rate:.1f} clips/s, {written} words)")

    print()
    print(f"clips processed : {len(rows) - skipped_clip}/{len(rows)}  ({skipped_clip} skipped)")
    print(f"word slices     : {written}")
    print(f"  under {MIN_USABLE_SEC}s  : {too_short}")
    print(f"  over  {MAX_USABLE_SEC}s  : {too_long}")
    print(f"  never recited : {not_recited} (no audio -- correctly excluded)")
    print(f"  Basmala/oob   : {basmala_words} (no reference-store entry)")
    print(f"index           : {INDEX}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
