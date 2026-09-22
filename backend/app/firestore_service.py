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
import threading
import time
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

# Every derived statistic reads the session history, which is a full Firestore
# read of one user's sessions. That history only changes when this server saves
# a session, records word feedback, or applies a re-attempt, so it is cached per
# user and dropped on exactly those writes. The TTL is the backstop for a change
# made outside this process (a second instance, or the Firebase console): stale
# numbers can last a few seconds, never longer.
_HISTORY_TTL_SECONDS = 30
_history_cache: dict[str, tuple[float, list[dict]]] = {}
_history_lock = threading.Lock()

# How far back the statistics that only describe recent practice will read.
# Progress deliberately has no limit: it reports the total number of sessions
# and the day streak, and both are wrong if older sessions are left out.
RULE_MASTERY_HISTORY = 100
PRACTICE_PLAN_HISTORY = 200

# How many per-word verdicts a session keeps for the label store (below).
# A Firestore document is capped at ~1 MiB; at roughly 150 bytes a verdict this
# leaves a wide margin, while still covering every ordinary practice session
# and all of Juz 30 in full. Only a near-complete recitation of a long surah
# ever exceeds it, and there the flagged words -- the ones a reciter can
# dispute -- are always kept (see word_verdicts_for_storage).
MAX_STORED_WORD_VERDICTS = 400


def word_verdicts_for_storage(results) -> list[dict]:
    """The per-word record a later "I said it right" needs to become a label.

    The feedback endpoint stores only *coordinates* and the reciter's verdict:
    "word 3 of ayah 2, the reciter disagreed". On its own that is unusable. To
    tell a systematic false alarm (many reciters dispute the same word, so the
    model is over-flagging there) from one learner who simply doesn't know the
    rule, the label has to sit next to what the model actually claimed and how
    far off it thought the recitation was. That context is computed once, sent
    to the screen, and -- until now -- thrown away. This keeps it.

    Only *recited* words are stored: a word the reciter never reached carries
    no judgement to capture, and dropping them is what keeps the list bounded
    by what was actually said rather than by surah length.

    When even the recited words exceed [MAX_STORED_WORD_VERDICTS], every flagged
    word is kept -- those are the ones a reciter can press "I said it right" on,
    so losing one would drop a label we can never recover -- and the remaining
    budget is filled with correct words in reading order.
    """
    recited = [r for r in results if r.recited]
    if len(recited) > MAX_STORED_WORD_VERDICTS:
        flagged_idx = [i for i, r in enumerate(recited) if not r.correct]
        budget = max(MAX_STORED_WORD_VERDICTS - len(flagged_idx), 0)
        correct_idx = [i for i, r in enumerate(recited) if r.correct][:budget]
        keep = sorted(set(flagged_idx) | set(correct_idx))
        recited = [recited[i] for i in keep]

    return [
        {
            "ayahNumber": r.ayah_number,
            "wordIndex": r.word_index,
            "word": r.display_word,
            # The features that separate a real mistake from recogniser noise:
            # what the model heard, what it expected, and how far apart it
            # judged them to be.
            "predicted": r.predicted_phonemes,
            "expected": r.expected_phonemes,
            "distance": r.edit_distance,
            "confidence": r.confidence,
            # The model's own claim about this word -- the "claimed" half of a
            # (claimed, reciter-says) label. errorType is None exactly when the
            # model called the word correct.
            "correct": r.correct,
            "errorType": r.error_type,
        }
        for r in recited
    ]


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
        # The per-word verdict record the feedback loop turns into labels. Kept
        # separate from `mistakes` on purpose: `mistakes` drives the stats and
        # the practice plan and holds only flagged words, while this holds the
        # correct words too (a dispute can land on either) and the phoneme
        # features neither the stats nor the UI need.
        "words": word_verdicts_for_storage(results),
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
    invalidate_history(uid)
    return session_ref.id


