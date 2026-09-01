"""Broad regression sweep for the partial-recitation over-extension failure
mode (see EXPECTED_LENGTH_FLOOR docstring in phoneme_analysis_service.py):
recite only ayah 1 of a surah, request the whole surah's range, and check that
the analysis never fabricates recited/flagged words past ayah 1.

Previous checks only re-tested the two surahs (113, 114) already known to have
failed at some point. This sweeps every surah with real reference audio for
all three qaris in the recitation library -- 45 real cases -- to get honest
coverage of the failure mode across the short, densely-repetitive surahs where
it is most likely to occur, not just the two already known.
"""
import json
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.phoneme_analysis_service import PhonemeAnalysisService

RECIT_DIR = Path(__file__).resolve().parent.parent / "app" / "static" / "recitations"
QARIS = ["abdurrahmaan_as_sudais", "alafasy", "yasser_ad_dussary"]
SURAHS = [1] + list(range(101, 115))


def main():
    print("Loading service...")
    svc = PhonemeAnalysisService()
    print("Loaded OK\n")

    results = []
    failures = []
    for qari in QARIS:
        for surah in SURAHS:
            audio_path = RECIT_DIR / qari / f"{surah:03d}001.mp3"
            if not audio_path.exists():
                continue
            audio_bytes = audio_path.read_bytes()
            words = svc.analyze_range(audio_bytes, surah, from_ayah=1, to_ayah=None)
            recited = [w for w in words if w.recited]
            reached_ayah = max((w.ayah_number for w in recited), default=0)
            beyond = [w for w in recited if w.ayah_number > 1]

            ok = reached_ayah <= 1 and not beyond
            row = {
                "qari": qari, "surah": surah, "reached_ayah": reached_ayah,
                "words_recited": len(recited), "fabricated_beyond_ayah1": len(beyond),
                "ok": ok,
            }
            results.append(row)
            status = "OK  " if ok else "FAIL"
            print(f"{status} {qari:24s} surah {surah:3d}  reached_ayah={reached_ayah}  "
                  f"words_recited={len(recited)}  beyond_ayah1={len(beyond)}")
            if not ok:
                failures.append(row)
                for w in beyond:
                    print(f"       -> fabricated {w.ayah_number}:{w.word_index} "
                          f"pred={w.predicted_phonemes!r} exp={w.expected_phonemes!r}")

    print(f"\n{len(results) - len(failures)}/{len(results)} cases correctly stopped at ayah 1, "
          f"{len(failures)} fabricated content beyond the actual stop point")

    with open(Path(__file__).parent / "broad_partial_recitation_sweep_result.json", "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)


if __name__ == "__main__":
    main()
