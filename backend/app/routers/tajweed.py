"""Per-word Tajweed reference: what a word *is*, not what a reciter did.

Every other analysis endpoint in this service answers "how did this recitation
go", and carries all the uncertainty that comes with it -- on learner voices
the recogniser wrongly flags 42.8% of correctly recited clips. These endpoints
answer a different kind of question entirely: which Makhraj does this word
begin from, which rules apply to it, how many counts should its madd be held.

That is a property of the Quran's text, so it is the same for every reciter and
needs no model. It stays available when the phoneme model is not loaded, and
nothing it returns is a guess.

No auth, matching the rest of the reference endpoints: which articulation point
a word starts from is not anyone's personal data.
"""
import json

from fastapi import APIRouter, HTTPException, Query, Request

from ..tajweed_reference import TajweedWord, basmala_prefix_len

router = APIRouter()


def _service(request: Request):
    reference = getattr(request.app.state, "tajweed_reference", None)
    if reference is None or not reference.available:
        raise HTTPException(
            status_code=503,
            detail="The Tajweed reference table isn't installed on this server. "
                   "Generate it with ml/tools/extract_tajweed_reference.py.",
        )
    return reference


def _parse_makhraj_set(raw: str | None) -> list[str]:
    """`'["ash_shafatain","taraf_al_lisan_szs"]'` -> `["ash_shafatain", ...]`."""
    if not raw:
        return []
    try:
        parsed = json.loads(raw)
    except (TypeError, ValueError):
        return []
    return [str(item) for item in parsed] if isinstance(parsed, list) else []


def _serialise(word: TajweedWord) -> dict:
    return {
        "surah": word.surah,
        "ayah": word.ayah,
        "word_index": word.word_index,        # 1-based, Basmala excluded
        "word_ar": word.word_ar,
        "word_tr": word.word_tr,
        "makhraj": {
            "id": word.makhraj,
            "letters": word.makhraj_letters,
            "english": word.makhraj_english,
        },
        # Every articulation point the word touches, not just the one it starts
        # from -- a word is rarely a single place of articulation. The column
        # stores this as a JSON array string, so it is parsed rather than split:
        # splitting on commas leaves the brackets and quotes attached.
        "makhraj_set": _parse_makhraj_set(word.makhraj_set),
        "rules": word.rules,
        "madd_length": word.madd_length,
        "detail": {
            "qalqalah_class": word.qalqalah_class,
            "ghunnah_type": word.ghunnah_type,
            "tafkheem_class": word.tafkheem_class,
        },
        "n_phones": word.n_phones,
    }


@router.get("/tajweed/word/{surah}/{ayah}/{word_index}")
async def get_word(request: Request, surah: int, ayah: int, word_index: int,
                   index_base: str = Query(
                       "display",
                       pattern="^(display|reference)$",
                       description="'display' (default) is the app's own index: "
                                   "0-based and counting the Basmala the reading "
                                   "page prepends. 'reference' is the table's own: "
                                   "1-based, Basmala excluded.")):
    """One word's Tajweed expectation.

    Defaults to the app's indexing because that is what a caller holding a
    WordPhonemeResult or a tapped word on the reading page actually has. The
    conversion is done in one place (tajweed_reference), so no caller has to
    know that S108:A1 shows seven words while the table holds three.
    """
    reference = _service(request)

    if index_base == "display":
        prefix = basmala_prefix_len(surah, ayah)
        if word_index < prefix:
            # Not an error: the Basmala genuinely has no entry under this
            # surah, and saying so is more useful than a bare 404.
            raise HTTPException(
                status_code=404,
                detail={
                    "error": "basmala_word",
                    "message": f"Word {word_index} of surah {surah} ayah {ayah} is part "
                               f"of the Basmala, which carries its own Tajweed under "
                               f"surah 1 ayah 1 rather than this surah.",
                    "basmala_prefix_len": prefix,
                },
            )
        word = reference.word_for_display(surah, ayah, word_index, prefix)
    else:
        word = reference.word(surah, ayah, word_index)

    if word is None:
        raise HTTPException(
            status_code=404,
            detail=f"No Tajweed reference for surah {surah} ayah {ayah} "
                   f"word {word_index} ({index_base} index).",
        )
    return _serialise(word)


@router.get("/tajweed/ayah/{surah}/{ayah}")
async def get_ayah(request: Request, surah: int, ayah: int):
    """Every word of one ayah.

    The reading page needs all of them at once; fetching word by word would be
    one request per word for something that never changes.
    """
    reference = _service(request)
    words = reference.ayah(surah, ayah)
    if not words:
        raise HTTPException(
            status_code=404,
            detail=f"No Tajweed reference for surah {surah} ayah {ayah}.")

    prefix = basmala_prefix_len(surah, ayah)
    return {
        "surah": surah,
        "ayah": ayah,
        # So a client can map its own 0-based display indices onto these
        # without duplicating the rule.
        "basmala_prefix_len": prefix,
        "word_count": len(words),
        "rule_summary": {
            rule: sum(1 for w in words if rule in w.rules)
            for rule in ("ghunnah", "shaddah", "madd", "qalqalah", "tafkheem")
        },
        "words": [_serialise(w) for w in words],
    }


@router.get("/tajweed/examples/{rule}")
async def get_examples(request: Request, rule: str,
                       limit: int = Query(20, ge=1, le=200),
                       surah: int | None = None):
    """Real Quranic words that carry a rule, for the Tajweed rules screen.

    Lets a rule be taught with words from the Quran itself rather than a
    hand-written example list that has to be maintained separately.
    """
    reference = _service(request)
    words = reference.words_with_rule(rule, limit=limit, surah=surah)
    if not words:
        raise HTTPException(
            status_code=404,
            detail=f"Unknown rule '{rule}'. Available: ghunnah, shaddah, madd, "
                   f"qalqalah, tafkheem.")
    return {"rule": rule, "count": len(words), "words": [_serialise(w) for w in words]}
