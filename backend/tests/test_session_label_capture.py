"""Phase 0 of the correction loop: a session must store enough about each word
for a later "I said it right" to become a usable label.

Before this, a session kept only aggregate counts and the flagged words'
coordinates. A reciter's disagreement was then a coordinate with nothing beside
it -- no way to tell a word the model systematically over-flags from a learner
who does not know the rule. These tests pin what the session now keeps: the
model's own claim and the phoneme features, for correct words as well as
flagged ones, bounded so a long surah cannot blow past Firestore's document
limit while never dropping a word the reciter could dispute.
"""
import sys
from dataclasses import dataclass
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app import firestore_service  # noqa: E402


@dataclass
class FakeResult:
    ayah_number: int
    word_index: int
    display_word: str
    predicted_phonemes: str
    expected_phonemes: str
    edit_distance: int
    confidence: float
    correct: bool
    recited: bool
    error_type: str | None
    explanation: str | None


def _word(ayah, idx, *, correct, recited=True, error_type=None):
    return FakeResult(
        ayah_number=ayah,
        word_index=idx,
        display_word=f"w{ayah}.{idx}",
        predicted_phonemes="baa" if correct else "taa",
        expected_phonemes="baa",
        edit_distance=0 if correct else 3,
        confidence=0.9 if correct else 0.4,
        correct=correct,
        recited=recited,
        error_type=error_type if not correct else None,
        explanation=None if correct else "say it longer",
    )


def test_stores_the_model_claim_and_features_for_a_flagged_word():
    results = [_word(1, 0, correct=False, error_type="madd")]
    words = firestore_service.word_verdicts_for_storage(results)

    assert len(words) == 1
    w = words[0]
    # The claim: what the model said about the word...
    assert w["correct"] is False
    assert w["errorType"] == "madd"
    # ...and the features that let a dispute be weighed rather than trusted.
    assert w["predicted"] == "taa"
    assert w["expected"] == "baa"
    assert w["distance"] == 3
    assert w["confidence"] == 0.4
    assert (w["ayahNumber"], w["wordIndex"]) == (1, 0)


def test_correct_words_are_kept_too_not_only_flagged():
    # A dispute can land on a word the model called correct (the reciter says it
    # was actually wrong -- the under-detection signal). If only flagged words
    # were stored, that dispute could never be reconstructed.
    results = [_word(1, 0, correct=True), _word(1, 1, correct=False, error_type="makhraj")]
    words = firestore_service.word_verdicts_for_storage(results)

    assert len(words) == 2
    assert words[0]["correct"] is True and words[0]["errorType"] is None


def test_unrecited_words_are_not_stored():
    # A word the reciter never reached carries no judgement to capture.
    results = [_word(1, 0, correct=True), _word(1, 1, correct=False, recited=False)]
    words = firestore_service.word_verdicts_for_storage(results)

    assert len(words) == 1
    assert words[0]["wordIndex"] == 0


def test_long_session_is_capped_but_keeps_every_flagged_word():
    cap = firestore_service.MAX_STORED_WORD_VERDICTS
    # More correct words than the cap, plus a handful of flagged ones scattered
    # through them.
    results = []
    flagged_positions = {5, 200, cap + 50, cap + 300}
    for i in range(cap + 400):
        results.append(_word(1, i, correct=i not in flagged_positions,
                             error_type="shaddah"))

    words = firestore_service.word_verdicts_for_storage(results)

    assert len(words) <= cap
    # Every flagged word survived the cap, including the two that sat past it.
    kept = {w["wordIndex"] for w in words if not w["correct"]}
    assert flagged_positions <= kept
    # Reading order is preserved, so a (ayah, word) coordinate still lines up.
    indices = [w["wordIndex"] for w in words]
    assert indices == sorted(indices)


def test_summary_carries_the_word_record():
    results = [_word(1, 0, correct=True), _word(1, 1, correct=False, error_type="ghunnah")]
    summary = firestore_service.summarize_word_results(results)

    assert "words" in summary
    assert len(summary["words"]) == 2
    # The existing stats fields are untouched.
    assert summary["wordsRecited"] == 2
    assert summary["wordsCorrect"] == 1
    assert summary["mistakeCounts"]["ghunnah"] == 1
