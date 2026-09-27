"""Unit tests for tajweed_diff -- the phoneme-run classifier that decides
*which* Tajweed rule a word broke, and whether it broke one at all.

These need no model weights and no audio: they pin the tolerance behaviour
that keeps a professional Qari's recitation from being reported as full of
mistakes, which is the failure mode that makes every other verdict on the
results screen untrustworthy.
"""
import sys

import pytest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app import tajweed_diff
from app.tajweed_diff import classify, summarize


def _types(findings):
    return [f.error_type for f in findings]


def test_identical_phonemes_produce_no_findings():
    assert classify("بِسْمِ", "بِسمِ", "بِسمِ") == []


def test_recognizer_madd_jitter_is_tolerated():
    # Measured on real audio: the recognizer transcribes Abdurrahmaan
    # As-Sudais's ٱلرَّحِيمِ with a 2-count madd where the reference sequence
    # says 4. Flagging that tells the user a Qari made a mistake.
    assert classify("ٱلرَّحِيمِ", "ررَحِۦۦۦۦم", "ررَحِۦۦم") == []


def test_dropped_madd_is_flagged_as_madd():
    findings = classify("ٱلرَّحِيمِ", "ررَحِۦۦۦۦم", "ررَحِم")
    assert tajweed_diff.MADD in _types(findings)


def test_grossly_wrong_madd_length_is_flagged():
    # 6 counts required, 1 held -- well past the recognizer's jitter band.
    findings = classify("وَلَا", "وَلَااااااا", "وَلَا")
    assert tajweed_diff.MADD in _types(findings)


def test_unpronounced_shaddah_is_flagged_as_shaddah():
    findings = classify("رَبِّ", "رَببِ", "رَبِ")
    assert tajweed_diff.SHADDAH in _types(findings)


def test_shortened_ghunnah_is_flagged_as_ghunnah():
    findings = classify("إِنَّ", "ءِننن", "ءِن")
    assert tajweed_diff.GHUNNAH in _types(findings)


def test_substituted_letter_is_flagged_as_makhraj():
    findings = classify("صِرَٰطَ", "صِرَااطَ", "سِرَااطَ")
    assert tajweed_diff.MAKHRAJ in _types(findings)


# Ikhfa: the noon/meem hidden into the next letter (ں / ۾ in the phoneme
# alphabet). Whether it is missing or said as a plain letter, it is the ikhfa
# that was not made -- reported under ghunnah, never as a makhraj mistake.

def test_ikhfa_heard_nowhere_is_flagged_as_ghunnah():
    findings = classify("مِن", "مِںںں", "مِ")
    assert _types(findings) == [tajweed_diff.GHUNNAH]


def test_ikhfa_said_as_a_plain_noon_is_flagged_as_ghunnah():
    # Measured on learner audio: مِن before ش read back as مِن, not مِںںں.
    findings = classify("مِن", "مِںںں", "مِن")
    assert _types(findings) == [tajweed_diff.GHUNNAH]
    assert "ikhfa" in findings[0].explanation and "“ن”" in findings[0].explanation


def test_ikhfa_said_as_a_plain_meem_is_flagged_as_ghunnah():
    # ۾ is a meem hidden before ب (iqlab here: نۢب), said as a clear meem.
    findings = classify("لَيُنۢبَذَنَّ", "لَيُ۾۾۾بَذَننننَ", "لَيُمبَذَننننَ")
    assert _types(findings) == [tajweed_diff.GHUNNAH]


def test_a_hidden_meem_heard_as_a_noon_stays_makhraj():
    # ۾ is both ikhfa shafawi (a meem) and iqlab (a noon made a hidden meem);
    # the alphabet cannot say which, so a clear noon there is not guessed to be
    # an unmade ikhfa.
    assert _types(classify("لَيُنۢبَذَنَّ", "لَيُ۾۾۾بَذَننننَ", "لَيُنبَذَننننَ")) == [tajweed_diff.MAKHRAJ]


def test_a_hidden_noon_heard_as_a_meem_stays_makhraj():
    # Measured on professional recitation: كُلٌّۭ فِي read back garbled as
    # كُللُهُم, which aligns the hidden noon onto the م of هُم. That is not an
    # ikhfa said plainly, and must not be explained as one.
    assert _types(classify("كُلٌّۭ", "كُللُںںں", "كُللُهُم")) == [tajweed_diff.MAKHRAJ]


def test_ikhfa_made_as_expected_is_not_flagged():
    assert classify("مِن", "مِںںں", "مِںںں") == []


