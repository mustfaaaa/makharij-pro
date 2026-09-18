"""Regression check: reciting only ayah 1 of a surah, but requesting the whole
surah's range, must report reached_ayah == 1 with zero fabricated errors past
it -- for every surah tested, not just the ones EXPECTED_LENGTH_FLOOR was
originally tuned against. Surahs 113/114 have dense internal word repetition
(e.g. An-Nas's ayah 1 and ayah 2 both end in "الناس") that let the DP
alignment jump ahead to a distant coincidental match; this is the case that
motivated the _recited_span gap-tolerance fix.
"""
import io
import json
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import librosa
import numpy as np
import soundfile as sf

from app.phoneme_analysis_service import PhonemeAnalysisService

RECIT_DIR = Path(__file__).resolve().parent.parent / "app" / "static" / "recitations"

CASES = [
    ("abdurrahmaan_as_sudais", 1),
    ("abdurrahmaan_as_sudais", 112),
    ("abdurrahmaan_as_sudais", 108),
    ("yasser_ad_dussary", 114),
    ("alafasy", 113),
]


def build_ayah1_clip(qari: str, surah: int) -> bytes:
    """Match live_word_level_check.py's build_clip(1): a real ayah-1 mp3
    re-encoded as WAV with trailing silence, not the bare mp3 bytes -- this is
    what actually reproduced the reached_ayah over-extension originally."""
    y, _ = librosa.load(str(RECIT_DIR / qari / f"{surah:03d}001.mp3"), sr=16000, mono=True)
    full = np.concatenate([y, np.zeros(int(0.3 * 16000), dtype=np.float32)])
    buf = io.BytesIO()
    sf.write(buf, full, 16000, format="WAV")
    return buf.getvalue()


def main():
    print("Loading service...")
    svc = PhonemeAnalysisService()
    print("Loaded OK\n")

    out = []
    for qari, surah in CASES:
        audio_path = RECIT_DIR / qari / f"{surah:03d}001.mp3"
        if not audio_path.exists():
            print(f"SKIP {qari} {surah} -- no audio file")
            continue

        audio_bytes = build_ayah1_clip(qari, surah)
        results = svc.analyze_range(audio_bytes, surah, from_ayah=1, to_ayah=None)

        recited = [r for r in results if r.recited]
        reached_ayah = max((r.ayah_number for r in recited), default=0)
        words_correct = sum(1 for r in recited if r.correct)
        fabricated_beyond_ayah1 = sum(1 for r in recited if r.ayah_number > 1)

        row = {
            "qari": qari,
            "surah": surah,
            "reached_ayah": reached_ayah,
            "words_recited": len(recited),
            "words_correct": words_correct,
            "fabricated_beyond_ayah1": fabricated_beyond_ayah1,
        }
        out.append(row)
        print(row)
        for r in recited:
            mark = "OK " if r.correct else "ERR"
            print(f"    [{mark}] {r.ayah_number}:{r.word_index} pred={r.predicted_phonemes!r:16s} "
                  f"exp={r.expected_phonemes!r:16s} dist={r.edit_distance}")

    with open(Path(__file__).parent / "verify_partial_recitation_result.json", "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)


if __name__ == "__main__":
    main()
