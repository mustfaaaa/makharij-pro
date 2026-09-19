"""Rattil AI's assistant: Google Gemini, allowed to act only through the app.

What this adds
--------------
Rattil already reads requests with a rule-based parser in the app
(frontend/lib/services/rattil_request_parser.dart) -- surahs, ayat, reciters,
player commands, Tajweed rules. That stays first: it is instant, free, works
offline and is tested. Only a message it cannot read comes here, so the model
handles what rules cannot ("how do I fix my ghunnah mistakes?") and nothing
that rules already handle well.

The one rule this module exists to keep
---------------------------------------
The model never supplies Quranic text. A language model can misremember an
ayah or blend two that sound alike -- the QDAT dataset card did exactly that,
naming 2:32 for a recording of 5:109 -- and in a Quran app a misquotation is
the worst mistake there is. So the model is given tools instead of licence:

  find_recitation      the app plays the verified audio and shows the text
                       from its own verified asset
  show_tajweed_rule    the app shows its own library entry
  get_my_progress,     the user's real numbers, never invented
  get_my_recent_mistakes, get_practice_plan, list_reciters

and anything it writes that looks like vocalised Arabic running on for several
words is removed before it reaches the screen (see scrub_quranic_text). The
system prompt asks for the same thing; the scrubber does not trust that it was
obeyed.

Privacy
-------
On Gemini's free tier, Google uses what is sent to improve its products. So
nothing identifying goes: no user id, name or email -- only the message, a few
turns of the conversation, and whatever aggregate numbers a tool returns.

Why REST and not Google's SDK
-----------------------------
No release of google-genai installs alongside this backend's pinned pydantic
(2.10.4) and websockets (17.1); the websockets pin carries the live-recording
socket. httpx is already here, and the REST API is three JSON shapes.
"""
from __future__ import annotations

import logging
import re
from dataclasses import dataclass, field
from typing import Any, Protocol

import httpx

from .quran_metadata import SURAH_AYAH_COUNTS, SURAH_NAMES

logger = logging.getLogger(__name__)

GEMINI_URL = "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"

# Tool round-trips before giving up: enough for "check my mistakes, then play
# the ayah I got wrong", not enough to spin on a confused model.
MAX_ROUNDS = 4
# Earlier turns sent for context. Short: each one is tokens, and on the free
# tier each one is also data Google keeps.
MAX_HISTORY_TURNS = 6
MAX_MESSAGE_CHARS = 600

RULES_IN_LIBRARY = ("makhraj", "ghunnah", "shaddah", "madd", "qalqalah", "ikhfa")
# What the recitation check actually reports (backend/app/tajweed_diff.py).
RULES_CHECKED = ("makhraj", "madd", "ghunnah", "ikhfa", "shaddah")

SYSTEM_PROMPT = """\
You are Rattil, the assistant inside MakharijPro, an app that helps people learn \
to recite the Quran with correct Tajweed. The app records a recitation, checks \
each word, and points out mistakes in makhraj, madd, ghunnah (including ikhfa) \
and shaddah; it does not check qalqalah.

Rules you must follow:
1. Never write Quranic text, an ayah's translation, or which words an ayah \
contains. To let the user hear or read any part of the Quran, call \
find_recitation: the app plays verified audio and shows the verified text itself. \
You may name a surah and ayah numbers.
2. For makhraj, ghunnah, shaddah, madd, qalqalah or ikhfa, call show_tajweed_rule; \
the app shows its own explanation, so add at most one sentence of your own. For \
other rules, describe them briefly and say the app's library does not cover them yet.
3. For the user's own progress, mistakes or practice plan, call the matching tool. \
Never guess or invent numbers.
4. Do not give religious rulings (fatwa), tafsir, or views on scholarly \
disagreements; suggest asking a qualified teacher.
5. Stay on reciting the Quran and using this app; politely decline anything else.
6. Reply in the language and script the user wrote in (English, Urdu, or Roman \
Urdu). Be brief: one to three short sentences, no headings, no lists unless asked.\
"""

