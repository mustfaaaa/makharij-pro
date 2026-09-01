import logging

from fastapi import APIRouter, File, HTTPException, Request, UploadFile

router = APIRouter()
logger = logging.getLogger(__name__)


@router.post("/analyze")
async def analyze_recitation(request: Request, audio: UploadFile = File(...)):
    """Accepts a recitation audio clip, returns per-rule correct/incorrect + confidence.

    Whole-clip classification only (see ml/models/.../model_card.json known_limitations) --
    not yet real-time word-level detection.
    """
    audio_bytes = await audio.read()
    if not audio_bytes:
        raise HTTPException(status_code=400, detail="Empty audio file")

    service = request.app.state.model_service
    try:
        results = service.predict_from_audio_bytes(audio_bytes)
    except Exception as exc:  # audio decode failures, corrupt/unsupported files, etc.
        logger.exception("Failed to analyze audio")
        raise HTTPException(
            status_code=422,
            detail=f"Could not process audio file (supported: wav, flac, ogg; mp3/m4a need ffmpeg installed): {exc}",
        )

    return {"model_id": service.model_card["model_id"], "results": results}


@router.get("/model-info")
async def model_info(request: Request):
    service = request.app.state.model_service
    card = service.model_card
    return {
        "model_id": card["model_id"],
        "experiment": card["experiment"],
        "tasks": card["tasks"],
        "calibrated_thresholds": card["calibrated_thresholds"],
        "known_limitations": card["known_limitations"],
    }