def record_word_feedback(uid: str, session_id: str, ayah_number: int,
                         word_index: int, agreed: bool) -> dict:
    """Records the reciter's own verdict on one flagged word.

    The detector wrongly flags roughly two correct recitations in five
    (ml/eval/README.md), so the reciter disagreeing is expected, not an edge
    case. Storing it does two things: it lets the results screen stop insisting,
    and it accumulates the one kind of data that does not exist anywhere --
    per-word judgements on real learner recitations. Every published corpus is
    either labelled per clip or made of deliberately-produced errors.

    Read it as "the reciter disagreed", never as "the app was wrong": someone
    can reject a correct verdict because they don't know the rule, or don't want
    to be wrong. It is a signal to weigh, not ground truth.
    """
    db = get_firestore_client()
    session_ref = db.collection("users").document(uid).collection("sessions").document(session_id)
    session = session_ref.get()
    if not session.exists:
        raise KeyError(f"Session {session_id} not found for this user")

    feedback = session.to_dict().get("wordFeedback", [])
    # One verdict per word: pressing it again replaces, rather than stacking up
    # contradictory entries for the same word.
    feedback = [
        f for f in feedback
        if not (f.get("ayahNumber") == ayah_number and f.get("wordIndex") == word_index)
    ]
    feedback.append({
        "ayahNumber": ayah_number,
        "wordIndex": word_index,
        "agreed": agreed,
        "at": datetime.now(timezone.utc),
    })
    session_ref.update({"wordFeedback": feedback})
    invalidate_history(uid)
    return {"session_id": session_id, "word_feedback_count": len(feedback)}


def fetch_sessions(uid: str, limit: int | None = None) -> list[dict]:
    """The session history, newest first, read once and cached briefly.

    Every statistic below is derived from this same list: pass it in rather than
    letting each one re-read Firestore. Opening the progress screen used to cost
    three reads of the whole history, and the notifications feed five.

    `limit` is for the statistics that only describe recent practice; a limited
    read is never cached, since it is not the whole history."""
    if limit is not None:
        return _fetch_all_sessions(uid, limit=limit)

    now = time.monotonic()
    with _history_lock:
        cached = _history_cache.get(uid)
        if cached is not None and now - cached[0] < _HISTORY_TTL_SECONDS:
            return list(cached[1])

    sessions = _fetch_all_sessions(uid)
    with _history_lock:
        _history_cache[uid] = (now, sessions)
    return list(sessions)


def invalidate_history(uid: str) -> None:
    """Called after every write that changes what the statistics would say, so
    the next screen shows the new recitation rather than the cached history."""
    with _history_lock:
        _history_cache.pop(uid, None)


def _fetch_all_sessions(uid: str, limit: int | None = None) -> list[dict]:
    db = get_firestore_client()
    query = (
        db.collection("users").document(uid).collection("sessions")
        .order_by("createdAt", direction="DESCENDING")
    )
    if limit is not None:
        query = query.limit(limit)
    return [doc.to_dict() for doc in query.stream()]


def _word_level_sessions(sessions: list[dict]) -> list[dict]:
    """Only sessions stored with per-word mistakes. Older rule-granularity rows
    can't be converted into per-word data after the fact, so the rule-based
    statistics ignore them rather than guessing."""
    return [s for s in sessions if "mistakeCounts" in s]


def compute_progress_stats(uid: str, sessions: list[dict] | None = None) -> dict:
    """FR-13: day streak, average score, and chart-ready history for the progress dashboard."""
    sessions = fetch_sessions(uid) if sessions is None else sessions
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


def compute_activity_heatmap(uid: str, weeks: int = 10, sessions: list[dict] | None = None) -> list[list[int]]:
    """Session-count-per-day for the last `weeks` weeks, shaped [week][day] (oldest week
    first, day 0 = the start of that 7-day chunk) to match the dashboard's existing grid.
    Not calendar-aligned to Mon-Sun -- the UI never showed weekday labels, so a simple
    "last N days chunked into 7s" grid is honest without inventing an alignment nobody asked for.
    Counts are capped at 4 to match the existing 5-level color scale."""
    sessions = fetch_sessions(uid) if sessions is None else sessions
    counts_by_date: dict = {}
    for s in sessions:
        d = s["createdAt"].date()
        counts_by_date[d] = counts_by_date.get(d, 0) + 1

    today = datetime.now(timezone.utc).date()
    total_days = weeks * 7
    days = [today - timedelta(days=total_days - 1 - i) for i in range(total_days)]
    levels = [min(counts_by_date.get(d, 0), 4) for d in days]
    return [levels[w * 7:(w + 1) * 7] for w in range(weeks)]


