"""FR-8/BR-5: reciting a flagged passage again, at word granularity.

The requirement is "let the reciter correct what they got wrong". The rule that
makes that true rather than merely plausible is the one pinned hardest here: a
word the session already called correct cannot be turned into a mistake by a
later recording. Without it, a user who re-records one bad word and fumbles a
good one beside it ends up with a worse score for having tried -- which is the
opposite of what the requirement asks for, and the kind of thing that is
obvious in a sentence and invisible in a diff.

The other rule worth pinning: the per-word phoneme record is evidence for the
correction loop, not a scoreboard. A first attempt that was wrongly flagged is
the single most valuable row in it, so a re-attempt must not overwrite it.
"""
import sys
from dataclasses import dataclass
from pathlib import Path
from unittest.mock import patch

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app import firestore_service  # noqa: E402


@dataclass
class FakeResult:
    """Just the fields apply_reattempt reads off a WordPhonemeResult."""
    ayah_number: int
    word_index: int
    display_word: str
    recited: bool = True
    correct: bool = True
    error_type: str | None = None
    explanation: str = ""


class FakeDoc:
    def __init__(self, data):
        self._data = data
        self.exists = data is not None
        self.updates = []

    def to_dict(self):
        return dict(self._data)

    def get(self):
        return self

    def update(self, patch_):
        self.updates.append(patch_)
        self._data.update(patch_)

    def collection(self, _name):
        return self

    def document(self, _id=None):
        return self


def a_session(**overrides):
    """A session with three recited words, two of them flagged."""
    data = {
        "surahNumber": 112,
        "fromAyah": 1,
        "toAyah": 1,
        "wordsRecited": 3,
        "wordsCorrect": 1,
        "accuracyScore": 0.3333,
        "mistakes": [
            {"ayahNumber": 1, "wordIndex": 0, "word": "قُلْ",
             "errorType": "makhraj", "explanation": "first take"},
            {"ayahNumber": 1, "wordIndex": 2, "word": "ٱللَّهُ",
             "errorType": "madd", "explanation": "first take"},
        ],
        "mistakeCounts": {"makhraj": 1, "madd": 1, "ghunnah": 0, "shaddah": 0},
        # The label evidence. Note word 1 is recorded as correct.
        "words": [
            {"ayahNumber": 1, "wordIndex": 0, "word": "قُلْ", "correct": False,
             "errorType": "makhraj", "predicted": "قل", "expected": "قُل"},
            {"ayahNumber": 1, "wordIndex": 1, "word": "هُوَ", "correct": True,
             "errorType": None, "predicted": "هُوَ", "expected": "هُوَ"},
            {"ayahNumber": 1, "wordIndex": 2, "word": "ٱللَّهُ", "correct": False,
             "errorType": "madd", "predicted": "للَاه", "expected": "للَااهُ"},
        ],
    }
    data.update(overrides)
    return FakeDoc(data)


@pytest.fixture
def session():
    doc = a_session()
    with patch.object(firestore_service, "get_firestore_client", return_value=doc):
        yield doc


def test_a_corrected_word_leaves_the_mistake_list(session):
    out = firestore_service.apply_reattempt("uid", "sess", [
        FakeResult(1, 0, "قُلْ", correct=True),
        FakeResult(1, 1, "هُوَ", correct=True),
        FakeResult(1, 2, "ٱللَّهُ", correct=False, error_type="madd"),
    ])

    assert [c["wordIndex"] for c in out["corrected"]] == [0]
    assert [m["wordIndex"] for m in session._data["mistakes"]] == [2]
    assert out["words_correct"] == 2
    assert out["accuracy_score"] == pytest.approx(2 / 3, abs=1e-4)


def test_a_word_already_correct_cannot_be_turned_into_a_mistake(session):
    """The rule the whole requirement rests on: trying again never costs you a
    word you had already got right."""
    out = firestore_service.apply_reattempt("uid", "sess", [
        FakeResult(1, 0, "قُلْ", correct=True),
        # The second take fumbles a word the first take got right.
        FakeResult(1, 1, "هُوَ", correct=False, error_type="makhraj"),
        FakeResult(1, 2, "ٱللَّهُ", correct=False, error_type="madd"),
    ])

    flagged = {m["wordIndex"] for m in session._data["mistakes"]}
    assert 1 not in flagged, "a word that was correct must stay correct"
    assert out["words_correct"] == 2
    # Not merely absent from the mistake list: the re-attempt must not have
    # considered it at all. Reporting it under `still_wrong`, or counting an
    # attempt against it, would both leak the second take's fumble into a
    # record the first take had already settled.
    assert 1 not in {w["wordIndex"] for w in out["still_wrong"]}
    assert "1:1" not in session._data["attemptCounts"]
    assert "1:1" not in session._data["hadMultipleAttempts"]


def test_the_per_word_label_record_is_never_overwritten(session):
    before = [dict(w) for w in session._data["words"]]
    firestore_service.apply_reattempt("uid", "sess", [
        FakeResult(1, 0, "قُلْ", correct=True),
        FakeResult(1, 2, "ٱللَّهُ", correct=True),
    ])
    assert session._data["words"] == before
    assert "words" not in session.updates[-1]


