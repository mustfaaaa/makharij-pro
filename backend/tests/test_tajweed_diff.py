"""Unit tests for tajweed_diff -- the phoneme-run classifier that decides
*which* Tajweed rule a word broke, and whether it broke one at all.

These need no model weights and no audio: they pin the tolerance behaviour
that keeps a professional Qari's recitation from being reported as full of
mistakes, which is the failure mode that makes every other verdict on the
results screen untrustworthy.
"""
import sys
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
