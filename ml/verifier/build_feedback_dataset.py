"""Turn exported MakharijPro sessions into verifier-training JSONL.

Input is a JSON array of session dictionaries, or ``{"sessions": [...]}``.
It is intentionally an offline step: exporting Firestore remains an owner
operation and this script never embeds Firebase credentials or user audio.

Each row is one learner feedback event joined to the exact model claim and
diagnostic features saved with that session.  ``target_model_flag_correct`` is
1 when the learner agreed with the flag and 0 for "I said it right".  Because
that is self-report rather than teacher ground truth, ``verified`` remains a
separate field and training/evaluation code must not silently treat the two as
equivalent.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


RULES = ("madd", "ghunnah", "shaddah", "makhraj", "skipped")


def _anonymous_group(value: str, salt: str) -> str:
    return hashlib.sha256(f"{salt}:{value}".encode("utf-8")).hexdigest()[:16]


def rows_from_sessions(sessions: list[dict], *, salt: str = "makharijpro") -> list[dict]:
    rows: list[dict] = []
    for session in sessions:
        session_id = str(session.get("session_id") or session.get("id") or "")
        raw_user = str(session.get("user_id") or session.get("uid") or session_id)
        default_surah = session.get("surahNumber")
        words = session.get("words") or []
        by_position = {
            (w.get("surahNumber", default_surah), w.get("ayahNumber"), w.get("wordIndex")): w
            for w in words
        }
        for feedback in session.get("wordFeedback") or []:
            position = (
                feedback.get("surahNumber", default_surah),
                feedback.get("ayahNumber"),
                feedback.get("wordIndex"),
            )
            word = feedback.get("wordSnapshot") or by_position.get(position)
            if not word or feedback.get("agreed") is None:
                continue
            expected = str(word.get("expected") or "")
            predicted = str(word.get("predicted") or "")
            expected_len = max(len(expected), 1)
            quality = feedback.get("audioQuality") or session.get("audioQuality") or {}
            duration = word.get("durationEvidence") or {}
            rule = word.get("errorType") or ""
            rows.append({
                "group_id": _anonymous_group(raw_user, salt),
                "session_id": session_id,
                "surah": position[0],
                "ayah": position[1],
                "word_index": position[2],
                "target_model_flag_correct": 1 if feedback["agreed"] else 0,
                "source": feedback.get("source", "learner_self_report"),
                "verified": bool(feedback.get("verified", False)),
                "analysis_version": feedback.get("analysisVersion") or session.get("analysisVersion"),
                "model_id": feedback.get("modelId") or session.get("modelId"),
                "rule": rule,
                "rule_one_hot": {name: int(rule == name) for name in RULES},
                "confidence": float(word.get("confidence") or 0.0),
                "edit_distance": float(word.get("distance") or 0.0),
                "distance_ratio": float(word.get("distance") or 0.0) / expected_len,
                "expected_length": len(expected),
                "predicted_length": len(predicted),
                "length_ratio": len(predicted) / expected_len,
                "review_status": word.get("reviewStatus"),
                "audio_quality_status": quality.get("status"),
                "estimated_snr_db": quality.get("estimated_snr_db"),
                "clipping_ratio": quality.get("clipping_ratio"),
                "speech_ratio": quality.get("speech_ratio"),
                "duration_expected_count": duration.get("expectedCount"),
                "duration_heard_count": duration.get("heardCount"),
                "duration_segment_ms": duration.get("segmentMs"),
                "duration_acoustic_units": duration.get("acousticUnits"),
                "duration_verification": duration.get("verification"),
            })
    return rows


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path, help="Exported sessions JSON")
    parser.add_argument("output", type=Path, help="Destination JSONL")
    parser.add_argument("--salt", default="makharijpro", help="Local anonymisation salt")
    args = parser.parse_args()

    loaded = json.loads(args.input.read_text(encoding="utf-8"))
    sessions = loaded.get("sessions", []) if isinstance(loaded, dict) else loaded
    rows = rows_from_sessions(sessions, salt=args.salt)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8") as handle:
        for row in rows:
            handle.write(json.dumps(row, ensure_ascii=False) + "\n")
    print(f"wrote {len(rows)} feedback rows to {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
