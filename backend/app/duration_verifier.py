"""Timestamp evidence for Madd and Ghunnah findings.

The phoneme recogniser may group repeated carriers into one token, so repeated
characters alone are not an independent duration measurement.  This extractor
keeps both signals: the expected/heard run lengths and the time occupied by the
recogniser token(s) carrying that run.  ``verification`` is deliberately
``inconclusive`` unless count direction and timestamp evidence agree.

These features are persisted for calibration against teacher-labelled words.
Until that calibration exists they explain/support a finding but never create
one by themselves.
"""

from __future__ import annotations

import math
from statistics import median

from .analysis_metadata import ANALYSIS_VERSION
from .tajweed_diff import ELONGATION_CHARS, IKHFA_CHARS, NASAL_CHARS, runs

DURATION_EVIDENCE_VERSION = "timestamp-duration-v1"


def _longest_run(text: str, target: frozenset[str]) -> tuple[int, int, int] | None:
    best = None
    start = 0
    while start < len(text):
        if text[start] not in target:
            start += 1
            continue
        end = start + 1
        while end < len(text) and text[end] == text[start]:
            end += 1
        candidate = (start, end, end - start)
        if best is None or candidate[2] > best[2]:
            best = candidate
        start = end
    return best


def _expected_count(text: str, target: frozenset[str]) -> int:
    return max((count for char, count in runs(text) if char in target), default=0)


def build(rule: str | None, expected: str, predicted: str,
          predicted_token_ids: list[int], token_times: list[float]) -> dict | None:
    if rule == "madd":
        target = ELONGATION_CHARS
        tolerance = 2
    elif rule == "ghunnah":
        target = NASAL_CHARS | IKHFA_CHARS
        tolerance = 2
    else:
        return None

    expected_count = _expected_count(expected, target)
    found = _longest_run(predicted, target)
    heard_count = found[2] if found else 0

    positive_steps = [
        float(b - a) for a, b in zip(token_times, token_times[1:])
        if math.isfinite(a) and math.isfinite(b) and b > a
    ]
    typical_step = median(positive_steps) if positive_steps else 0.04
    segment_sec = 0.0
    acoustic_units = 0.0
    if found and predicted_token_ids and token_times:
        begin, end, _ = found
        ids = sorted(set(predicted_token_ids[begin:end]))
        ids = [i for i in ids if 0 <= i < len(token_times)]
        if ids:
            first, last = ids[0], ids[-1]
            after = float(token_times[last + 1]) if last + 1 < len(token_times) else float(token_times[last]) + typical_step
            segment_sec = max(0.0, after - float(token_times[first]))
            acoustic_units = segment_sec / typical_step if typical_step > 0 else 0.0

    if heard_count < expected_count - tolerance:
        direction = "short"
    elif heard_count > expected_count + tolerance:
        direction = "long"
    else:
        direction = "within_tolerance"

    verification = "inconclusive"
    if direction == "short" and acoustic_units < max(1.5, expected_count - tolerance):
        verification = "supports_short"
    elif direction == "long" and acoustic_units > expected_count + tolerance:
        verification = "supports_long"
    elif direction != "within_tolerance" and acoustic_units >= max(1.0, expected_count - tolerance):
        verification = "timestamp_disagrees"

    return {
        "version": DURATION_EVIDENCE_VERSION,
        "analysisVersion": ANALYSIS_VERSION,
        "rule": rule,
        "expectedCount": expected_count,
        "heardCount": heard_count,
        "segmentMs": round(segment_sec * 1000.0, 1),
        "localTokenStepMs": round(typical_step * 1000.0, 1),
        "acousticUnits": round(acoustic_units, 2),
        "direction": direction,
        "verification": verification,
        "decisionActive": False,
    }
