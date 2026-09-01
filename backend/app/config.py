import os
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parent.parent
DEFAULT_MODEL_DIR = BACKEND_DIR.parent / "ml" / "models" / "makharijpro_tajweed_model_v1"

MODEL_DIR = Path(os.environ.get("MAKHARIJ_MODEL_DIR", str(DEFAULT_MODEL_DIR)))
MODEL_PATH = MODEL_DIR / "model.keras"
MODEL_CARD_PATH = MODEL_DIR / "model_card.json"

# Firebase project ID from frontend/lib/firebase_options.dart -- not itself a secret, but the
# service account key (path below) is and must never be committed. See README.md for how to
# obtain it; only the project owner can generate this from the Firebase console.
FIREBASE_PROJECT_ID = "makharijpro-ai-9606e"
FIREBASE_SERVICE_ACCOUNT_PATH = Path(
    os.environ.get("FIREBASE_SERVICE_ACCOUNT_PATH", str(BACKEND_DIR / "serviceAccountKey.json"))
)
