import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.duration_verifier import build  # noqa: E402


def test_non_duration_rule_has_no_evidence():
    assert build("makhraj", "abc", "adc", [0, 1, 2], [0.0, 0.1, 0.2]) is None


def test_short_madd_is_supported_by_short_timestamp_span():
    evidence = build(
        "madd",
        "ررَحِۦۦۦۦم",
        "ررَحِۦم",
        list(range(7)),
        [0.00, 0.08, 0.16, 0.24, 0.32, 0.40, 0.48, 0.56],
    )
    assert evidence["expectedCount"] == 4
    assert evidence["heardCount"] == 1
    assert evidence["direction"] == "short"
    assert evidence["verification"] == "supports_short"
    assert evidence["decisionActive"] is False


def test_grouped_token_uses_the_next_timestamp_for_duration():
    # All four carriers can be emitted as one recogniser token. Their occupied
    # time is then the gap to the next token, not zero.
    evidence = build(
        "madd",
        "بَااااب",
        "بَااااب",
        [0, 1, 2, 2, 2, 2, 3],
        [0.0, 0.08, 0.16, 0.48, 0.56],
    )
    assert evidence["heardCount"] == 4
    assert evidence["segmentMs"] > 0
    assert evidence["direction"] == "within_tolerance"


def test_ghunnah_uses_nasal_runs():
    evidence = build("ghunnah", "ءِننن", "ءِن", [0, 1, 2], [0.0, 0.07, 0.14, 0.21])
    assert evidence["expectedCount"] == 3
    assert evidence["heardCount"] == 1
    assert evidence["direction"] == "within_tolerance"  # current recogniser tolerance is +/-2
