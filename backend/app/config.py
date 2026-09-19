import os
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parent.parent


def _load_dotenv(path: Path) -> None:
    """Read KEY=value lines from backend/.env into the environment.

    A few lines rather than python-dotenv: the backend's pinned packages are
    load-bearing (the live-recording socket depends on them), so a new
    dependency for this is not worth the risk. Variables already set in the
    real environment win -- the file only fills gaps.
    """
    if not path.exists():
        return
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))


_load_dotenv(BACKEND_DIR / ".env")

# Rattil AI's assistant (Google Gemini, free tier). Unset key = the assistant
# is simply off: the app keeps its own rule-based reading of requests.
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY", "")
GEMINI_MODEL = os.environ.get("GEMINI_MODEL", "gemini-3.8-flash")

# Firebase project ID from frontend/lib/firebase_options.dart -- not itself a secret, but the
# service account key (path below) is and must never be committed. See README.md for how to
# obtain it; only the project owner can generate this from the Firebase console.
FIREBASE_PROJECT_ID = "makharijpro-ai-9606e"
FIREBASE_SERVICE_ACCOUNT_PATH = Path(
    os.environ.get("FIREBASE_SERVICE_ACCOUNT_PATH", str(BACKEND_DIR / "serviceAccountKey.json"))
)