# The whole decision table, one row per case: which category a word with this
# one difference is reported under.
DECISION_TABLE = [
    # (word, expected, heard, category or None for "not flagged")
    ("مِن", "مِںںں", "مِں", None),                        # ikhfa made (length is not judged)
    ("مِن", "مِںںں", "مِ", tajweed_diff.GHUNNAH),          # ikhfa noon heard nowhere
    ("مِن", "مِںںں", "مِن", tajweed_diff.GHUNNAH),         # ikhfa noon -> plain noon
    ("أَم بِ", "ءَ۾۾۾بِ", "ءَمبِ", tajweed_diff.GHUNNAH),   # ikhfa meem -> plain meem
    ("أَم بِ", "ءَ۾۾۾بِ", "ءَبِ", tajweed_diff.GHUNNAH),    # ikhfa meem heard nowhere
    ("مِن", "مِںںں", "مِم", tajweed_diff.MAKHRAJ),         # ikhfa noon -> meem: another letter
    ("مِن", "مِںںں", "مِل", tajweed_diff.MAKHRAJ),         # ikhfa -> unrelated letter
    ("أَم بِ", "ءَ۾۾۾بِ", "ءَنبِ", tajweed_diff.MAKHRAJ),   # ikhfa meem -> noon: not guessed
    ("أَم بِ", "ءَ۾۾۾بِ", "ءَلبِ", tajweed_diff.MAKHRAJ),   # ikhfa meem -> unrelated letter
    ("نَعْبُدُ", "نَعبُدُ", "مَعبُدُ", tajweed_diff.MAKHRAJ),  # normal noon -> meem
    ("نَعْبُدُ", "نَعبُدُ", "لَعبُدُ", tajweed_diff.MAKHRAJ),  # normal noon -> other letter
    ("مَلِكِ", "مَلِكِ", "نَلِكِ", tajweed_diff.MAKHRAJ),    # normal meem -> noon
    ("مَلِكِ", "مَلِكِ", "بَلِكِ", tajweed_diff.MAKHRAJ),    # normal meem -> other letter
]


@pytest.mark.parametrize("word,expected,heard,category", DECISION_TABLE)
def test_ikhfa_decision_table(word, expected, heard, category):
    types = _types(classify(word, expected, heard))
    assert types == ([category] if category else [])


def test_a_garbled_word_with_an_unmade_ikhfa_is_still_reported_as_garbled():
    # Four or more differences: the word did not match, whatever else is in it.
    # ٱلْإِنسَٰنَ read back as رءِنكُتَ: the ikhfa said as a plain noon is one of
    # four differences, so the word is reported as not matching, not as ghunnah.
    findings = classify("ٱلْإِنسَٰنَ", "لءِںںںسَاانَ", "رءِنكُتَ")
    summary = summarize("ٱلْإِنسَٰنَ", findings)
    assert tajweed_diff.GHUNNAH in _types(findings)
    assert len(findings) >= tajweed_diff.GARBLED_FINDING_COUNT
    assert summary.error_type == tajweed_diff.MAKHRAJ and "didn’t match" in summary.explanation


def test_other_letter_substitutions_are_still_makhraj():
    # The ikhfa branch only claims a plain noon/meem in place of an ikhfa.
    assert _types(classify("مِن", "مِںںں", "مِل")) == [tajweed_diff.MAKHRAJ]
    assert _types(classify("صِرَٰطَ", "صِرَااطَ", "سِرَااطَ")) == [tajweed_diff.MAKHRAJ]
    assert _types(classify("نَعْبُدُ", "نَعبُدُ", "مَعبُدُ")) == [tajweed_diff.MAKHRAJ]


def test_word_never_heard_is_reported_as_skipped():
    findings = classify("مَـٰلِكِ", "مَاالِكِ", "")
    assert _types(findings) == [tajweed_diff.SKIPPED]


def test_diacritic_only_difference_does_not_flag_a_word():
    # Harakat differences are below the recognizer's reliable resolution.
    assert classify("نَعْبُدُ", "نَعبُدُ", "نُعبُدُ") == []


def test_summarize_returns_none_for_a_correct_word():
    assert summarize("بِسْمِ", []) is None


def test_summarize_prefers_the_named_rule_over_a_generic_makhraj():
    findings = [
        tajweed_diff.Finding(tajweed_diff.MAKHRAJ, "generic"),
        tajweed_diff.Finding(tajweed_diff.MADD, "specific"),
    ]
    assert summarize("word", findings).error_type == tajweed_diff.MADD


def test_summarize_collapses_a_garbled_word_instead_of_listing_every_letter():
    findings = [tajweed_diff.Finding(tajweed_diff.MAKHRAJ, f"letter {i}") for i in range(5)]
    summary = summarize("نَسْتَعِينُ", findings)
    assert "letter 0" not in summary.explanation
    assert "نَسْتَعِينُ" in summary.explanation


def test_summarize_reports_at_most_two_findings():
    findings = [
        tajweed_diff.Finding(tajweed_diff.MADD, "one."),
        tajweed_diff.Finding(tajweed_diff.SHADDAH, "two."),
        tajweed_diff.Finding(tajweed_diff.MAKHRAJ, "three."),
    ]
    assert summarize("word", findings).explanation == "one. two."
