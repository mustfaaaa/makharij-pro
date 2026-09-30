import sys
from dataclasses import dataclass
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app import firestore_service, verdict_policy  # noqa: E402


@dataclass
class Result:
    ayah_number: int
    word_index: int
    display_word: str = "word"
    predicted_phonemes: str = "x"
    expected_phonemes: str = "y"
    start_sec: float = 0.0
    end_sec: float = 0.5
    correct: bool = False
    recited: bool = True
    edit_distance: int = 1
    confidence: float = 0.5
    error_type: str | None = "makhraj"
    explanation: str | None = "review"
    surah_number: int = 1
    review_status: str | None = None
    evidence_count: int = 1


def test_generic_makhraj_is_review_not_a_confirmed_error():
    result = Result(1, 0)
    assert verdict_policy.status_of(result) == verdict_policy.NEEDS_REVIEW
    assert not verdict_policy.counts_toward_score(result)


def test_multiple_makhraj_findings_are_strong_enough_to_confirm():
    result = Result(1, 0, evidence_count=2)
    assert verdict_policy.status_of(result) == verdict_policy.CONFIRMED_ERROR
    assert verdict_policy.counts_toward_score(result)


def test_review_word_is_visible_but_does_not_reduce_score():
    correct = Result(1, 0, correct=True, error_type=None)
    review = Result(1, 1, error_type="makhraj")
    summary = firestore_service.summarize_word_results([correct, review])

    assert summary["accuracyScore"] == 1.0
    assert summary["wordsRecited"] == 2
    assert summary["wordsJudged"] == 1
    assert summary["wordsNeedsReview"] == 1
    assert len(summary["mistakes"]) == 1
    assert summary["mistakes"][0]["reviewStatus"] == "needs_review"
    assert summary["mistakeCounts"]["makhraj"] == 0
    assert summary["reviewCounts"]["makhraj"] == 1


def test_named_rule_requires_agreement_on_degraded_audio():
    primary = Result(1, 0, error_type="madd")
    agrees = Result(1, 0, error_type="madd")
    verdict_policy.apply_second_pass_consensus([primary], [agrees])
    assert primary.review_status == verdict_policy.CONFIRMED_ERROR

    primary = Result(1, 0, error_type="madd")
    disagrees = Result(1, 0, correct=True, error_type=None)
    verdict_policy.apply_second_pass_consensus([primary], [disagrees])
    assert primary.review_status == verdict_policy.NEEDS_REVIEW


def test_multiple_makhraj_findings_still_need_second_pass_agreement_on_degraded_audio():
    primary = Result(1, 0, error_type="makhraj", evidence_count=2)
    weak_comparison = Result(1, 0, error_type="makhraj", evidence_count=1)
    verdict_policy.apply_second_pass_consensus([primary], [weak_comparison])
    assert primary.review_status == verdict_policy.NEEDS_REVIEW

    primary = Result(1, 0, error_type="makhraj", evidence_count=2)
    strong_comparison = Result(1, 0, error_type="makhraj", evidence_count=2)
    verdict_policy.apply_second_pass_consensus([primary], [strong_comparison])
    assert primary.review_status == verdict_policy.CONFIRMED_ERROR


def test_second_pass_never_creates_a_new_flag():
    primary = Result(1, 0, correct=True, error_type=None)
    comparison = Result(1, 0, error_type="ghunnah")
    verdict_policy.apply_second_pass_consensus([primary], [comparison])
    assert primary.correct
    assert primary.review_status == verdict_policy.CORRECT
