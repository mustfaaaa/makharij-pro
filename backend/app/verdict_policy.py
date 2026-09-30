"""Confidence policy layered on top of phoneme-diff findings.

``makhraj`` is the generic bucket for any letter mismatch, including the
recogniser's own mistakes.  It is useful evidence to review, but not strong
enough to reduce a learner's score or train their practice plan.  Named rule
findings are confirmed on clean audio; on degraded audio they are confirmed
only when the original and conservatively enhanced decodes agree.
"""

from __future__ import annotations

CORRECT = "correct"
CONFIRMED_ERROR = "confirmed_error"
NEEDS_REVIEW = "needs_review"
UNJUDGED = "unjudged"


def status_of(result) -> str:
    explicit = getattr(result, "review_status", None)
    if explicit in {CORRECT, CONFIRMED_ERROR, NEEDS_REVIEW, UNJUDGED}:
        return explicit
    if not result.recited:
        return UNJUDGED
    if result.correct:
        return CORRECT
    if result.error_type == "makhraj":
        # One generic letter mismatch is exactly where recogniser noise lands.
        # Several independent findings are stronger evidence and should not be
        # silently removed from progress.
        return (CONFIRMED_ERROR
                if (getattr(result, "evidence_count", 0) or 0) >= 2
                else NEEDS_REVIEW)
    return CONFIRMED_ERROR


def counts_toward_score(result) -> bool:
    return status_of(result) in {CORRECT, CONFIRMED_ERROR}


def apply_second_pass_consensus(primary: list, comparison: list) -> list:
    """Annotate primary results using a second decode of the same recording.

    Primary timings and findings remain the response's source of truth.  The
    second pass can only lower certainty; it never creates a new flag that the
    original recording did not contain.
    """
    other = {
        (r.surah_number, r.ayah_number, r.word_index): r
        for r in comparison
    }
    for result in primary:
        if not result.recited:
            result.review_status = UNJUDGED
            continue
        if result.correct:
            result.review_status = CORRECT
            continue
        if result.error_type == "makhraj":
            match = other.get((result.surah_number, result.ayah_number, result.word_index))
            agrees = (
                match is not None
                and match.recited
                and not match.correct
                and match.error_type == "makhraj"
                and (getattr(result, "evidence_count", 0) or 0) >= 2
                and (getattr(match, "evidence_count", 0) or 0) >= 2
            )
            result.review_status = CONFIRMED_ERROR if agrees else NEEDS_REVIEW
            continue

        match = other.get((result.surah_number, result.ayah_number, result.word_index))
        agrees = (
            match is not None
            and match.recited
            and not match.correct
            and match.error_type == result.error_type
        )
        result.review_status = CONFIRMED_ERROR if agrees else NEEDS_REVIEW
    return primary