def compute_rule_mastery(uid: str, window: int = 20, sessions: list[dict] | None = None) -> dict:
    """Share of recited words free of each rule's mistakes, over the last
    `window` sessions, as a 0-100 percentage.

    Deliberately measured against *every* word recited, not against the words
    each rule actually applies to -- knowing which words carry a madd or a
    ghunnah would need the reference's per-phoneme sifat, which this pipeline
    doesn't consume. So these read as "how clean was your recitation of this
    rule", and are comparable between rules and over time, but are not a claim
    about per-rule opportunity.
    """
    sessions = _word_level_sessions(
        fetch_sessions(uid, limit=RULE_MASTERY_HISTORY) if sessions is None else sessions
    )[:window]
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


def compute_achievements(uid: str, sessions: list[dict] | None = None) -> list[dict]:
    """Every badge here is derived from real session history -- no fabricated
    unlock state. 'Tajweed Scholar' (read all rule explanations) has no
    backing data source yet (the Tajweed Rules library has no read-tracking),
    so it's always reported locked at 0 progress rather than a guess."""
    sessions = fetch_sessions(uid) if sessions is None else sessions
    total = len(sessions)
    day_streak = compute_progress_stats(uid, sessions)["day_streak"]
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


def compute_notifications(uid: str, sessions: list[dict] | None = None) -> list[dict]:
    """A real, derived status feed -- not a stored/triggered notification system (no push
    infrastructure exists). Composed from the same achievement/progress/practice-plan data
    already computed elsewhere, generated fresh on each call rather than logged historically,
    since there's no event log of exactly when an achievement unlocked or a streak broke."""
    now = datetime.now(timezone.utc).isoformat()
    notifications = []

    sessions = fetch_sessions(uid) if sessions is None else sessions
    stats = compute_progress_stats(uid, sessions)
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

    for badge in compute_achievements(uid, sessions):
        if badge["is_unlocked"]:
            notifications.append({
                "id": f"achievement_{badge['id']}", "type": "achievement", "dateTime": now,
                "title": "Achievement unlocked", "message": badge["title"],
            })

    plan = generate_practice_plan(uid, sessions)
    if plan["plan_type"] == "personalized" and plan["recommendations"]:
        top = plan["recommendations"][0]
        notifications.append({
            "id": "practice_plan_top", "type": "tip", "dateTime": now,
            "title": f"Focus on {top['tajweed_rule']}", "message": top["reason"],
        })

    return notifications


def generate_practice_plan(uid: str, sessions: list[dict] | None = None) -> dict:
    """FR-14 / Algorithm 6.5: rank Tajweed rules by how often the user's own
    recitations actually broke them, and point at the words they broke them on.

    Unlike the previous rule-granularity version, every recommendation here can
    name real evidence -- the specific words that were flagged, from the user's
    own sessions.
    """
    sessions = _word_level_sessions(
        fetch_sessions(uid, limit=PRACTICE_PLAN_HISTORY) if sessions is None else sessions
    )
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


