"""Pins how verdicts are worded.

Measured on 773 labelled learner recordings, the detector wrongly flags roughly
two correct recitations in five (ml/eval/README.md). At that rate, a verdict
phrased as a statement about the reciter -- "you skipped this", "the madd was
too short" -- is a false accusation almost half the time, and it teaches the
reciter to "fix" something that was already right.

So every explanation reports what the app *heard* against what was *expected*,
and hands the judgement back to the reciter. That is not a stylistic preference;
it is the only honest register available at this accuracy, and it is easy to
undo one careless edit at a time. Hence these tests.
"""
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.tajweed_diff import classify, summarize

# Phrasings that assert what the reciter did, rather than what was heard.
ACCUSATORY = [
    "you skipped",
    "was not recited",
    "was not pronounced",
    "was not held",
    "was not applied",
    "was missing",
    "was too short",
    "was too long",
    "did not match",
    "must be doubled",
    "must sound doubled",
    "you must",
    "you failed",
    "incorrect",
    "wrong",
]

# Every wording should offer the reciter a way to check for themselves.
INVITATIONS = ["listen back", "did you recite", "try it again"]

CASES = [
    ("madd dropped", "ٱلرَّحِيمِ", "ررَحِۦۦۦۦم", "ررَحِم"),
    ("madd short", "ٱلرَّحِيمِ", "ررَحِۦۦۦۦم", "ررَحِۦم"),
    ("ghunnah short", "إِنَّ", "ءِننن", "ءِن"),
    ("shaddah", "رَبِّ", "رَببِ", "رَبِ"),
    ("makhraj", "صِرَٰطَ", "صِرَااطَ", "سِرَااطَ"),
    ("skipped", "مَٰلِكِ", "مَاالِكِ", ""),
    ("garbled", "نَسْتَعِينُ", "نَستَعِۦۦۦۦن", "بَقتُفِم"),
]


@pytest.mark.parametrize("name,word,expected,predicted", CASES)
def test_verdict_does_not_accuse_the_reciter(name, word, expected, predicted):
    verdict = summarize(word, classify(word, expected, predicted))
    assert verdict is not None, f"{name} should produce a verdict"

    lowered = verdict.explanation.lower()
    for phrase in ACCUSATORY:
        assert phrase not in lowered, (
            f"{name}: verdict states a mistake as fact ({phrase!r}) — "
            f"at a 43% false-alarm rate that is an accusation, not a report.\n"
            f"  {verdict.explanation}"
        )


@pytest.mark.parametrize("name,word,expected,predicted", CASES)
def test_verdict_invites_the_reciter_to_judge(name, word, expected, predicted):
    verdict = summarize(word, classify(word, expected, predicted))
    lowered = verdict.explanation.lower()
    assert any(hint in lowered for hint in INVITATIONS), (
        f"{name}: verdict gives the reciter no way to check it themselves.\n"
        f"  {verdict.explanation}"
    )


@pytest.mark.parametrize("name,word,expected,predicted", CASES)
def test_verdict_names_the_word_it_is_about(name, word, expected, predicted):
    verdict = summarize(word, classify(word, expected, predicted))
    assert word in verdict.explanation, f"{name}: verdict doesn't say which word"


def test_a_correct_word_says_nothing_at_all():
    assert summarize("بِسْمِ", classify("بِسْمِ", "بِسمِ", "بِسمِ")) is None


def test_length_verdicts_report_both_numbers():
    """Expected against heard, so the reciter can weigh it rather than take it
    on trust."""
    verdict = summarize("ٱلرَّحِيمِ", classify("ٱلرَّحِيمِ", "ررَحِۦۦۦۦم", "ررَحِۦم"))
    assert "4" in verdict.explanation, "should say how many counts are expected"
    assert "1" in verdict.explanation, "should say how many came through"
