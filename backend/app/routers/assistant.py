"""POST /api/v1/rattil/chat -- Rattil AI's assistant, for what its parser can't read.

The app sends a message here only after its own rule-based reader has failed
to understand it, so this sees the open-ended questions ("how do I fix my
ghunnah?") and none of the requests rules already handle. See
app/rattil_assistant.py for what the model is and is not allowed to do.

Signed-in only: its tools read the user's own progress, and the free tier's
limits are shared by everyone using this server.
"""
import asyncio

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field

from ..auth import get_current_uid
from ..rattil_assistant import MAX_HISTORY_TURNS, MAX_MESSAGE_CHARS, AssistantBusy, AssistantUnavailable

router = APIRouter()


class ChatTurn(BaseModel):
    role: str = Field(pattern="^(user|model)$")
    text: str = Field(max_length=MAX_MESSAGE_CHARS * 2)


class ChatRequest(BaseModel):
    message: str = Field(min_length=1, max_length=MAX_MESSAGE_CHARS)
    history: list[ChatTurn] = Field(default_factory=list, max_length=MAX_HISTORY_TURNS * 2)


@router.post("/rattil/chat")
async def rattil_chat(request: Request, body: ChatRequest, uid: str = Depends(get_current_uid)):
    assistant = getattr(request.app.state, "rattil_assistant", None)
    if assistant is None:
        raise HTTPException(
            status_code=503,
            detail="Rattil's assistant isn't set up on this server (GEMINI_API_KEY is not configured).",
        )
    try:
        # The Gemini call is blocking I/O; keep it off the event loop so the
        # live-recording socket on the same server keeps flowing.
        reply = await asyncio.to_thread(
            assistant.ask, uid, body.message, [t.model_dump() for t in body.history])
    except AssistantBusy:
        raise HTTPException(status_code=429,
                            detail="Rattil is getting a lot of questions right now -- try again in a minute.")
    except AssistantUnavailable:
        raise HTTPException(status_code=503, detail="Rattil's assistant can't be reached right now.")
    return {"reply": reply.text, "actions": reply.actions}
