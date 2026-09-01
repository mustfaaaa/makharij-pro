"""Resolves a clip's Arabic ayah text to the (surah, ayah) the app can score.

The Quranic Audio Dataset identifies a clip by the surah's English name and the
ayah's Arabic text -- never by number -- and writes that text in a different
orthography from the app's own Quran asset. Nothing from the dataset can enter
the pipeline until the two are reconciled, so this is the gate the whole
evaluation stands on.

Measured on the full 6,828-clip corpus: exact bare-letter matching resolved
18.8%. Three orthographic differences accounted for almost all of the misses,
and folding them takes it to 73.1% -- with essentially everything remaining
being material that *should not* resolve (see NOT_QURAN below, plus Ayat
al-Kursi clips that are fragments of 2:255 rather than whole ayahs).
"""
import json
import re
import unicodedata
from pathlib import Path

QURAN_JSON_PATH = (
    Path(__file__).resolve().parent.parent.parent
    / "frontend" / "assets" / "quran" / "quran_full.json"
)

# Dataset "surah" values that are not Quran at all -- the call to prayer, the
# tashahhud, supplications. About 900 clips. They are excluded rather than left
# to fail matching silently, so the resolution rate reflects real misses.
NOT_QURAN = {
    "Adhan", "Iqamah Prayer", "At-Tahiyyat", "Subhanaka", "Salawat",
    "Adhkar after prayer", "Dua Qunoot", "Dua for Protection", "Ayat Ramadan",
    "Dua from the Quran",
}

_FOLD = {
    # Every alif form folds away together. Alif is written inconsistently
    # between the two orthographies -- sometimes a full ا, sometimes the
    # superscript ٰ, sometimes neither (مَٰلِكِ vs مَالِكِ, but ٱلرَّحْمَٰنِ vs
    # الرَّحْمَنِ goes the other way). Folding it *to* a letter fixed one case
    # while breaking the other, so for identification it simply goes: a whole
    # ayah keeps far more than enough remaining letters to stay unique.
    "ا": "", "ٱ": "", "أ": "", "إ": "", "آ": "", "ٲ": "", "ٳ": "", "ٰ": "",
    # Alef maqsura, Farsi yeh, yeh-hamza all stand for the same letter here.
    "ى": "ي", "ی": "ي", "ئ": "ي",
    "ک": "ك",   # Farsi kaf
    "ة": "ه", "ؤ": "و", "ء": "",
}


def fold(text: str) -> str:
    """Reduce an ayah to the bare letters the two orthographies agree on."""
    out = []
    for ch in unicodedata.normalize("NFC", text or ""):
        if ch in _FOLD:
            if _FOLD[ch]:
                out.append(_FOLD[ch])
            continue
        code = ord(ch)
        # Harakat, Quranic annotation and waqf marks, tatweel.
        if (0x0610 <= code <= 0x061A) or (0x064B <= code <= 0x065F) \
                or (0x06D6 <= code <= 0x06ED) or code == 0x0640:
            continue
        if unicodedata.category(ch).startswith("L"):
            out.append(ch)
    return re.sub(r"\s+", "", "".join(out))


class AyahResolver:
    """Maps folded ayah text to (surah, ayah)."""

    def __init__(self, quran_path: Path = QURAN_JSON_PATH):
        with open(quran_path, encoding="utf-8") as f:
            quran = json.load(f)

        self._index: dict[str, set[tuple[int, int]]] = {}
        basmala = None
        for surah in quran["surahs"]:
            for ayah in surah["ayahs"]:
                key = fold(ayah["arabicText"])
                self._index.setdefault(key, set()).add((surah["number"], ayah["number"]))
                if surah["number"] == 1 and ayah["number"] == 1:
                    basmala = key

        # The asset prepends the Basmala to every surah's ayah 1, so a clip of
        # just that opening ayah only matches with the prefix stripped.
        for surah in quran["surahs"]:
            if surah["number"] == 1 or not basmala:
                continue
            first = surah["ayahs"][0]
            key = fold(first["arabicText"])
            if key.startswith(basmala):
                self._index.setdefault(key[len(basmala):], set()).add(
                    (surah["number"], first["number"])
                )

    def resolve(self, surah_name: str | None, ayah_text: str | None):
        """(surah, ayah) for a clip, or None when it can't be placed.

        Ambiguous matches -- the same text appearing in more than one ayah --
        are rejected rather than guessed: scoring against the wrong ayah would
        manufacture mistakes that never happened.
        """
        if surah_name in NOT_QURAN:
            return None
        hits = self._index.get(fold(ayah_text))
        if not hits or len(hits) > 1:
            return None
        return next(iter(hits))
