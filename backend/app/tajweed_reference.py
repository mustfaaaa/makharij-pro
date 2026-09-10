"""Per-word Tajweed reference: which Makhraj a word starts from, which rules
apply to it, and how long its madd should be held.

This is reference data about the Quran's text, not a prediction about audio.
Nothing here runs a model, so none of the uncertainty that surrounds the
recogniser applies: when this says a word carries a 4-count madd, that is what
the word *is*, not what someone was heard to do.

That distinction is the point. The app can teach with this even where it cannot
reliably judge -- "this word begins from ash-shafatain and carries a ghunnah" is
true regardless of how well any detector performs on a given recording.

Source: extracted by ml/tools/extract_tajweed_reference.py from the
makharij_dataset project, itself derived from Quran-Lab's phone sequences and
Quran-MD's word forms. 77,429 word positions, all 114 surahs, all 6,236 ayahs.

Word indexing
-------------
The asset indexes words 1-based within an ayah and EXCLUDES the Basmala. This
app displays words 0-based and PREPENDS the Basmala to every surah's ayah 1
(bar Al-Fatihah, where it is ayah 1, and the surahs that carry none). The
conversion lives here and nowhere else:

    reference_index = app_word_index - basmala_prefix_len(surah, ayah) + 1

Callers that already hold a reference-style index use `word()`; callers holding
an index from the reading page or a WordPhonemeResult use `word_for_display()`
and let this module do the arithmetic.
"""
from __future__ import annotations

import sqlite3
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path

DB_PATH = Path(__file__).resolve().parent / "data" / "tajweed_reference.sqlite3"

# The Basmala is four words, and it prefixes every surah's ayah 1 except two:
# Al-Fatihah, where it *is* ayah 1, and At-Tawbah, which carries none. Mirrors
# word_mapping._NO_BASMALA_PREFIX, but computed without it on purpose -- that
# module needs the gated phoneme model's tables, and the whole point of this
# reference is that it works with no model loaded at all.
BASMALA_WORD_COUNT = 4
_NO_BASMALA_PREFIX = {1, 9}


def basmala_prefix_len(surah: int, ayah: int) -> int:
    """How many leading words of this ayah are the Basmala the app prepends."""
    if ayah != 1 or surah in _NO_BASMALA_PREFIX:
        return 0
    return BASMALA_WORD_COUNT

# The 15 consonant articulation points, with the letters each covers, so a
# caller can render "ash_shafatain" as something a learner can read.
MAKHRAJ_LABELS: dict[str, dict[str, str]] = {
    "aqsal_halq": {"letters": "ء ه", "en": "Deepest throat"},
    "wasat_al_halq": {"letters": "ع ح", "en": "Middle of the throat"},
    "adnal_halq": {"letters": "غ خ", "en": "Nearest part of the throat"},
    "aqsal_lisan_qaf": {"letters": "ق", "en": "Deepest part of the tongue"},
    "aqsal_lisan_kaf": {"letters": "ك", "en": "Deepest tongue, further forward"},
    "wasat_al_lisan": {"letters": "ج ش ي", "en": "Middle of the tongue"},
    "janib_al_lisan": {"letters": "ض", "en": "Side of the tongue"},
    "taraf_al_lisan_lam": {"letters": "ل", "en": "Tongue tip against the gums"},
    "taraf_al_lisan_noon": {"letters": "ن", "en": "Tongue tip (nun)"},
    "taraf_al_lisan_reh": {"letters": "ر", "en": "Tongue tip (ra)"},
    "taraf_al_lisan_tdt": {"letters": "ط د ت", "en": "Tongue tip and incisor roots"},
    "taraf_al_lisan_szs": {"letters": "ص ز س", "en": "Tongue tip between the incisors"},
    "taraf_al_lisan_thdhz": {"letters": "ظ ذ ث", "en": "Tongue tip and incisor tips"},
    "batn_ush_shafah": {"letters": "ف", "en": "Inside of the lower lip"},
    "ash_shafatain": {"letters": "ب م و", "en": "Both lips"},
}


@dataclass(frozen=True)
class TajweedWord:
    surah: int
    ayah: int
    word_index: int          # 1-based, Basmala excluded
    word_ar: str
    word_tr: str
    makhraj: str
    makhraj_set: str
    has_ghunnah: bool
    has_shaddah: bool
    has_madd: bool
    has_qalqalah: bool
    has_tafkheem: bool
    madd_length: int         # prescribed harakat: 0, 2, 4 or 6
    qalqalah_class: str | None
    ghunnah_type: str | None
    tafkheem_class: str | None
    n_phones: int

    @property
    def makhraj_letters(self) -> str:
        return MAKHRAJ_LABELS.get(self.makhraj, {}).get("letters", "")

    @property
    def makhraj_english(self) -> str:
        return MAKHRAJ_LABELS.get(self.makhraj, {}).get("en", self.makhraj)

    @property
    def rules(self) -> list[str]:
        """The rule names that apply to this word, for chips or a summary."""
        applicable = []
        if self.has_ghunnah:
            applicable.append("ghunnah")
        if self.has_shaddah:
            applicable.append("shaddah")
        if self.has_madd:
            applicable.append("madd")
        if self.has_qalqalah:
            applicable.append("qalqalah")
        if self.has_tafkheem:
            applicable.append("tafkheem")
        return applicable


