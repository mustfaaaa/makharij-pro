import logging
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from .firebase_admin_setup import init_firebase
from .model_service import TajweedModelService
from .phoneme_analysis_service import PhonemeAnalysisService
from .routers import inference, live, rattil, sessions

logging.basicConfig(level=logging.INFO)


@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.model_service = TajweedModelService()  # loaded once, reused across requests
    try:
        init_firebase()
    except FileNotFoundError as exc:
        # Non-fatal: /api/v1/analyze (no auth needed) must keep working even before the
        # service account key is set up. Auth/Firestore-dependent endpoints will 503 until
        # it's added -- see backend/README.md for how to generate one.
        logging.warning(f"Firebase not initialized, auth/session endpoints will 503: {exc}")

    # Gate 1+2 (approved, see makharij_audit): word-level phoneme recognition
    # via the Quran-Lab zipformer model, verified against 8 real Rattil clips
    # (6/8 exact, 4.1% aggregate char error). Supersedes the earlier
    # wav2vec2-forced-alignment + DTW approach -- this single model gives
    # both phoneme content and per-token timestamps directly, and its
    # checkpoint is a completed 72MB int8 ONNX file rather than a 1.2GB
    # download that never finished. Non-fatal like Firebase above.
    try:
        app.state.phoneme_analysis_service = PhonemeAnalysisService()
        logging.info("Phoneme analysis service loaded -- word-level analysis available")
    except Exception as exc:
        app.state.phoneme_analysis_service = None
        logging.warning(f"Phoneme analysis service not available, word-level analysis will 503: {exc}")

    yield


app = FastAPI(title="MakharijPro AI Backend", lifespan=lifespan)

# The Flutter web build runs on localhost/127.0.0.1 at whatever port `flutter run`
# happens to pick, which differs from the backend's own origin (127.0.0.1:8000) --
# without this, the browser blocks every request before it reaches the server at
# all, surfacing as a generic "could not reach the server" error client-side.
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"http://(localhost|127\.0\.0\.1)(:\d+)?",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(inference.router, prefix="/api/v1")
app.include_router(sessions.router, prefix="/api/v1")
app.include_router(rattil.router, prefix="/api/v1")
# Live word-position streaming (WebSocket) for highlighting words as the
# user recites -- see routers/live.py for the protocol.
app.include_router(live.router, prefix="/api/v1")

# Rattil AI recitation repository, served locally -- not Firebase Cloud Storage, since that now
# requires a linked billing account even for trivial usage. See backend/README.md for the tradeoff
# and the migration path. Files under app/static/recitations/{qari_id}/{surah}{ayah}.mp3.
_static_dir = Path(__file__).resolve().parent / "static"
_static_dir.mkdir(exist_ok=True)
app.mount("/media", StaticFiles(directory=str(_static_dir)), name="media")


@app.get("/health")
async def health():
    return {"status": "ok"}
