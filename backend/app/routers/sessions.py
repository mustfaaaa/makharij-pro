import logging

from fastapi import APIRouter, Depends, File, Form, HTTPException, Request, UploadFile
from starlette.concurrency import run_in_threadpool

from .. import firestore_service
from ..auth import get_current_uid
from ..firebase_admin_setup import get_firestore_client

router = APIRouter()
logger = logging.getLogger(__name__)

# How many words past the point the reciter stopped are still returned, so the
# results screen can show where they got to in context without shipping every
# remaining word of a 286-ayah surah.
UNRECITED_TAIL_WORDS = 120

# Recorded on every session so history can say which analysis produced it.
PHONEME_MODEL_ID = "quran-lab-zipformer-p-arabic-v3.1"


def _analyze(service, audio_bytes, surah_number, from_ayah, to_ayah):
    """Run in a worker thread, so analysing a long recitation does not hold up
    the progress screen, the practice plan or Rattil. One recitation is
    analysed at a time; the recognizer itself enforces that now, because the
    live socket calls it from its own thread too."""
    return service.analyze_range(audio_bytes, surah_number, from_ayah, to_ayah)


def record_session(uid: str, results, *, surah_number: int, from_ayah: int, qari_id: str) -> dict:
    """Store an analysed recitation and build what the app is sent back.

    One shape whichever way the analysis ran -- on an uploaded recording, or on
    the live socket's own stream when recording stops -- so the app reads both
    the same and the history cannot tell them apart. Blocking (Firestore): run
    it off the event loop.
    """
    summary = firestore_service.summarize_word_results(results)
    # The passage analysed ends with the last word listed: the end of the
    # surah the recording stopped in, or of the range asked for.
    final = results[-1] if results else None
    end_surah = (final.surah_number or surah_number) if final else surah_number
    to_ayah = final.ayah_number if final else from_ayah
    session_id = firestore_service.save_session(
        uid=uid,
        model_id=PHONEME_MODEL_ID,
        surah_number=surah_number,
        from_ayah=from_ayah,
        to_ayah=to_ayah,
        end_surah=end_surah,
        summary=summary,
    )

    recited = [r for r in results if r.recited]
    last = recited[-1] if recited else None

    # Every word of the range comes back with a verdict, which is fine for a
    # short surah and absurd for Al-Baqarah -- 6,000 mostly-"not recited" word
    # objects the client already has the text for locally. Send what was
    # recited plus a short tail (so the UI can show where the reciter stopped
    # in context) and let `total_words` carry the rest of the story.
    cutoff = len(results)
    if last is not None:
        last_index = results.index(last)
        cutoff = min(len(results), last_index + 1 + UNRECITED_TAIL_WORDS)
    elif len(results) > UNRECITED_TAIL_WORDS:
        cutoff = UNRECITED_TAIL_WORDS
    trimmed = results[:cutoff]

    return {
        "session_id": session_id,
        "surah_number": surah_number,
        "from_ayah": from_ayah,
        # Where the passage analysed ends: `to_ayah` is an ayah of `end_surah`,
        # which is `surah_number` unless the recitation ran on into later ones.
        "end_surah": end_surah,
        "to_ayah": to_ayah,
        # How far the recording actually got -- what the UI needs to stop
        # rendering "you recited this" past the point the user stopped.
        "reached_surah": (last.surah_number or surah_number) if last else None,
        "reached_ayah": last.ayah_number if last else None,
        "reached_word_index": last.word_index if last else None,
        "total_words": summary["totalWords"],
        "words_recited": summary["wordsRecited"],
        "words_correct": summary["wordsCorrect"],
        # Proportion of correctly recited words to words actually recited (BR-3),
        # measured per word rather than per whole-clip rule verdict.
        "accuracy_score": summary["accuracyScore"],
        "mistake_counts": summary["mistakeCounts"],
        "qari_id": qari_id,
        "words": [
            {
                "surah_number": r.surah_number or surah_number,
                "ayah_number": r.ayah_number,
                "word_index": r.word_index,
                "word": r.display_word,
                "start_sec": r.start_sec,
                "end_sec": r.end_sec,
                "distance": float(r.edit_distance),
                "confidence": r.confidence,
                "recited": r.recited,
                "flagged": r.recited and not r.correct,
                "error_type": r.error_type,
                "explanation": r.explanation,
            }
            for r in trimmed
        ],
    }