def apply_reattempt(uid: str, session_id: str, results,
                    scope: tuple[int, int | None] | None = None) -> dict:
    """FR-8/BR-5 self-correction, at word granularity.

    What a re-attempt is allowed to change
    --------------------------------------
    Only words this session already flagged. A word the session called correct
    stays correct even if the new recording scores it worse -- BR-5 is about
    letting a reciter fix what they got wrong, not about putting a second
    recording's mistakes onto the first one's record. Without that rule a user
    who re-recites one bad word and fumbles a neighbouring good one ends up
    with a worse score for having tried, which is the opposite of the
    behaviour the requirement asks for.

    `scope` narrows it further to (ayah_number, word_index) when the reciter
    re-recorded a single word rather than the passage; word_index None means
    the whole ayah.

    Why the original per-word record is not overwritten
    ---------------------------------------------------
    `words` is the evidence the correction loop turns into ML labels -- what
    the model claimed and how far off it thought the recitation was. A first
    attempt that was wrongly flagged is exactly the case worth learning from,
    so overwriting it with a later, cleaner take would delete the only record
    of the false alarm. Re-attempts are appended to `reattempts` instead, and
    only the user-facing statistics are recomputed.

    `hadMultipleAttempts` stays true once set, even after a successful
    correction: BR-5 intends such words to keep counting as weak areas for the
    practice plan (FR-14).
    """
    db = get_firestore_client()
    session_ref = (db.collection("users").document(uid)
                   .collection("sessions").document(session_id))
    session = session_ref.get()
    if not session.exists:
        raise KeyError(f"Session {session_id} not found for this user")
    data = session.to_dict()

    was_flagged = {(m["ayahNumber"], m["wordIndex"]) for m in data.get("mistakes", [])}
    if scope is not None:
        ayah, word_index = scope
        was_flagged = {
            key for key in was_flagged
            if key[0] == ayah and (word_index is None or key[1] == word_index)
        }
    if not was_flagged:
        raise ValueError(
            "Nothing to re-attempt: this session has no flagged words in that range")

    # New verdicts, keyed the same way, for words the recording actually reached.
    fresh = {(r.ayah_number, r.word_index): r for r in results if r.recited}

    attempt_counts = dict(data.get("attemptCounts", {}))
    had_multiple = set(data.get("hadMultipleAttempts", []))
    mistakes = [dict(m) for m in data.get("mistakes", [])]
    by_key = {(m["ayahNumber"], m["wordIndex"]): m for m in mistakes}

    corrected: list[dict] = []
    still_wrong: list[dict] = []
    not_reached: list[dict] = []

    for key in sorted(was_flagged):
        coordinate = f"{key[0]}:{key[1]}"
        result = fresh.get(key)
        if result is None:
            # The re-recording never got to this word; its original verdict
            # stands, and it does not count as an attempt.
            not_reached.append({"ayahNumber": key[0], "wordIndex": key[1]})
            continue

        attempt_counts[coordinate] = attempt_counts.get(coordinate, 1) + 1
        had_multiple.add(coordinate)
        entry = {"ayahNumber": key[0], "wordIndex": key[1],
                 "word": result.display_word}

        if result.correct:
            mistakes = [m for m in mistakes
                        if (m["ayahNumber"], m["wordIndex"]) != key]
            corrected.append(entry)
        else:
            # Still wrong, but possibly wrong in a new way -- the explanation
            # the user sees should describe the attempt they just made.
            existing = by_key.get(key)
            if existing is not None:
                existing["errorType"] = result.error_type or "makhraj"
                existing["explanation"] = result.explanation or ""
            still_wrong.append({**entry, "errorType": result.error_type})

    words_recited = data.get("wordsRecited", 0)
    words_correct = max(words_recited - len(mistakes), 0)
    counts = Counter(m["errorType"] for m in mistakes)

    reattempts = list(data.get("reattempts", []))
    reattempts.append({
        "at": datetime.now(timezone.utc),
        "scope": {"ayahNumber": scope[0], "wordIndex": scope[1]} if scope else None,
        "corrected": corrected,
        "stillWrong": still_wrong,
        "notReached": not_reached,
    })

    update = {
        "mistakes": mistakes,
        "mistakeCounts": {rule: counts.get(rule, 0) for rule in RULES},
        "wordsCorrect": words_correct,
        "accuracyScore": (round(words_correct / words_recited, 4)
                          if words_recited else 0.0),
        "attemptCounts": attempt_counts,
        "hadMultipleAttempts": sorted(had_multiple),
        "reattempts": reattempts,
    }
    session_ref.update(update)
    invalidate_history(uid)

    return {
        "session_id": session_id,
        "corrected": corrected,
        "still_wrong": still_wrong,
        "not_reached": not_reached,
        "words_correct": words_correct,
        "words_recited": words_recited,
        "accuracy_score": update["accuracyScore"],
        "mistake_counts": update["mistakeCounts"],
        "had_multiple_attempts": update["hadMultipleAttempts"],
    }
