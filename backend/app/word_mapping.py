"""Maps the phoneme model's units onto the words the app actually displays.

Why this exists: the Quran-Lab phoneme table segments an ayah into *phonetic*
units, not written words, and the two only agree for 2,121 of 6,236 ayahs
(34%). Tajweed fuses words across boundaries -- وَقُرْءَانٍۢ مُّبِينٍۢ becomes the
single unit وَقُرءَاانِممممُبِۦۦۦۦن -- and the muqatta'at split the other way, الٓر
becoming three units (ءَلِف / لَاااااام / رَاا).

Using those units as word indices meant every verdict landed on the wrong word
outside that 34%. Al-Fatihah happens to be entirely inside it, which is exactly
why the app appeared to work for Al-Fatihah and nothing else.

Two further offsets are handled here:
  - The app's Quran asset prepends the Basmala to ayah 1 of every surah except
    At-Tawbah, while the phoneme table does not, so ayah 1 was misaligned by
    four words everywhere. The Basmala's own phonemes (surah 1 ayah 1, itself a
    clean 1:1 ayah) are prepended to match -- which also means the Basmala the
    user actually recites now gets scored instead of discarded.
  - Waqf marks are separate whitespace tokens in the text but carry no sound.

The mapping is derived, not assumed: both sides are reduced to a comparable
letter alphabet and aligned, so a word gets exactly the phoneme characters that
line up with its letters. tests/test_word_mapping.py measures the result across
all 6,236 ayahs rather than trusting it.
"""
import json
import unicodedata
from functools import lru_cache
from pathlib import Path


QURAN_JSON_PATH = (
    Path(__file__).resolve().parent.parent.parent / "frontend" / "assets" / "quran" / "quran_full.json"
)

# Phoneme alphabet -> plain Arabic letters. ۥ/ۦ are long-vowel carriers, ں/۾ the
# ikhfa noon/meem; the rest are pronunciation marks with no letter of their own.
_PHONEME_LETTER_MAP = {"ۥ": "و", "ۦ": "ي", "ں": "ن", "۾": "م"}
_PHONEME_DROP = set("َُؙِ۪ۜڇـ")

# Written Arabic -> the same plain alphabet, following what the phonemizer
# actually produces rather than dictionary spelling:
#   أ إ ؤ ئ آ  are all glottal stops, written ء in the phoneme alphabet
#   ى  and the superscript alef ٰ are long a, spelled اا
#   ة  is pronounced ت when the word is joined to the next, which in continuous
#      recitation it always is (غِشَٰوَةٌۭ -> غِشَااوَتُ)
_ARABIC_LETTER_MAP = {
    "أ": "ء", "إ": "ء", "آ": "ء", "ؤ": "ء", "ئ": "ء",
    "ى": "ا", "ٰ": "ا", "ة": "ت",
}
# The connecting hamza is silent mid-phrase and the phonemizer omits it
# entirely (ٱلْكِتَٰبِ -> لكِتَاابِ). Mapping it to a letter shifted every
# following word's phonemes one position to the left.
_ARABIC_DROP = {"ٱ"}

BASMALA_AYAH = (1, 1)
# At-Tawbah is the one surah with no Basmala, and Al-Fatihah's Basmala is its
# own ayah 1 rather than a prefix to it.
_NO_BASMALA_PREFIX = {1, 9}


def _is_arabic_mark(code: int) -> bool:
    return (
        (0x0610 <= code <= 0x061A)
        or (0x064B <= code <= 0x065F)
        or (0x06D6 <= code <= 0x06ED)
        or code in (0x0640, 0x06DF, 0x06E0)
    )


def _reduce(text: str, letter_map: dict, drop: set) -> tuple[str, list[int]]:
    """Reduce to bare letters, returning the letters and, for each one, the
    index of the source character it came from."""
    letters: list[str] = []
    origin: list[int] = []
    for i, ch in enumerate(text):
        if ch in drop or ch.isspace():
            continue
        mapped = letter_map.get(ch)
        if mapped is None:
            if _is_arabic_mark(ord(ch)):
                continue
            if not unicodedata.category(ch).startswith("L"):
                continue
            mapped = ch
        # Collapse runs: elongation and shaddah double a letter on the phoneme
        # side but not in writing, so both sides must be flattened to compare.
        # The run keeps the index of its *first* character: ownership is filled
        # forward from each anchored character, so anchoring on the last one
        # left the earlier characters of the run to be claimed by the previous
        # word (ٱللَّهِ's opening ل was landing on بِسْمِ).
        if letters and letters[-1] == mapped:
            continue
        letters.append(mapped)
        origin.append(i)
    return "".join(letters), origin


def _reduce_phonemes(text: str) -> tuple[str, list[int]]:
    return _reduce(text, _PHONEME_LETTER_MAP, _PHONEME_DROP)


def _reduce_arabic(text: str) -> tuple[str, list[int]]:
    return _reduce(text, _ARABIC_LETTER_MAP, _ARABIC_DROP)


# Alignment costs. Substitution is priced above two indels on purpose: pairing
# two *different* letters is almost always wrong here, and when the two sides
# each carry a letter the other lacks (ٱللَّهِ's dagger alef against
# ٱلرَّحْمَٰنِ's article lam) an equal-cost tie let the aligner chain
# substitutions across the word boundary, handing ٱللَّهِ's closing ه to the
# next word. Preferring insert+delete keeps identical letters paired.
_COST_INDEL = 2
_COST_SUB = 5


