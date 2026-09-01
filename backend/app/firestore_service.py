"""Firestore persistence for recitation sessions, and the progress/practice-plan
statistics derived from them.

Everything here is keyed on the *word-level* analysis (see
phoneme_analysis_service.py), because that is what the app actually measures:
which word was mispronounced, and which Tajweed rule it broke.

It used to store the whole-clip rule classifier's output instead -- three
QDAT-derived labels for the entire recording. That had two consequences worth
recording, since both were visible to users:

  - the stored accuracy was the fraction of 3 rule verdicts that passed, so it
    could only ever be 0%, 33%, 67% or 100%. The results screen showed the real
    per-word score, so a session displayed as 94% appeared in history as 67%;
  - the practice plan recommended rules from a model measured at 74.8% accuracy
    on its weakest task, while the real per-word mistakes -- correctly typed as
    madd / ghunnah / shaddah / makhraj -- were computed, shown once, and thrown
    away.

Sessions written under the old schema have no `mistakeCounts` and are skipped by
the rule-based statistics rather than being reinterpreted as something they
aren't; they still count towards streaks and session totals.
"""
from collections import Counter
from datetime import datetime, timedelta, timezone

from .firebase_admin_setup import get_firestore_client

# Error type ids as produced by tajweed_diff.py, with the labels users see.
RULE_LABELS = {
    "madd": "Madd (elongation)",
    "ghunnah": "Ghunnah (nasalization)",
    "shaddah": "Shaddah (doubling)",
    "makhraj": "Makhraj (articulation point)",
    "skipped": "Skipped words",
}
RULES = tuple(RULE_LABELS)

MIN_HISTORY_FOR_PERSONALIZED_PLAN = 3  # Algorithm 6.5's MIN_HISTORY


def summarize_word_results(results) -> dict:
    """Reduce a list of WordPhonemeResult into what a session stores.

    `results` covers the requested ayah range; words the reciter never reached
    are excluded from scoring entirely -- they are not mistakes.
    """
    recited = [r for r in results if r.recited]
    correct = [r for r in recited if r.correct]
    mistakes = [
        {
            "ayahNumber": r.ayah_number,
            "wordIndex": r.word_index,
            "word": r.display_word,
            "errorType": r.error_type or "makhraj",
            "explanation": r.explanation or "",
        }
        for r in recited
        if not r.correct
    ]
    counts = Counter(m["errorType"] for m in mistakes)

    return {
        "accuracyScore": round(len(correct) / len(recited), 4) if recited else 0.0,
        "totalWords": len(results),
        "wordsRecited": len(recited),
        "wordsCorrect": len(correct),
        "reachedAyah": recited[-1].ayah_number if recited else None,
        "mistakes": mistakes,
        # Per-rule tallies, so the practice plan and mastery chart never have to
        # re-read the (much larger) mistake list.
        "mistakeCounts": {rule: counts.get(rule, 0) for rule in RULES},
    }


def save_session(uid: str, model_id: str, surah_number: int, from_ayah: int,
                 to_ayah: int, summary: dict) -> str:
    db = get_firestore_client()
    session_ref = db.collection("users").document(uid).collection("sessions").document()
    session_ref.set({
        "createdAt": datetime.now(timezone.utc),
        "modelId": model_id,
        "surahNumber": surah_number,
        "fromAyah": from_ayah,
        "toAyah": to_ayah,
        **summary,
    })
    return session_ref.id


def _fetch_all_sessions(uid: str) -> list[dict]:
    db = get_firestore_client()
    docs = (
        db.collection("users").document(uid).collection("sessions")
        .order_by("createdAt", direction="DESCENDING").stream()
    )
    return [doc.to_dict() for doc in docs]


def _word_level_sessions(sessions: list[dict]) -> list[dict]:
    """Only sessions stored with per-word mistakes. Older rule-granularity rows
    can't be converted into per-word data after the fact, so the rule-based
    statistics ignore them rather than guessing."""
    return [s for s in sessions if "mistakeCounts" in s]


