"""backend/.env.example is committed; backend/.env is not. Keep it that way.

.env.example documents which variables exist, and it is tracked in a public
repository. A real key pasted into it -- rather than into the git-ignored
backend/.env beside it -- is one commit away from being published, and a
published key is found and abused within minutes. That nearly happened with
the Gemini key: this catches it while it is still only on disk.
"""
from pathlib import Path

BACKEND = Path(__file__).resolve().parent.parent

# Variables whose value is a secret. Documented in .env.example, never filled.
SECRET_KEYS = {"GEMINI_API_KEY"}


def _entries(path: Path) -> dict[str, str]:
    out = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            key, value = line.split("=", 1)
            out[key.strip()] = value.strip()
    return out


def test_env_example_carries_no_secret_values():
    entries = _entries(BACKEND / ".env.example")
    for key in SECRET_KEYS:
        assert key in entries, f"{key} should be documented in .env.example"
        assert entries[key] == "", (
            f"{key} has a value in backend/.env.example, which is committed to a public "
            f"repository. Move it to backend/.env (git-ignored) and leave the example empty.")


def test_the_real_env_file_is_ignored_by_git():
    ignore = (BACKEND / ".gitignore").read_text(encoding="utf-8").splitlines()
    assert ".env" in [line.strip() for line in ignore]
