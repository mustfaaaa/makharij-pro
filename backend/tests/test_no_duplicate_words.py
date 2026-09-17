"""Every word of the requested range is reported exactly once.

The bug this pins
-----------------
Ayah 1 of a surah carries an optional Basmala. When the reciter does not say it,
the analyser drops it from the comparison -- but the list of words *after* the
analysed stretch was still indexed into the full word list by length alone,
which pointed four words too early. The closing words of the ayah were therefore
emitted twice: once with their real verdict, and again underneath as "never
recited".

On screen that is a word the reciter just said, shown greyed out directly below
itself. Across the whole Quran it made ayah 1 the worst-scoring ayah in the book:
every one of the forty worst ayahs was an ayah 1, which is precisely where a
Basmala can be dropped.

The invariant is simple enough to state without knowing any of that: an (ayah,
word index) pair appears once, and the words reported are exactly the words of
the range.
"""
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.phoneme_analysis_service import PhonemeAnalysisService  # noqa: E402

RECITATIONS = Path(__file__).resolve().parent.parent / "app" / "static" / "recitations"
QARI = "abdurrahmaan_as_sudais"

# Surahs whose ayah 1 the repository ships audio for, and which take a Basmala
# (so the prefix-dropping path is exercised). Surah 1 is excluded on purpose:
# there the Basmala *is* ayah 1, so nothing is ever dropped.
FIRST_AYAHS = [101, 103, 104, 107, 110, 112, 113, 114]


@pytest.fixture(scope="module")
def service():
    return PhonemeAnalysisService()


@pytest.mark.parametrize("surah", FIRST_AYAHS)
def test_first_ayah_reports_each_word_once(service, surah):
    clip = RECITATIONS / QARI / f"{surah:03d}001.mp3"
    if not clip.is_file():
        pytest.skip(f"no reference audio for surah {surah}")

    results = service.analyze_range(clip.read_bytes(), surah, 1, 1)

    seen = [(r.ayah_number, r.word_index) for r in results]
    assert len(seen) == len(set(seen)), (
        f"surah {surah} ayah 1 reported a word more than once: "
        f"{sorted(w for w in set(seen) if seen.count(w) > 1)}"
    )


@pytest.mark.parametrize("surah", FIRST_AYAHS)
def test_first_ayah_reports_exactly_the_words_of_the_ayah(service, surah):
    clip = RECITATIONS / QARI / f"{surah:03d}001.mp3"
    if not clip.is_file():
        pytest.skip(f"no reference audio for surah {surah}")

    results = service.analyze_range(clip.read_bytes(), surah, 1, 1)
    expected = service.expected_words(surah, 1) or []

    # Dropping the Basmala from the *comparison* must not drop it from the
    # *report* -- the reading page shows those words, so they have to come back
    # as "not recited" rather than vanish.
    assert len(results) == len(expected), (
        f"surah {surah} ayah 1: {len(results)} words reported, "
        f"{len(expected)} in the ayah"
    )
    assert [r.word_index for r in results] == list(range(len(expected)))


def test_a_mid_surah_range_is_unaffected(service):
    """The offset only exists where a Basmala can be dropped, so a range that
    does not start at ayah 1 is a control: it should have been correct before
    the fix and must stay correct after it."""
    clip = RECITATIONS / QARI / "112002.mp3"
    if not clip.is_file():
        pytest.skip("no reference audio")

    results = service.analyze_range(clip.read_bytes(), 112, 2, 2)
    seen = [(r.ayah_number, r.word_index) for r in results]
    assert len(seen) == len(set(seen))
    assert all(r.ayah_number == 2 for r in results)