def compute_progress_stats(uid: str) -> dict:
    """FR-13: day streak, average score, and chart-ready history for the progress dashboard."""
    sessions = _fetch_all_sessions(uid)
    if not sessions:
        return {"total_sessions": 0, "avg_score": 0.0, "day_streak": 0, "daily_scores": []}

    total_sessions = len(sessions)
    avg_score = round(sum(s.get("accuracyScore", 0.0) for s in sessions) / total_sessions, 4)

    # Group by calendar date (UTC -- we don't have the user's timezone, documented simplification).
    by_date: dict = {}
    for s in sessions:
        d = s["createdAt"].date()
        by_date.setdefault(d, []).append(s.get("accuracyScore", 0.0))

    today = datetime.now(timezone.utc).date()
    cursor = today if today in by_date else today - timedelta(days=1)
    day_streak = 0
    while cursor in by_date:
        day_streak += 1
        cursor -= timedelta(days=1)

    daily_scores = [
        {"date": d.isoformat(), "avg_score": round(sum(scores) / len(scores), 4), "n_sessions": len(scores)}
        for d, scores in sorted(by_date.items())
    ][-30:]  # last 30 days with activity, chart-ready

    return {
        "total_sessions": total_sessions,
        "avg_score": avg_score,
        "day_streak": day_streak,
        "daily_scores": daily_scores,
    }


def compute_activity_heatmap(uid: str, weeks: int = 10) -> list[list[int]]:
    """Session-count-per-day for the last `weeks` weeks, shaped [week][day] (oldest week
    first, day 0 = the start of that 7-day chunk) to match the dashboard's existing grid.
    Not calendar-aligned to Mon-Sun -- the UI never showed weekday labels, so a simple
    "last N days chunked into 7s" grid is honest without inventing an alignment nobody asked for.
    Counts are capped at 4 to match the existing 5-level color scale."""
    sessions = _fetch_all_sessions(uid)
    counts_by_date: dict = {}
    for s in sessions:
        d = s["createdAt"].date()
        counts_by_date[d] = counts_by_date.get(d, 0) + 1

    today = datetime.now(timezone.utc).date()
    total_days = weeks * 7
    days = [today - timedelta(days=total_days - 1 - i) for i in range(total_days)]
    levels = [min(counts_by_date.get(d, 0), 4) for d in days]
    return [levels[w * 7:(w + 1) * 7] for w in range(weeks)]


def compute_rule_mastery(uid: str, window: int = 20) -> dict:
    """Share of recited words free of each rule's mistakes, over the last
    `window` sessions, as a 0-100 percentage.

    Deliberately measured against *every* word recited, not against the words
    each rule actually applies to -- knowing which words carry a madd or a
    ghunnah would need the reference's per-phoneme sifat, which this pipeline
    doesn't consume. So these read as "how clean was your recitation of this
    rule", and are comparable between rules and over time, but are not a claim
    about per-rule opportunity.
    """
    sessions = _word_level_sessions(_fetch_all_sessions(uid))[:window]
    words = sum(s.get("wordsRecited", 0) for s in sessions)
    if words == 0:
        return {}

    totals = Counter()
    for s in sessions:
        for rule, count in s.get("mistakeCounts", {}).items():
            totals[rule] += count

    return {
        RULE_LABELS[rule]: round(max(0.0, 1 - totals[rule] / words) * 100, 1)
        for rule in RULES
    }


def compute_achievements(uid: str) -> list[dict]:
    """Every badge here is derived from real session history -- no fabricated
    unlock state. 'Tajweed Scholar' (read all rule explanations) has no
    backing data source yet (the Tajweed Rules library has no read-tracking),
    so it's always reported locked at 0 progress rather than a guess."""
    sessions = _fetch_all_sessions(uid)
    total = len(sessions)
    day_streak = compute_progress_stats(uid)["day_streak"]
    best_score = max((s.get("accuracyScore", 0.0) for s in sessions), default=0.0)
    distinct_surahs = len({s["surahNumber"] for s in sessions if s.get("surahNumber") is not None})

    def badge(id_, title, description, icon_key, unlocked, progress):
        return {"id": id_, "title": title, "description": description, "icon_key": icon_key,
                "is_unlocked": unlocked, "progress": round(min(progress, 1.0), 4)}

    return [
        badge("first_recitation", "First Recitation", "Complete your first recitation session",
              "mic", total >= 1, min(total, 1)),
        badge("streak_7", "7-Day Streak", "Practice for 7 consecutive days",
              "local_fire_department", day_streak >= 7, day_streak / 7),
        badge("perfect_score", "Perfect Score", "Score 100% accuracy in a session",
              "star", best_score >= 1.0, best_score),
        badge("surah_explorer", "Surah Explorer", "Recite 10 different surahs",
              "menu_book", distinct_surahs >= 10, distinct_surahs / 10),
        badge("tajweed_scholar", "Tajweed Scholar", "Read all Tajweed rule explanations",
              "school", False, 0.0),
        badge("streak_30", "30-Day Streak", "Practice for 30 consecutive days",
              "whatshot", day_streak >= 30, day_streak / 30),
    ]


