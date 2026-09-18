"""Real end-to-end test of PhonemeAnalysisService's word-level grouping
against real Rattil audio, before wiring it into the live endpoint.
"""
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.phoneme_analysis_service import PhonemeAnalysisService

RECIT_DIR = Path(__file__).resolve().parent.parent / "app" / "static" / "recitations"

CASES = [
    ("abdurrahmaan_as_sudais", 1, 1),
    ("abdurrahmaan_as_sudais", 1, 2),
    ("abdurrahmaan_as_sudais", 112, 1),
    ("yasser_ad_dussary", 1, 1),
    ("alafasy", 113, 1),
]


def main():
    print("Loading service...")
    svc = PhonemeAnalysisService()
    print("Loaded OK\n")

    for qari, surah, ayah in CASES:
        audio_path = RECIT_DIR / qari / f"{surah:03d}{ayah:03d}.mp3"
        if not audio_path.exists():
            print(f"SKIP {qari} {surah}:{ayah} -- no audio file")
            continue

        audio_bytes = audio_path.read_bytes()
        results = svc.analyze(audio_bytes, surah, ayah)

        print(f"=== {qari} {surah}:{ayah} ===")
        for r in results:
            mark = "OK " if r.correct else "ERR"
            print(f"  [{mark}] word {r.word_index}: pred={r.predicted_phonemes!r:20s} "
                  f"exp={r.expected_phonemes!r:20s} dist={r.edit_distance} "
                  f"t=[{r.start_sec:.2f},{r.end_sec:.2f}]")
        print()


if __name__ == "__main__":
    main()