def _align_letters(a: str, b: str) -> list[tuple[int | None, int | None]]:
    """Weighted Levenshtein with backtrace, biased towards matching identical
    letters rather than substituting across a word boundary."""
    n, m = len(a), len(b)
    dp = [[0] * (m + 1) for _ in range(n + 1)]
    for i in range(1, n + 1):
        dp[i][0] = i * _COST_INDEL
    for j in range(1, m + 1):
        dp[0][j] = j * _COST_INDEL
    for i in range(1, n + 1):
        ai = a[i - 1]
        row, prev = dp[i], dp[i - 1]
        for j in range(1, m + 1):
            sub = prev[j - 1] + (0 if ai == b[j - 1] else _COST_SUB)
            row[j] = min(sub, prev[j] + _COST_INDEL, row[j - 1] + _COST_INDEL)

    i, j = n, m
    pairs: list[tuple[int | None, int | None]] = []
    while i > 0 or j > 0:
        if i > 0 and j > 0 and dp[i][j] == dp[i - 1][j - 1] + (0 if a[i - 1] == b[j - 1] else _COST_SUB):
            pairs.append((i - 1, j - 1)); i -= 1; j -= 1
        elif i > 0 and dp[i][j] == dp[i - 1][j] + _COST_INDEL:
            pairs.append((i - 1, None)); i -= 1
        else:
            pairs.append((None, j - 1)); j -= 1
    pairs.reverse()
    return pairs


def split_phonemes_by_word(phoneme_text: str, display_words: list[str]) -> list[str]:
    """Divide one ayah's phoneme string between its displayed words.

    Returns one phoneme substring per entry of [display_words] (possibly empty,
    for a word the phonemization has no sound for).
    """
    if not display_words:
        return []

    joined = " ".join(display_words)
    ar_letters, ar_origin = _reduce_arabic(joined)
    ph_letters, ph_origin = _reduce_phonemes(phoneme_text)
    if not ar_letters or not ph_letters:
        return ["" for _ in display_words]

    # Which display word each reduced Arabic letter belongs to.
    word_of_char = [0] * len(joined)
    wi = 0
    for i, ch in enumerate(joined):
        if ch == " ":
            wi += 1
            continue
        word_of_char[i] = wi
    letter_word = [word_of_char[o] for o in ar_origin]

    pairs = _align_letters(ph_letters, ar_letters)

    # Walk the alignment, handing each phoneme letter to the word its aligned
    # Arabic letter belongs to. An unaligned phoneme letter stays with whatever
    # word we were last inside, so nothing is dropped on the floor.
    letter_owner = [0] * len(ph_letters)
    current = 0
    for pi, ai in pairs:
        if ai is not None:
            current = letter_word[ai]
        if pi is not None:
            letter_owner[pi] = current

    # Translate letter ownership back to spans of the original phoneme string,
    # so diacritics and elongation repeats travel with their letter.
    owner_of_char = [None] * len(phoneme_text)
    for li, owner in enumerate(letter_owner):
        owner_of_char[ph_origin[li]] = owner
    current = 0
    for i in range(len(phoneme_text)):
        if owner_of_char[i] is None:
            owner_of_char[i] = current
        else:
            current = owner_of_char[i]

    out = ["" for _ in display_words]
    buffers: list[list[str]] = [[] for _ in display_words]
    for i, ch in enumerate(phoneme_text):
        if ch.isspace():
            continue
        buffers[owner_of_char[i]].append(ch)
    for i, buf in enumerate(buffers):
        out[i] = "".join(buf)
    return out


class WordMapper:
    """Serves display words and their expected phonemes for any ayah."""

    def __init__(self, phoneme_table: dict, quran_path: Path = QURAN_JSON_PATH):
        self._table = phoneme_table
        with open(quran_path, encoding="utf-8") as f:
            data = json.load(f)
        self._text: dict[str, str] = {
            f"{s['number']}:{a['number']}": a["arabicText"]
            for s in data["surahs"]
            for a in s["ayahs"]
        }

    def _phoneme_text(self, surah: int, ayah: int) -> str | None:
        entry = self._table.get(f"{surah}:{ayah}")
        return " ".join(entry["aya_phonemes_list"]) if entry else None

    def basmala_prefix_len(self, surah: int, ayah: int) -> int:
        """How many of this ayah's displayed words are the Basmala the asset
        prepends. 0 when the ayah carries none of its own."""
        if ayah != 1 or surah in _NO_BASMALA_PREFIX:
            return 0
        basmala = self._phoneme_text(*BASMALA_AYAH)
        return len(basmala.split()) if basmala else 0

    @lru_cache(maxsize=4096)
    def words(self, surah: int, ayah: int) -> tuple[tuple[str, str], ...]:
        """(display word, expected phonemes) for every word the app shows.

        Empty when there is no reference for this ayah.
        """
        text = self._text.get(f"{surah}:{ayah}")
        phonemes = self._phoneme_text(surah, ayah)
        if text is None or phonemes is None:
            return ()

        if ayah == 1 and surah not in _NO_BASMALA_PREFIX:
            # The displayed text opens with the Basmala; give the phoneme side
            # the same opening so the two line up word for word.
            basmala = self._phoneme_text(*BASMALA_AYAH)
            if basmala:
                phonemes = f"{basmala} {phonemes}"

        display = text.split()
        return tuple(zip(display, split_phonemes_by_word(phonemes, display)))