def compute_notifications(uid: str) -> list[dict]:
    """A real, derived status feed -- not a stored/triggered notification system (no push
    infrastructure exists). Composed from the same achievement/progress/practice-plan data
    already computed elsewhere, generated fresh on each call rather than logged historically,
    since there's no event log of exactly when an achievement unlocked or a streak broke."""
    now = datetime.now(timezone.utc).isoformat()
    notifications = []

    stats = compute_progress_stats(uid)
    if stats["day_streak"] >= 1:
        notifications.append({
            "id": "streak_active", "type": "tip", "dateTime": now,
            "title": "Keep your streak going",
            "message": f"You're on a {stats['day_streak']}-day streak. Recite today to keep it alive.",
        })
    elif stats["total_sessions"] > 0:
        notifications.append({
            "id": "streak_reset", "type": "reminder", "dateTime": now,
            "title": "Your streak reset",
            "message": "Recite today to start a new streak.",
        })

    for badge in compute_achievements(uid):
        if badge["is_unlocked"]:
            notifications.append({
                "id": f"achievement_{badge['id']}", "type": "achievement", "dateTime": now,
                "title": "Achievement unlocked", "message": badge["title"],
            })

    plan = generate_practice_plan(uid)
    if plan["plan_type"] == "personalized" and plan["recommendations"]:
        top = plan["recommendations"][0]
        notifications.append({
            "id": "practice_plan_top", "type": "tip", "dateTime": now,
            "title": f"Focus on {top['tajweed_rule']}", "message": top["reason"],
        })

    return notifications


def generate_practice_plan(uid: str) -> dict:
    """FR-14 / Algorithm 6.5: rank Tajweed rules by how often the user's own
    recitations actually broke them, and point at the words they broke them on.

    Unlike the previous rule-granularity version, every recommendation here can
    name real evidence -- the specific words that were flagged, from the user's
    own sessions.
    """
    sessions = _word_level_sessions(_fetch_all_sessions(uid))
    if len(sessions) < MIN_HISTORY_FOR_PERSONALIZED_PLAN:
        return {
            "plan_type": "beginner",
            "based_on_sessions": len(sessions),
            "recommendations": [
                {"rule": rule, "tajweed_rule": RULE_LABELS[rule], "error_count": 0, "examples": [],
                 "reason": "Not enough recitation history yet for a personalized plan -- "
                           "practice all rules for now."}
                for rule in RULES
            ],
        }

    error_freq = Counter()
    examples: dict[str, list[dict]] = {rule: [] for rule in RULES}
    for s in sessions:
        for rule, count in s.get("mistakeCounts", {}).items():
            error_freq[rule] += count
        for m in s.get("mistakes", []):
            bucket = examples.setdefault(m.get("errorType", "makhraj"), [])
            if len(bucket) < 3:
                bucket.append({
                    "surah_number": s.get("surahNumber"),
                    "ayah_number": m.get("ayahNumber"),
                    "word": m.get("word"),
                    "explanation": m.get("explanation"),
                })

    ranked = [rule for rule, count in error_freq.most_common() if count > 0]
    recommendations = [
        {
            "rule": rule,
            "tajweed_rule": RULE_LABELS[rule],
            "error_count": error_freq[rule],
            "examples": examples.get(rule, []),
            "reason": f"{error_freq[rule]} word(s) flagged for this across your "
                      f"last {len(sessions)} session(s)",
        }
        for rule in ranked
    ]

    if not recommendations:
        return {"plan_type": "no_weak_areas", "based_on_sessions": len(sessions),
                "recommendations": [{"rule": None, "tajweed_rule": None, "error_count": 0,
                                     "examples": [],
                                     "reason": "No recurring errors found -- keep up the good work."}]}

    return {"plan_type": "personalized", "based_on_sessions": len(sessions),
            "recommendations": recommendations}