class TajweedReference:
    """Read-only lookup over the extracted asset.

    SQLite rather than parquet on purpose: it is in the standard library, so
    this carries no pandas or pyarrow version risk -- which has already bitten
    this project once, when two halves of the pipeline disagreed about librosa.
    """

    def __init__(self, db_path: Path = DB_PATH):
        self._db_path = db_path
        self._available = db_path.is_file()
        if self._available:
            # check_same_thread=False: FastAPI serves from a thread pool and
            # every query here is a read.
            self._connection = sqlite3.connect(str(db_path), check_same_thread=False)
            self._connection.row_factory = sqlite3.Row
        else:
            self._connection = None

    @property
    def available(self) -> bool:
        return self._available

    @lru_cache(maxsize=8192)
    def word(self, surah: int, ayah: int, word_index: int) -> TajweedWord | None:
        """One word by its *reference* index (1-based, no Basmala)."""
        if not self._available:
            return None
        row = self._connection.execute(
            "SELECT * FROM tajweed_word WHERE surah=? AND ayah=? AND word_index=?",
            (int(surah), int(ayah), int(word_index)),
        ).fetchone()
        if row is None:
            return None
        return TajweedWord(
            surah=row["surah"], ayah=row["ayah"], word_index=row["word_index"],
            word_ar=row["word_ar"], word_tr=row["word_tr"],
            makhraj=row["makhraj"], makhraj_set=row["makhraj_set"],
            has_ghunnah=bool(row["has_ghunnah"]), has_shaddah=bool(row["has_shaddah"]),
            has_madd=bool(row["has_madd"]), has_qalqalah=bool(row["has_qalqalah"]),
            has_tafkheem=bool(row["has_tafkheem"]),
            madd_length=row["madd_length"],
            qalqalah_class=row["qalqalah_class"] or None,
            ghunnah_type=row["ghunnah_type"] or None,
            tafkheem_class=row["tafkheem_class"] or None,
            n_phones=row["n_phones"],
        )

    def word_for_display(self, surah: int, ayah: int, display_index: int,
                         prefix_len: int | None = None) -> TajweedWord | None:
        """One word by the index the *app* uses (0-based, Basmala included).

        Returns None for a Basmala word: those belong to no ayah of this surah
        in the reference, and quietly mapping them onto word 1 would attach the
        wrong Tajweed to the wrong word.
        """
        prefix = basmala_prefix_len(surah, ayah) if prefix_len is None else prefix_len
        reference_index = display_index - prefix + 1
        if reference_index < 1:
            return None
        return self.word(surah, ayah, reference_index)

    def ayah(self, surah: int, ayah: int) -> list[TajweedWord]:
        """Every word of one ayah, in order."""
        if not self._available:
            return []
        rows = self._connection.execute(
            "SELECT word_index FROM tajweed_word WHERE surah=? AND ayah=? "
            "ORDER BY word_index", (int(surah), int(ayah))).fetchall()
        words = [self.word(surah, ayah, r["word_index"]) for r in rows]
        return [w for w in words if w is not None]

    def words_with_rule(self, rule: str, limit: int = 50,
                        surah: int | None = None) -> list[TajweedWord]:
        """Examples of a rule, for the Tajweed rules screen.

        Lets a rule be taught with real words from the Quran rather than a
        hand-written example list.
        """
        column = {
            "ghunnah": "has_ghunnah", "shaddah": "has_shaddah", "madd": "has_madd",
            "qalqalah": "has_qalqalah", "tafkheem": "has_tafkheem",
        }.get(rule)
        if not self._available or column is None:
            return []
        query = f"SELECT surah, ayah, word_index FROM tajweed_word WHERE {column}=1"
        parameters: list[int] = []
        if surah is not None:
            query += " AND surah=?"
            parameters.append(int(surah))
        query += " ORDER BY surah, ayah, word_index LIMIT ?"
        parameters.append(int(limit))
        rows = self._connection.execute(query, parameters).fetchall()
        words = [self.word(r["surah"], r["ayah"], r["word_index"]) for r in rows]
        return [w for w in words if w is not None]