TOOLS = [{
    "functionDeclarations": [
        {
            "name": "find_recitation",
            "description": (
                "Play part of the Quran for the user: a whole surah, one ayah, or a "
                "range. The app plays a reciter's verified audio and shows the verified "
                "Arabic text and translation. Use this whenever the user wants to hear, "
                "read or practise any part of the Quran."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "surah": {"type": "integer", "description": "Surah number, 1 to 114."},
                    "ayah_start": {"type": "integer", "description": "First ayah; omit for the whole surah."},
                    "ayah_end": {"type": "integer", "description": "Last ayah; omit for a single ayah or the whole surah."},
                    "reciter": {"type": "string", "description": "Reciter's name, if the user asked for one."},
                },
                "required": ["surah"],
            },
        },
        {
            "name": "show_tajweed_rule",
            "description": "Show the app's own explanation of a Tajweed rule from its library.",
            "parameters": {
                "type": "object",
                "properties": {"rule": {"type": "string", "enum": list(RULES_IN_LIBRARY)}},
                "required": ["rule"],
            },
        },
        {
            "name": "get_my_progress",
            "description": "The user's practice statistics: sessions, average accuracy, day streak, and accuracy per Tajweed rule.",
            "parameters": {"type": "object", "properties": {}},
        },
        {
            "name": "get_my_recent_mistakes",
            "description": "Words the user recently recited with a mistake, and which rule each broke.",
            "parameters": {
                "type": "object",
                "properties": {"limit": {"type": "integer", "description": "How many, at most 15."}},
            },
        },
        {
            "name": "get_practice_plan",
            "description": "The user's personalised practice plan: which rules to work on first, and why.",
            "parameters": {"type": "object", "properties": {}},
        },
        {
            "name": "list_reciters",
            "description": "The reciters available in the app, and which surahs each has.",
            "parameters": {"type": "object", "properties": {}},
        },
    ]
}]


class AssistantUnavailable(Exception):
    """The assistant cannot answer right now; the app falls back to its parser."""


class AssistantBusy(AssistantUnavailable):
    """Gemini's rate limit was reached (HTTP 429) -- a wait, not a failure."""


class AssistantData(Protocol):
    """Where tools get their answers. Injected, so tests need no Firestore."""

    def qaris(self) -> list[dict]: ...
    def progress(self, uid: str) -> dict: ...
    def rule_mastery(self, uid: str) -> dict: ...
    def recent_mistakes(self, uid: str, limit: int) -> list[dict]: ...
    def practice_plan(self, uid: str) -> dict: ...


@dataclass
class AssistantReply:
    text: str
    # What the app should do alongside the text: {"type": "play", ...} or
    # {"type": "rule", "rule": "ghunnah"}.
    actions: list[dict] = field(default_factory=list)


# ── the safety net ─────────────────────────────────────────────────────────

_ARABIC_WORD = r"[؀-ۿݐ-ݿࢠ-ࣿﭐ-﷿ﹰ-﻿]+"
_VOCALISED = re.compile(r"[ً-ْٰۖ-ۭ]")
_ARABIC_RUN = re.compile(rf"{_ARABIC_WORD}(?:[\s،۔.,،]+{_ARABIC_WORD})*")
QURAN_TEXT_PLACEHOLDER = "(the app shows the ayah's text)"


def scrub_quranic_text(text: str, min_words: int = 3) -> str:
    """Remove runs of vocalised Arabic long enough to be a quotation.

    Three or more consecutive Arabic-script words, at least three of which
    carry harakat, is what a quoted ayah looks like -- and the model must not
    quote. A single word ("غُنَّة") survives, and so does Urdu, which is written
    in the same script but without vowel marks; the vowel marks are what tell
    them apart.
    """
    def replace(m: re.Match) -> str:
        words = re.findall(_ARABIC_WORD, m.group(0))
        vocalised = sum(1 for w in words if _VOCALISED.search(w))
        return QURAN_TEXT_PLACEHOLDER if len(words) >= min_words and vocalised >= min_words else m.group(0)

    return _ARABIC_RUN.sub(replace, text)


# ── Gemini over REST ───────────────────────────────────────────────────────

class GeminiClient:
    def __init__(self, api_key: str, model: str, http: httpx.Client | None = None,
                 timeout: float = 30.0):
        if not api_key:
            raise AssistantUnavailable("GEMINI_API_KEY is not set")
        self._key = api_key
        self._model = model
        self._http = http or httpx.Client(timeout=timeout)

    def generate(self, contents: list[dict]) -> dict:
        try:
            r = self._http.post(
                GEMINI_URL.format(model=self._model),
                headers={"x-goog-api-key": self._key, "Content-Type": "application/json"},
                json={
                    "systemInstruction": {"parts": [{"text": SYSTEM_PROMPT}]},
                    "contents": contents,
                    "tools": TOOLS,
                    "toolConfig": {"functionCallingConfig": {"mode": "AUTO"}},
                    # Room for a Gemini 3 model's thinking as well as the short
                    # reply the prompt asks for.
                    "generationConfig": {"maxOutputTokens": 1024},
                },
            )
        except httpx.HTTPError as exc:
            raise AssistantUnavailable(f"could not reach Gemini: {type(exc).__name__}") from exc
        if r.status_code == 429:
            raise AssistantBusy("Gemini rate limit reached")
        if r.status_code >= 400:
            # The body can echo the request; log the status only.
            raise AssistantUnavailable(f"Gemini returned HTTP {r.status_code}")
        return r.json()


