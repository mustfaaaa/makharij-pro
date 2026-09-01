import logging

from fastapi import Header, HTTPException
from firebase_admin import auth as firebase_auth

from .firebase_admin_setup import verify_id_token

logger = logging.getLogger(__name__)


async def get_current_uid(authorization: str | None = Header(None)) -> str:
    """FastAPI dependency: requires 'Authorization: Bearer <firebase_id_token>', returns the uid.

    The Flutter app already handles Firebase Auth sign-in client-side (see
    frontend/lib/services/auth_service.dart) -- this only verifies the token it sends, never
    handles credentials directly.

    authorization is optional at the FastAPI level so a missing header reaches this function's
    own 401 rather than FastAPI's generic 422 "field required" -- a caller checking specifically
    for 401 to trigger a sign-in flow shouldn't have to also handle 422 for the same condition.
    """
    if authorization is None or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Expected 'Authorization: Bearer <token>' header")

    id_token = authorization.removeprefix("Bearer ").strip()
    try:
        return verify_id_token(id_token)
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc))
    except firebase_auth.ExpiredIdTokenError:
        raise HTTPException(status_code=401, detail="Token expired -- sign in again")
    except firebase_auth.InvalidIdTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")
    except Exception:
        logger.exception("Token verification failed")
        raise HTTPException(status_code=401, detail="Could not verify token")