@router.post("/sessions/analyze_word_level")
async def analyze_word_level(
    request: Request,
    audio: UploadFile = File(...),
    surah_number: int = Form(...),
    from_ayah: int = Form(1),
    to_ayah: int | None = Form(None),
    end_surah: int | None = Form(None),
    ayah_number: int | None = Form(None),
    qari_id: str = Form("abdurrahmaan_as_sudais"),
    uid: str = Depends(get_current_uid),
):
    """Gate 1+2 (approved -- see makharij_audit): real per-word phoneme
    recognition + timing via the Quran-Lab streaming zipformer model,
    compared directly against that model's own documented expected phoneme
    sequence -- not a fabricated preview. qari_id is accepted for API
    compatibility/analytics but not used for comparison, since the phoneme
    model compares against the ayah's canonical phoneme sequence rather than
    a specific reciter's audio.

    Analysis covers an ayah *range* -- the whole surah unless from_ayah/to_ayah
    narrow it. A user recites continuously and stops where they stop, so
    scoring a single ayah made every word past it look like an error. Words
    the recording never reached come back with `recited: false` and no error;
    `reached_ayah`/`reached_word_index` say exactly how far the user got.

    `ayah_number` is the older single-ayah form of this call and still works:
    it pins the range to that one ayah.

    `end_surah` lets the recitation run on past the surah it began in: the
    range is then from_ayah of surah_number to to_ayah of end_surah (to the
    end of end_surah without to_ayah), each surah analysed from its own ayah 1
    with its Basmala optional, and every word says which surah it is in. Left
    out, the range stays inside surah_number, exactly as before. A recording
    too long for one alignment is aligned in windows (see
    PhonemeAnalysisService.analyze_span), so it has no length ceiling.

    Covers all 6236 ayat -- see ordered_quran_phonemes.json.
    """
    service = request.app.state.phoneme_analysis_service
    if service is None:
        raise HTTPException(
            status_code=503,
            detail="Word-level analysis isn't available yet on this server (phoneme model not loaded).",
        )

    audio_bytes = await audio.read()
    if not audio_bytes:
        raise HTTPException(status_code=400, detail="Empty audio file")

    if ayah_number is not None:
        from_ayah = to_ayah = ayah_number
        end_surah = None

    try:
        results = await run_in_threadpool(
            service.analyze_span, audio_bytes, surah_number, from_ayah, end_surah, to_ayah)
    except ValueError as exc:
        # No phoneme reference for this surah/range -- helpful, not a bare 404.
        raise HTTPException(status_code=404, detail=str(exc))
    except Exception as exc:
        logger.exception("Word-level phoneme analysis failed")
        raise HTTPException(status_code=422, detail=f"Could not analyze audio: {exc}")

    return await run_in_threadpool(
        record_session, uid, results, surah_number=surah_number, from_ayah=from_ayah, qari_id=qari_id)


@router.post("/sessions/{session_id}/word-feedback")
async def word_feedback(
    session_id: str,
    ayah_number: int = Form(...),
    word_index: int = Form(...),
    agreed: bool = Form(False),
    surah_number: int | None = Form(None),
    uid: str = Depends(get_current_uid),
):
    """The reciter's own verdict on a word the app flagged.

    `surah_number` says which surah the word is in, for a recitation that ran
    on past the one it began in; left out, it is the session's own surah.

    `agreed=false` means "I said this correctly" -- the app was wrong here.
    Given the measured false-alarm rate, offering this is honesty rather than a
    courtesy, and what it collects is per-word judgement on real learner
    recitation, which no published dataset holds.
    """
    try:
        return firestore_service.record_word_feedback(
            uid, session_id, ayah_number, word_index, agreed, surah_number=surah_number
        )
    except KeyError as exc:
        raise HTTPException(status_code=404, detail=str(exc))