# ── the assistant ──────────────────────────────────────────────────────────

class RattilAssistant:
    def __init__(self, client: GeminiClient, data: AssistantData):
        self._client = client
        self._data = data

    def ask(self, uid: str, message: str, history: list[dict] | None = None) -> AssistantReply:
        message = (message or "").strip()[:MAX_MESSAGE_CHARS]
        if not message:
            return AssistantReply("Ask me anything about reciting, or about your practice.")

        contents: list[dict] = []
        for turn in (history or [])[-MAX_HISTORY_TURNS:]:
            role = "model" if turn.get("role") in ("model", "assistant") else "user"
            text = str(turn.get("text", ""))[:MAX_MESSAGE_CHARS]
            if text:
                contents.append({"role": role, "parts": [{"text": text}]})
        contents.append({"role": "user", "parts": [{"text": message}]})

        actions: list[dict] = []
        for _ in range(MAX_ROUNDS):
            response = self._client.generate(contents)
            candidate = (response.get("candidates") or [None])[0]
            if not candidate or not candidate.get("content"):
                logger.info("Gemini gave no candidate: %s",
                            (response.get("promptFeedback") or {}).get("blockReason"))
                return AssistantReply("I can't help with that one -- try asking about a surah, "
                                      "an ayah, or your practice.", actions)
            parts = candidate["content"].get("parts") or []
            calls = [p["functionCall"] for p in parts if "functionCall" in p]
            if not calls:
                if candidate.get("finishReason") == "RECITATION":
                    # Gemini itself stopped because the output matched existing text
                    # too closely -- almost certainly an attempted quotation.
                    return AssistantReply("I'll let the app show the ayah itself.", actions)
                text = "".join(p.get("text", "") for p in parts if not p.get("thought")).strip()
                return AssistantReply(scrub_quranic_text(text) or "Okay.", actions)

            # The model's turn goes back verbatim: Gemini 3 attaches thought
            # signatures to its parts and expects to see them again.
            contents.append({"role": "model", "parts": parts})
            results = []
            for call in calls:
                result, action = self._run_tool(uid, call.get("name", ""), call.get("args") or {})
                if action:
                    actions.append(action)
                results.append({"functionResponse": {"name": call.get("name", ""), "response": result}})
            contents.append({"role": "user", "parts": results})

        return AssistantReply("That took more steps than I can manage -- try asking more simply.", actions)

    # ── tools ─────────────────────────────────────────────────────────────

    def _run_tool(self, uid: str, name: str, args: dict[str, Any]) -> tuple[dict, dict | None]:
        try:
            if name == "find_recitation":
                return self._find_recitation(args)
            if name == "show_tajweed_rule":
                rule = str(args.get("rule", "")).lower()
                if rule not in RULES_IN_LIBRARY:
                    return {"error": f"not in the library; it has {', '.join(RULES_IN_LIBRARY)}"}, None
                return ({"shown": rule, "checked_by_app": rule in RULES_CHECKED,
                         "note": "The app now shows its explanation; add at most one sentence."},
                        {"type": "rule", "rule": rule})
            if name == "get_my_progress":
                stats = self._data.progress(uid)
                return {
                    "sessions": stats.get("total_sessions", 0),
                    "average_accuracy_pct": round(100 * float(stats.get("avg_score", 0.0)), 1),
                    "day_streak": stats.get("day_streak", 0),
                    "accuracy_by_rule_pct": self._data.rule_mastery(uid),
                }, None
            if name == "get_my_recent_mistakes":
                limit = max(1, min(int(args.get("limit") or 8), 15))
                return {"mistakes": self._data.recent_mistakes(uid, limit)}, None
            if name == "get_practice_plan":
                return self._data.practice_plan(uid), None
            if name == "list_reciters":
                return {"reciters": [
                    {"name": q["nameEnglish"],
                     "surahs": "all 114" if len(q.get("availableSurahs", [])) >= 114
                     else f"{len(q.get('availableSurahs', []))}: {sorted(q.get('availableSurahs', []))}"}
                    for q in self._data.qaris()
                ]}, None
        except Exception:
            logger.exception("Rattil tool %s failed", name)
            return {"error": "that information is not available right now"}, None
        return {"error": f"unknown tool {name}"}, None

    def _find_recitation(self, args: dict) -> tuple[dict, dict | None]:
        """Validate a request to play, exactly as strictly as the app's parser does."""
        try:
            surah = int(args.get("surah"))
        except (TypeError, ValueError):
            return {"error": "surah must be a number from 1 to 114"}, None
        if surah not in SURAH_AYAH_COUNTS:
            return {"error": "there are 114 surahs; that number is not one of them"}, None
        count = SURAH_AYAH_COUNTS[surah]

        start = args.get("ayah_start")
        end = args.get("ayah_end")
        start = int(start) if start not in (None, "") else None
        end = int(end) if end not in (None, "") else None
        if start is not None and end is None:
            end = start
        if start is not None:
            start, end = min(start, end), max(start, end)
            if start < 1 or end > count:
                return {"error": f"surah {surah} has {count} ayat; {start}-{end} does not exist"}, None

        qaris = self._data.qaris()
        wanted = str(args.get("reciter") or "").strip().lower()
        chosen = None
        if wanted:
            chosen = next((q for q in qaris if _names_match(wanted, q)), None)
            if chosen is None:
                return {"error": f"no reciter called {wanted!r}; available: "
                                 f"{', '.join(q['nameEnglish'] for q in qaris)}"}, None
            if surah not in chosen.get("availableSurahs", []):
                has = [q["nameEnglish"] for q in qaris if surah in q.get("availableSurahs", [])]
                return {"error": f"{chosen['nameEnglish']} does not have surah {surah}; "
                                 f"{', '.join(has) or 'no reciter'} does"}, None
        else:
            having = [q for q in qaris if surah in q.get("availableSurahs", [])]
            if not having:
                return {"error": f"no reciter has surah {surah} yet"}, None
            chosen = max(having, key=lambda q: len(q.get("availableSurahs", [])))

        name = SURAH_NAMES.get(surah, {}).get("english", f"Surah {surah}")
        where = name if start is None else f"{name} {start}" + ("" if start == end else f"-{end}")
        return ({"playing": where, "reciter": chosen["nameEnglish"],
                 "note": "The app is playing it and showing the text; do not write the text."},
                {"type": "play", "surah": surah, "ayah_start": start, "ayah_end": end,
                 "qari_id": chosen["qariId"]})


