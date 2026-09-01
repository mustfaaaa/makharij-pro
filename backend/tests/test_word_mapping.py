"""Unit tests for word_mapping -- the layer that puts the phoneme model's
phonetic units onto the words the app actually prints.

This is the piece that decided every word index in the app, and it was wrong
for two thirds of the Quran before it existed: the model's units only coincide
with written words for 2,121 of 6,236 ayahs, and Al-Fatihah happens to be
inside that minority, which is exactly why the app looked correct there and
nowhere else. So these tests measure the mapping over the whole Quran rather
than spot-checking a few ayahs.
"""
import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.word_mapping import WordMapper, split_phonemes_by_word

PHONEME_TABLE_PATH = (
    Path(__file__).resolve().parent.parent
    / "models_cache" / "quran-lab-zipformer" / "ordered_quran_phonemes.json"
)

pytestmark = pytest.mark.skipif(
    not PHONEME_TABLE_PATH.exists(),
    reason="phoneme reference table not downloaded",
)


@pytest.fixture(scope="module")
def table():
    with open(PHONEME_TABLE_PATH, encoding="utf-8") as f:
        return json.load(f)


@pytest.fixture(scope="module")
def mapper(table):
    return WordMapper(table)


def test_splitting_never_invents_or_loses_phonemes():
    words = ["بِسْمِ", "ٱللَّهِ"]
    parts = split_phonemes_by_word("بِسمِ للَااهِ", words)
    assert len(parts) == len(words)
    assert "".join(parts) == "بِسمِللَااهِ"


def test_a_word_with_no_sound_gets_no_phonemes():
    # Waqf marks are their own whitespace token in the text but are silent.
    parts = split_phonemes_by_word("ذَاالِكَ لكِتَاابُ", ["ذَٰلِكَ", "ۛ", "ٱلْكِتَٰبُ"])
    assert parts[1] == ""


# Arabic literals are never hand-typed in these tests. Retyping combining-mark
# sequences produces strings that look identical and compare unequal -- the
# exact footgun app/phoneme_text_norm.py documents -- so every expected value
# below is taken from the data itself.


def test_al_fatihah_ayah_one_maps_word_for_word(mapper, table):
    # 1:1 is one of the ayahs whose units already line up with its words, so
    # the mapping must leave it exactly as the source has it.
    words = mapper.words(1, 1)
    assert [d for d, _p in words] == mapper._text["1:1"].split()
    assert [p for _d, p in words] == table["1:1"]["aya_phonemes_list"]


def test_a_fused_unit_is_split_back_across_its_two_words(mapper, table):
    # 15:1 ends with وَقُرْءَانٍۢ مُّبِينٍۢ, two written words the phonemizer
    # fuses into one unit (idgham with ghunnah). Each word must still get its
    # own share of that unit.
    words = mapper.words(15, 1)
    fused_unit = table["15:1"]["aya_phonemes_list"][-1]
    last_two = [p for _d, p in words[-2:]]

    assert all(last_two), "a fused unit left one of its words with no phonemes"
    assert "".join(last_two) == fused_unit


def test_muqattaat_letters_collapse_into_their_single_written_word(mapper, table):
    # الٓر is spelled out as three units (ءَلِف / لَاااااام / رَاا) but is a
    # single written word -- the opposite direction of the fusion above. It
    # sits right after the four Basmala words the asset prepends.
    words = mapper.words(15, 1)
    spelled_out = "".join(table["15:1"]["aya_phonemes_list"][:3])

    assert words[4][1] == spelled_out


def test_ayah_one_gets_the_basmala_the_app_prints_above_it(mapper):
    words = mapper.words(112, 1)
    basmala_words = mapper._text["1:1"].split()

    assert [d for d, _p in words][: len(basmala_words)] == basmala_words
    assert mapper.basmala_prefix_len(112, 1) == len(basmala_words)


@pytest.mark.parametrize("surah", [1, 9])
def test_surahs_without_a_prepended_basmala_get_no_prefix(mapper, surah):
    # Al-Fatihah's Basmala is its own ayah 1; At-Tawbah has none at all.
    assert mapper.basmala_prefix_len(surah, 1) == 0


def test_prefix_only_applies_to_the_first_ayah(mapper):
    assert mapper.basmala_prefix_len(112, 2) == 0


def test_every_ayah_maps_without_dropping_a_single_phoneme(mapper, table):
    """The whole-Quran guarantee: no phoneme character is lost or duplicated."""
    checked = 0
    for key, entry in table.items():
        surah, ayah = (int(x) for x in key.split(":"))
        words = mapper.words(surah, ayah)
        assert words, f"no mapping for {key}"

        expected = "".join(entry["aya_phonemes_list"])
        if ayah == 1 and surah not in (1, 9):
            expected = "".join(table["1:1"]["aya_phonemes_list"]) + expected

        assert "".join(p for _d, p in words) == expected, f"phonemes altered for {key}"
        checked += 1
    assert checked == 6236


def test_word_counts_match_the_text_the_app_renders(mapper, table):
    """Each mapped entry is one displayed word -- this is what makes a word
    index mean the same thing on both sides."""
    for key in table:
        surah, ayah = (int(x) for x in key.split(":"))
        words = mapper.words(surah, ayah)
        assert len(words) == len(mapper._text[key].split()), f"word count differs for {key}"
