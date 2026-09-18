"""Rattil AI recitation retrieval (FR-15/FR-17/UC-8). Deliberately simple for now: explicit
surah/ayah numbers, not natural-language request parsing (FR-19) -- that's a layer on top of this
once the frontend chat UI exists to actually need it. No auth required, matching the other public endpoints'
pattern -- listening to a reference recitation isn't tied to a user's personal data the way session
history is.
"""
from fastapi import APIRouter, HTTPException, Request, Response

from ..firebase_admin_setup import get_firestore_client
from ..quran_metadata import SURAH_AYAH_COUNTS, SURAH_NAMES

router = APIRouter()


@router.get("/rattil/qaris")
async def list_qaris():
    """The Qari selector's data source (FR-16)."""
    db = get_firestore_client()
    docs = db.collection("qaris").stream()
    qaris = [doc.to_dict() for doc in docs]
    return {"qaris": qaris}


@router.get("/rattil/recitation")
async def get_recitation(request: Request, qari_id: str, surah: int,
                          ayah_start: int | None = None, ayah_end: int | None = None):
    """Returns playable URLs for the requested ayah range (FR-17). Omit ayah_start/ayah_end for
    the whole surah. REL-3: unavailable requests get a helpful message listing what IS available,
    not a bare 404."""
    db = get_firestore_client()
    qari_doc = db.collection("qaris").document(qari_id).get()
    if not qari_doc.exists:
        available = [d.id for d in db.collection("qaris").stream()]
        raise HTTPException(status_code=404,
                             detail=f"Unknown qari_id '{qari_id}'. Available: {available}")

    qari = qari_doc.to_dict()
    if surah not in qari.get("availableSurahs", []):
        raise HTTPException(
            status_code=404,
            detail=f"Surah {surah} not available for {qari['nameEnglish']}. "
                   f"Available surahs for this qari: {qari['availableSurahs']}",
        )

    if surah not in SURAH_AYAH_COUNTS:
        raise HTTPException(status_code=500, detail=f"Surah {surah} has no ayah-count metadata")
    max_ayah = SURAH_AYAH_COUNTS[surah]

    start = ayah_start or 1
    end = ayah_end or (ayah_start or max_ayah)
    if start < 1 or end > max_ayah or start > end:
        raise HTTPException(
            status_code=400,
            detail=f"Surah {surah} has {max_ayah} ayat -- requested range {start}-{end} is invalid.",
        )

    base_url = str(request.base_url).rstrip("/")
    clips = [
        {"ayah": ayah, "url": f"{base_url}/media/recitations/{qari_id}/{surah:03d}{ayah:03d}.mp3"}
        for ayah in range(start, end + 1)
    ]

    return {
        "qari_id": qari_id,
        "qari_name": qari["nameEnglish"],
        "surah": surah,
        "surah_name": SURAH_NAMES.get(surah, {}),
        "clips": clips,
    }


@router.get("/rattil/word")
async def get_reference_word(request: Request, surah: int, ayah: int, word_index: int,
                             qari_id: str = "abdurrahmaan_as_sudais"):
    """One word of a reference recitation, as a playable WAV.

    Lets the results screen put the reciter's own word next to a Qari saying the
    same word -- being told an elongation was short means much more beside the
    sound of it done properly. No auth, matching the rest of this router: a
    reference recitation isn't anyone's personal data.

    Coverage is the 15 surahs the repository holds audio for (Al-Fatihah and
    101-114). Anything else gets a 404 that says so.
    """
    service = getattr(request.app.state, "reference_words", None)
    if service is None:
        raise HTTPException(
            status_code=503,
            detail="Reference audio isn't available on this server (phoneme model not loaded).",
        )

    if not service.has(qari_id, surah, ayah):
        raise HTTPException(
            status_code=404,
            detail=f"No reference audio for {qari_id} surah {surah} ayah {ayah}. "
                   f"Available surahs: {sorted(SURAH_AYAH_COUNTS)}",
        )

    wav = service.word_wav(qari_id, surah, ayah, word_index)
    if wav is None:
        raise HTTPException(
            status_code=404,
            detail=f"Word {word_index} could not be located in surah {surah} ayah {ayah}.",
        )

    # Immutable: the reference recordings never change, so a client that has
    # played this word once should never fetch it again.
    return Response(content=wav, media_type="audio/wav",
                    headers={"Cache-Control": "public, max-age=31536000, immutable"})