def _names_match(wanted: str, qari: dict) -> bool:
    words = re.findall(r"[a-z]+", f"{qari.get('nameEnglish', '')} {qari.get('qariId', '')}".lower())
    distinctive = [w for w in words if len(w) >= 4 and w not in ("abdul", "rahman", "abdurrahmaan")]
    return any(w in wanted or wanted in w for w in distinctive)


# ── production data source ─────────────────────────────────────────────────

class FirestoreAssistantData:
    """The assistant's tools, answered from the same Firestore data the app's
    own screens use -- trimmed to what a reply needs, with no identifiers."""

    def qaris(self) -> list[dict]:
        from .firebase_admin_setup import get_firestore_client

        return [{**d.to_dict(), "qariId": d.id}
                for d in get_firestore_client().collection("qaris").stream()]

    def progress(self, uid: str) -> dict:
        from . import firestore_service

        return firestore_service.compute_progress_stats(uid)

    def rule_mastery(self, uid: str) -> dict:
        from . import firestore_service

        return firestore_service.compute_rule_mastery(uid)

    def recent_mistakes(self, uid: str, limit: int) -> list[dict]:
        from . import firestore_service

        out: list[dict] = []
        for session in firestore_service._fetch_all_sessions(uid):
            surah = session.get("surahNumber")
            for m in session.get("mistakes", []):
                out.append({
                    "surah": surah,
                    "surah_name": SURAH_NAMES.get(surah, {}).get("english"),
                    "ayah": m.get("ayahNumber"),
                    "word": m.get("word"),
                    "rule": m.get("errorType"),
                })
                if len(out) >= limit:
                    return out
        return out

    def practice_plan(self, uid: str) -> dict:
        from . import firestore_service

        plan = firestore_service.generate_practice_plan(uid)
        return {
            "plan_type": plan.get("plan_type"),
            # In priority order already. "examples" are Quranic words from the
            # user's own sessions; leaving them out keeps the model from being
            # handed Quran text it might then repeat.
            "recommendations": [
                {k: r.get(k) for k in ("rule", "tajweed_rule", "error_count", "reason") if k in r}
                for r in plan.get("recommendations", [])[:5]
            ],
        }