def test_a_still_wrong_word_gets_the_new_attempts_explanation(session):
    out = firestore_service.apply_reattempt("uid", "sess", [
        FakeResult(1, 0, "قُلْ", correct=False, error_type="shaddah",
                   explanation="second take"),
    ])

    entry = next(m for m in session._data["mistakes"] if m["wordIndex"] == 0)
    assert entry["errorType"] == "shaddah"
    assert entry["explanation"] == "second take"
    assert out["still_wrong"][0]["wordIndex"] == 0


def test_mistake_counts_follow_the_corrected_list(session):
    firestore_service.apply_reattempt("uid", "sess", [
        FakeResult(1, 2, "ٱللَّهُ", correct=True),
    ])
    counts = session._data["mistakeCounts"]
    assert counts["madd"] == 0
    assert counts["makhraj"] == 1


def test_a_flagged_word_the_retake_never_reached_keeps_its_verdict(session):
    """Stopping short is not a correction, and must not count as an attempt."""
    out = firestore_service.apply_reattempt("uid", "sess", [
        FakeResult(1, 0, "قُلْ", correct=True),
        FakeResult(1, 2, "ٱللَّهُ", recited=False),
    ])

    assert [n["wordIndex"] for n in out["not_reached"]] == [2]
    assert {m["wordIndex"] for m in session._data["mistakes"]} == {2}
    assert "1:2" not in session._data["attemptCounts"]


def test_attempt_counts_and_weak_area_flag(session):
    firestore_service.apply_reattempt("uid", "sess", [
        FakeResult(1, 0, "قُلْ", correct=True),
        FakeResult(1, 2, "ٱللَّهُ", correct=True),
    ])
    assert session._data["attemptCounts"] == {"1:0": 2, "1:2": 2}
    # BR-5: a corrected word still counts as a weak area for the practice plan.
    assert session._data["hadMultipleAttempts"] == ["1:0", "1:2"]


def test_a_corrected_word_stays_a_weak_area_but_stops_being_re_attemptable(session):
    """Once fixed, a word leaves the mistake list -- so a second re-attempt has
    nothing to do to it. What it does not leave is `hadMultipleAttempts`: BR-5
    wants the practice plan (FR-14) to keep treating it as weak even after a
    successful correction."""
    firestore_service.apply_reattempt("uid", "sess", [
        FakeResult(1, 0, "قُلْ", correct=True)])
    assert session._data["attemptCounts"]["1:0"] == 2

    firestore_service.apply_reattempt("uid", "sess", [
        FakeResult(1, 0, "قُلْ", correct=False, error_type="makhraj")])

    # The word is no longer flagged, so the second take cannot re-open it --
    # and cannot un-correct it either.
    assert session._data["attemptCounts"]["1:0"] == 2
    assert 0 not in {m["wordIndex"] for m in session._data["mistakes"]}
    assert "1:0" in session._data["hadMultipleAttempts"]


def test_scope_limits_the_retake_to_one_word(session):
    firestore_service.apply_reattempt("uid", "sess", [
        FakeResult(1, 0, "قُلْ", correct=True),
        FakeResult(1, 2, "ٱللَّهُ", correct=True),
    ], scope=(1, 0))

    # Word 2 was correct in the new audio too, but out of scope: untouched.
    assert {m["wordIndex"] for m in session._data["mistakes"]} == {2}
    assert list(session._data["attemptCounts"]) == ["1:0"]


def test_scope_of_a_whole_ayah(session):
    firestore_service.apply_reattempt("uid", "sess", [
        FakeResult(1, 0, "قُلْ", correct=True),
        FakeResult(1, 2, "ٱللَّهُ", correct=True),
    ], scope=(1, None))
    assert session._data["mistakes"] == []


def test_each_reattempt_is_appended_to_the_history(session):
    firestore_service.apply_reattempt("uid", "sess", [
        FakeResult(1, 0, "قُلْ", correct=True)])
    firestore_service.apply_reattempt("uid", "sess", [
        FakeResult(1, 2, "ٱللَّهُ", correct=True)])

    history = session._data["reattempts"]
    assert len(history) == 2
    assert [h["corrected"][0]["wordIndex"] for h in history] == [0, 2]


def test_a_session_with_nothing_flagged_is_rejected():
    doc = a_session(mistakes=[], mistakeCounts={})
    with patch.object(firestore_service, "get_firestore_client", return_value=doc):
        with pytest.raises(ValueError, match="no flagged words"):
            firestore_service.apply_reattempt("uid", "sess", [
                FakeResult(1, 0, "قُلْ", correct=True)])


def test_a_scope_with_nothing_flagged_is_rejected(session):
    with pytest.raises(ValueError, match="no flagged words"):
        firestore_service.apply_reattempt("uid", "sess", [
            FakeResult(1, 1, "هُوَ", correct=True)], scope=(1, 1))


def test_an_unknown_session_is_not_found():
    doc = FakeDoc(None)
    with patch.object(firestore_service, "get_firestore_client", return_value=doc):
        with pytest.raises(KeyError):
            firestore_service.apply_reattempt("uid", "nope", [])


def test_accuracy_never_exceeds_one(session):
    """wordsRecited is the first attempt's denominator; corrections must not
    push the numerator past it."""
    out = firestore_service.apply_reattempt("uid", "sess", [
        FakeResult(1, 0, "قُلْ", correct=True),
        FakeResult(1, 2, "ٱللَّهُ", correct=True),
    ])
    assert out["words_correct"] == 3
    assert out["accuracy_score"] == 1.0
