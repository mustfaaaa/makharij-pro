"""Broad correctness sweep in the other direction from
broad_partial_recitation_sweep.py: instead of checking that a partial
recitation doesn't fabricate errors past its stop point, this checks that a
*complete, correct* recitation of a whole surah is not over-flagged with false
positives, and that it reaches the real last ayah rather than stopping short.

Existing coverage of this direction was a single ayah (Al-Fatihah 1:1, one
qari) in test_live_endpoints.py. This splices every ayah of every surah with
real reference audio, for all three qaris, into one continuous recitation
(same technique as live_word_level_check.py's build_clip) and analyzes the
whole thing -- 45 real, non-fabricated cases.

A real streaming ASR model has a documented ~3.65% phoneme error rate, so
100% correct on every word is not the bar (see phoneme_analysis_service.py's
module docstring) -- flagging occasional elongation/ghunnah jitter on a
reference Qari is expected, not a bug. What *would* be a bug: reaching the
wrong last ayah, or a correct-word rate low enough to suggest the alignment
itself is broken rather than just recognizer noise.
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
QARIS = ["abdurrahmaan_as_sudais", "alafasy", "yasser_ad_dussary"]
SURAHS = [1] + list(range(101, 115))

# Below this correct-word rate, treat it as a real regression worth
# investigating rather than expected recognizer noise.
MIN_ACCEPTABLE_ACCURACY = 0.70


def build_full_clip(svc: PhonemeAnalysisService, qari: str, surah: int) -> bytes:
    n_ayahs = svc.ayah_count(surah)
    chunks = []
    for ayah in range(1, n_ayahs + 1):
        path = RECIT_DIR / qari / f"{surah:03d}{ayah:03d}.mp3"
        if not path.exists():
            return b""
        y, _ = librosa.load(str(path), sr=16000, mono=True)
        chunks += [y, np.zeros(int(0.3 * 16000), dtype=np.float32)]
    full = np.concatenate(chunks)
    buf = io.BytesIO()
    sf.write(buf, full, 16000, format="WAV")
    return buf.getvalue()


def main():
    print("Loading service...")
    svc = PhonemeAnalysisService()
    print("Loaded OK\n")

    results = []
    concerns = []
    for qari in QARIS:
        for surah in SURAHS:
            audio = build_full_clip(svc, qari, surah)
            if not audio:
                print(f"SKIP {qari} surah {surah} -- missing per-ayah audio")
                continue

            n_ayahs = svc.ayah_count(surah)
            words = svc.analyze_range(audio, surah, from_ayah=1, to_ayah=None)
            recited = [w for w in words if w.recited]
            reached_ayah = max((w.ayah_number for w in recited), default=0)
            correct = sum(1 for w in recited if w.correct)
            accuracy = correct / len(recited) if recited else 0.0

            reached_end = reached_ayah == n_ayahs
            acceptable = accuracy >= MIN_ACCEPTABLE_ACCURACY
            row = {
                "qari": qari, "surah": surah, "n_ayahs": n_ayahs,
                "reached_ayah": reached_ayah, "words_recited": len(recited),
                "words_correct": correct, "accuracy": round(accuracy, 3),
                "reached_end": reached_end, "acceptable_accuracy": acceptable,
            }
            results.append(row)
            status = "OK  " if (reached_end and acceptable) else "WARN"
            print(f"{status} {qari:24s} surah {surah:3d} ({n_ayahs} ayahs)  "
                  f"reached_ayah={reached_ayah}  words={len(recited)}  "
                  f"correct={correct} ({accuracy:.0%})")
            if not (reached_end and acceptable):
                concerns.append(row)

    print(f"\n{len(results) - len(concerns)}/{len(results)} full recitations reached the "
          f"real last ayah with >= {MIN_ACCEPTABLE_ACCURACY:.0%} correct words")
    if concerns:
        print("\nCases worth a closer look:")
        for c in concerns:
            print(f"  {c}")

    with open(Path(__file__).parent / "broad_full_surah_sweep_result.json", "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)


if __name__ == "__main__":
    main()
