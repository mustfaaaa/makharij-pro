"""One-time script: fetch the complete Quran text (Uthmani Arabic + Saheeh
International English translation) and merge into a single JSON asset for
the Flutter app, replacing the Al-Fatihah-only dummy data used across
every surah's recitation/result/details screens."""
import json
from pathlib import Path

import httpx

OUT_PATH = Path(__file__).resolve().parent.parent.parent / "frontend" / "assets" / "quran" / "quran_full.json"


def fetch_edition(edition: str) -> dict:
    r = httpx.get(f"https://api.alquran.cloud/v1/quran/{edition}", timeout=60)
    r.raise_for_status()
    return r.json()["data"]


def clean(text: str) -> str:
    # Strip stray BOM/zero-width-no-break-space seen on ayah 1:1 in the API response.
    return text.replace("﻿", "").strip()


def main() -> None:
    arabic = fetch_edition("quran-uthmani")
    english = fetch_edition("en.sahih")

    assert len(arabic["surahs"]) == 114, f"expected 114 surahs, got {len(arabic['surahs'])}"
    assert len(english["surahs"]) == 114

    surahs = []
    total_ayahs = 0
    for ar_surah, en_surah in zip(arabic["surahs"], english["surahs"]):
        assert ar_surah["number"] == en_surah["number"]
        assert len(ar_surah["ayahs"]) == len(en_surah["ayahs"]), (
            f"surah {ar_surah['number']}: ayah count mismatch "
            f"{len(ar_surah['ayahs'])} vs {len(en_surah['ayahs'])}"
        )
        ayahs = []
        for ar_ayah, en_ayah in zip(ar_surah["ayahs"], en_surah["ayahs"]):
            assert ar_ayah["numberInSurah"] == en_ayah["numberInSurah"]
            ayahs.append({
                "number": ar_ayah["numberInSurah"],
                "arabicText": clean(ar_ayah["text"]),
                "translation": clean(en_ayah["text"]),
            })
        total_ayahs += len(ayahs)
        surahs.append({
            "number": ar_surah["number"],
            "nameArabic": ar_surah["name"],
            "nameEnglish": ar_surah["englishName"],
            "meaning": ar_surah["englishNameTranslation"],
            "revelationType": ar_surah["revelationType"],
            "ayahs": ayahs,
        })

    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    with open(OUT_PATH, "w", encoding="utf-8") as f:
        json.dump({"surahs": surahs}, f, ensure_ascii=False)

    with open(OUT_PATH.parent / "fetch_report.txt", "w", encoding="utf-8") as f:
        f.write(f"surahs={len(surahs)} total_ayahs={total_ayahs} expected=6236\n")
        f.write(f"output={OUT_PATH} size_bytes={OUT_PATH.stat().st_size}\n")

    print(f"OK surahs={len(surahs)} total_ayahs={total_ayahs} size={OUT_PATH.stat().st_size}")


if __name__ == "__main__":
    main()
