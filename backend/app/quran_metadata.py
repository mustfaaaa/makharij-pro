"""Ayah counts for the surahs currently in the Rattil AI repository. Extend this alongside the
repository itself (see tests/build_rattil_repository.py) when more surahs are added -- this file
intentionally does NOT claim to cover all 114 surahs, only what's actually been populated.

Surah 100 (Al-'Adiyat) was deliberately left out of the 101-114 expansion: the source dataset
(Buraaq/quran-md-ayahs) is missing ayahs 1-2 for all three of our reciters -- a real gap in the
data, not something we can serve honestly."""

SURAH_AYAH_COUNTS = {
    1: 7, 101: 11, 102: 8, 103: 3, 104: 9, 105: 5, 106: 4, 107: 7,
    108: 3, 109: 6, 110: 3, 111: 5, 112: 4, 113: 5, 114: 6,
}

SURAH_NAMES = {
    1: {"ar": "الفاتحة", "en": "Al-Fatiha"},
    101: {"ar": "القارعة", "en": "Al-Qari'ah"},
    102: {"ar": "التكاثر", "en": "At-Takathur"},
    103: {"ar": "العصر", "en": "Al-'Asr"},
    104: {"ar": "الهمزة", "en": "Al-Humazah"},
    105: {"ar": "الفيل", "en": "Al-Fil"},
    106: {"ar": "قريش", "en": "Quraysh"},
    107: {"ar": "الماعون", "en": "Al-Ma'un"},
    108: {"ar": "الكوثر", "en": "Al-Kawthar"},
    109: {"ar": "الكافرون", "en": "Al-Kafirun"},
    110: {"ar": "النصر", "en": "An-Nasr"},
    111: {"ar": "المسد", "en": "Al-Masad"},
    112: {"ar": "الإخلاص", "en": "Al-Ikhlas"},
    113: {"ar": "الفلق", "en": "Al-Falaq"},
    114: {"ar": "الناس", "en": "An-Nas"},
}
