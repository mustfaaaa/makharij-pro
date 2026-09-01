"""Text normalization for looking up quran_text2phoneme.json, extracted
byte-exact from models_cache/quran-lab-zipformer/quran_per_eval.py (not
retyped) -- hand-typing Arabic combining-mark sequences through an LLM can
silently reorder them into a visually-identical but byte-different string.
That is exactly what happened on the first attempt here: a retyped copy of
the diacritic regex over-matched and stripped real base letters, not just
diacritics, breaking every lookup. This file must never be hand-edited for
its regex/replacement content -- only re-extracted from the source script.
"""
import re
import unicodedata

_DIAC = re.compile(r'[ؐ-ًؚ-ٰٟۖ-ۭـ]')
def norm(s):
    s = unicodedata.normalize("NFC", str(s)); s = _DIAC.sub('', s)
    for a, b in [('أ','ا'),('إ','ا'),('آ','ا'),('ٱ','ا'),('ى','ي'),('ة','ه'),('ؤ','و'),('ئ','ي')]:
        s = s.replace(a, b)
    return re.sub(r'\s+', ' ', s).strip()
