import logging

import firebase_admin
from firebase_admin import auth as firebase_auth
from firebase_admin import credentials, firestore

from . import config

logger = logging.getLogger(__name__)

_app = None
_db = None


def init_firebase():
    """Initializes the Firebase Admin app once. Call from main.py's lifespan startup."""
    global _app, _db
    if _app is not None:
        return

    if not config.FIREBASE_SERVICE_ACCOUNT_PATH.exists():
        raise FileNotFoundError(
            f"Firebase service account key not found at {config.FIREBASE_SERVICE_ACCOUNT_PATH}. "
            "Generate one from Firebase Console -> Project Settings -> Service Accounts -> "
            "Generate new private key, and save it there (or point FIREBASE_SERVICE_ACCOUNT_PATH "
            "at it) -- see backend/README.md."
        )

    cred = credentials.Certificate(str(config.FIREBASE_SERVICE_ACCOUNT_PATH))
    _app = firebase_admin.initialize_app(cred, {"projectId": config.FIREBASE_PROJECT_ID})
    _db = firestore.client()
    logger.info(f"Firebase Admin initialized for project {config.FIREBASE_PROJECT_ID}")


def is_initialized() -> bool:
    return _db is not None


def get_firestore_client():
    if _db is None:
        raise RuntimeError(
            "Firebase not initialized -- add a service account key, see backend/README.md."
        )
    return _db


def verify_id_token(id_token: str) -> str:
    """Verifies a Firebase ID token (from the Flutter app's signed-in user) and returns the uid.
    Raises firebase_admin.auth exceptions on invalid/expired tokens -- caller converts to HTTP 401."""
    if _app is None:
        raise RuntimeError(
            "Firebase not initialized -- add a service account key, see backend/README.md."
        )
    decoded = firebase_auth.verify_id_token(id_token)
    return decoded["uid"]
