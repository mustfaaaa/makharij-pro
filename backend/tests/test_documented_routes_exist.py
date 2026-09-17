"""Every route the README documents must actually be served.

Why this exists
---------------
`backend/README.md` claimed `POST /api/v1/sessions/{id}/reattempt` was "done,
verified end-to-end". No such route existed anywhere in the app -- the
rule-granularity version it described had been lost in the move to word-level
analysis, and the row was never corrected. A reader had no way to tell, and a
committee asking to see FR-8 would have found nothing behind the claim.

One stale row is a mistake; a README that can go stale silently is a defect.
This reads the endpoint list out of the README itself and asserts the app
serves each one, so the document cannot drift from the code again without a
test going red.

It deliberately does not check behaviour -- only that the route is there. What
each endpoint does is pinned by its own tests; this pins the far cheaper
failure of documenting something that does not exist at all.
"""
import re
import sys
from pathlib import Path

import pytest

BACKEND = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BACKEND))

README = BACKEND / "README.md"

# Documented with a path parameter whose name differs between prose and code;
# compared by shape rather than by parameter name (see _normalise).
PARAM = re.compile(r"\{[^}]+\}")

# Lines like: - `POST /api/v1/sessions/{session_id}/reattempt` — ...
DOCUMENTED = re.compile(r"`(GET|POST|PUT|DELETE|PATCH)\s+(/[^`\s]*)`")


def _normalise(path: str) -> str:
    """Path with the query string dropped and every {parameter} placeheld.

    The README writes example query strings inline
    (`/rattil/recitation?qari_id=...`) and writes `{session_id}` where the
    router may write `{sessionId}`. Neither is a missing endpoint, and this
    test is about missing endpoints.
    """
    return PARAM.sub("{}", path.split("?", 1)[0].rstrip("/"))


def _documented_endpoints() -> set[tuple[str, str]]:
    text = README.read_text(encoding="utf-8")
    found = set()
    for method, path in DOCUMENTED.findall(text):
        if path.startswith("/api/"):
            found.add((method.upper(), _normalise(path)))
    return found


def _served_endpoints() -> set[tuple[str, str]]:
    from app.main import app

    served = set()
    for route in app.routes:
        for method in getattr(route, "methods", set()) or set():
            served.add((method.upper(), _normalise(route.path)))
    return served


def test_the_readme_documents_some_endpoints():
    """Guards the test itself: a regex that silently matches nothing would
    make every assertion below vacuously true."""
    assert len(_documented_endpoints()) >= 8


@pytest.mark.parametrize("endpoint", sorted(_documented_endpoints()))
def test_every_documented_endpoint_is_served(endpoint):
    method, path = endpoint
    served = _served_endpoints()
    assert endpoint in served, (
        f"backend/README.md documents {method} {path}, but the app serves no "
        f"such route. Either build it or correct the README -- a claim nobody "
        f"can check is worse than an admitted gap."
    )