@router.post("/sessions/{session_id}/reattempt")
async def reattempt(
    request: Request,
    session_id: str,
    audio: UploadFile = File(...),
    surah_number: int = Form(...),
    from_ayah: int = Form(1),
    to_ayah: int | None = Form(None),
    ayah_number: int | None = Form(None),
    word_index: int | None = Form(None),
    uid: str = Depends(get_current_uid),
):
    """FR-8/BR-5: recite a flagged passage again, and fix only what was wrong.

    The reciter re-records either the whole passage or, with `ayah_number`
    (optionally plus `word_index`), the one place they want another go at. Only
    words this session already flagged can change; a word it called correct
    keeps that verdict even if the new take scores it worse, so trying again can
    never cost you a word you had already got right.

    The session's own statistics -- mistakes, per-rule counts, accuracy -- are
    recomputed. Its per-word phoneme record is not: that is what the correction
    loop turns into training labels, and a first attempt that was wrongly
    flagged is the case most worth keeping.
    """
    service = request.app.state.phoneme_analysis_service
    if service is None:
        raise HTTPException(
            status_code=503,
            detail="Word-level analysis isn't available yet on this server "
                   "(phoneme model not loaded).",
        )

    audio_bytes = await audio.read()
    if not audio_bytes:
        raise HTTPException(status_code=400, detail="Empty audio file")

    scope = None
    if ayah_number is not None:
        from_ayah = to_ayah = ayah_number
        scope = (ayah_number, word_index)
    elif word_index is not None:
        raise HTTPException(
            status_code=400,
            detail="word_index needs an ayah_number to identify the word.",
        )

    try:
        results = await run_in_threadpool(_analyze, service, audio_bytes, surah_number, from_ayah, to_ayah)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    except Exception as exc:
        logger.exception("Re-attempt analysis failed")
        raise HTTPException(status_code=422, detail=f"Could not analyze audio: {exc}")

    try:
        return await run_in_threadpool(
            firestore_service.apply_reattempt, uid, session_id, results, scope, surah_number)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))


# These read Firestore through its synchronous client. Declared `async`, that
# read blocked the event loop, so the four calls the home screen makes at once
# were served one after another. Declared `def`, FastAPI runs them in its worker
# threads and they overlap.
@router.get("/progress")
def get_progress(uid: str = Depends(get_current_uid)):
    """FR-13: day streak, average score, chart-ready daily history, activity heatmap, and
    per-rule mastery for the progress dashboard."""
    sessions = firestore_service.fetch_sessions(uid)
    stats = firestore_service.compute_progress_stats(uid, sessions)
    stats["activity_heatmap"] = firestore_service.compute_activity_heatmap(uid, sessions=sessions)
    stats["rule_mastery"] = firestore_service.compute_rule_mastery(uid, sessions=sessions)
    return stats


@router.get("/achievements")
def get_achievements(uid: str = Depends(get_current_uid)):
    """Real, session-history-derived badge unlock state -- see firestore_service.py
    for exactly what each badge is computed from."""
    return {"achievements": firestore_service.compute_achievements(uid)}


@router.get("/notifications")
def get_notifications(uid: str = Depends(get_current_uid)):
    """A real, derived status feed (streak, achievements, top practice-plan focus) --
    not a stored/triggered notification system. See firestore_service.py's docstring."""
    return {"notifications": firestore_service.compute_notifications(uid)}


@router.get("/practice-plan")
def get_practice_plan(uid: str = Depends(get_current_uid)):
    """FR-14/Algorithm 6.5: recommends which rules to practice based on recurring weak areas."""
    return firestore_service.generate_practice_plan(uid)


@router.get("/sessions")
def list_sessions(uid: str = Depends(get_current_uid)):
    """Session history for the progress dashboard (FR-13/UC-5)."""
    db = get_firestore_client()
    docs = (
        db.collection("users").document(uid).collection("sessions")
        .order_by("createdAt", direction="DESCENDING").limit(100).stream()
    )
    sessions = []
    for doc in docs:
        data = doc.to_dict()
        data["session_id"] = doc.id
        # Firestore hands back its own datetime type; send an ISO-8601 string so
        # the client can actually parse it. It used to arrive unparseable, so
        # every past session was displayed with the time it was *opened*.
        created = data.get("createdAt")
        if created is not None:
            data["createdAt"] = created.isoformat()
        sessions.append(data)
    return {"sessions": sessions}
