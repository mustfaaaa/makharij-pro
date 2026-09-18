"""The Tajweed Drill: the one phrase model v1 was trained on, and a guard.

What model v1 is, and the only place it can be trusted
------------------------------------------------------
`ml/models/makharijpro_tajweed_model_v1` is a small clip-level CNN trained on
QDAT (obadx/qdat): 1,323 clips, 148 speakers, speaker-disjoint split. It gives
three verdicts for a whole recording -- Madd Munfasil, the ghunnah of a
noon mushaddadah, and Ikhfa -- and on held-out speakers it scores 74.8%,
95.6% and 79.1%.

Every one of those clips is the same phrase. So v1's verdicts mean something
for that phrase and nothing for any other: fed a different ayah it still
returns three confident numbers, and they are noise. This module is how the app
uses v1 only where it is valid.

Which phrase -- and why not the one the dataset card names
----------------------------------------------------------
QDAT's dataset card says the recordings are "لا علم لنا إلا ما علمتنا إنك أنت
العليم الحكيم" (Al-Baqarah 2:32). The audio says otherwise. Decoding 40 random
QDAT clips with the production recogniser: 38 end in عَلَّامُ الْغُيُوبِ, none end in
الْعَلِيمُ الْحَكِيمُ, none begin with سُبْحَانَكَ, and 2 were too garbled to read.
The phrase is the close of Al-Ma'idah 5:109:

    قَالُوا لَا عِلْمَ لَنَا إِنَّكَ أَنتَ عَلَّامُ الْغُيُوبِ

The two ayat sound alike, which is presumably how the card went wrong. All
three rules are in it, which also settles what QDAT's 0/1 labels mean: the
card calls them rule *presence*, but every recording of this phrase contains
all three rules, so presence cannot vary. They are "applied correctly or not"
-- as v1's own model card assumed -- and a clip QDAT labels incorrect on all
three audibly shortens the madd, clips the ghunnah and drops the ikhfa.

The guard
---------
Before v1 is consulted, the production recogniser checks the recording is this
phrase: phoneme error rate against the phrase's canonical phonemes must be at
or below GUARD_MAX_PER. That rejects other ayat -- including 2:32, the
near-twin -- and a full recitation of 5:109, whose extra opening words would
also throw off the recording-duration input v1 depends on. The threshold is
not a guess; see ml/eval/calibrate_drill_guard.py for how it was set and what
it accepts and rejects.
"""
from __future__ import annotations

from dataclasses import dataclass

SURAH = 5
AYAH = 109
# Word positions within 5:109 as the app's word mapper numbers them (0-based,
# counting the rub' el hizb and waqf marks as positions). The phrase is the
# ayah's close: قَالُوا ... الْغُيُوبِ.
FIRST_WORD = 9
LAST_WORD = 17

PHRASE_TEXT = "قَالُوا۟ لَا عِلْمَ لَنَآ إِنَّكَ أَنتَ عَلَّٰمُ ٱلْغُيُوبِ"

# Set by ml/eval/calibrate_drill_guard.py -- see there before changing it.
# Measured on 300 QDAT clips against 162 non-attempts: every genuine attempt
# scored <= 0.459 (including clips wrong on all three rules), every
# non-attempt >= 0.656 (the twin 2:32 at 0.820, the whole of 5:109 at 0.951).
# 0.55 sits in the middle of that gap: 100% kept, 100% rejected, with room on
# both sides for voices neither set contains.
GUARD_MAX_PER = 0.55


@dataclass(frozen=True)
class DrillRule:
    task: str             # v1's output head
    rule_id: str          # the app's rule vocabulary (tajweed_diff)
    name: str
    word_index: int       # position in 5:109 of the word the rule lives on
    where: str            # what to listen for, in plain words
    how: str              # what doing it right sounds like


RULES = (
    DrillRule(
        task="separate_tide",
        rule_id="madd",
        name="Madd Munfasil",
        word_index=12,
        where="the alif at the end of لَنَا, just before the hamza of إِنَّكَ",
        how="Hold the alif for about four counts before starting إِنَّكَ -- the "
            "madd is 'separated' because the hamza begins the next word.",
    ),
    DrillRule(
        task="the_tight_noon",
        rule_id="ghunnah",
        name="Ghunnah (Noon Mushaddadah)",
        word_index=14,
        where="the doubled noon in إِنَّكَ",
        how="Hold the nasal hum of the noon for two full counts before the kaf.",
    ),
    DrillRule(
        task="concealment",
        rule_id="ghunnah",
        name="Ikhfa",
        word_index=15,
        where="the noon sakinah in أَنتَ, before the taa",
        how="Don't pronounce the noon fully: hide it into the taa with a light "
            "nasal hum, the tongue already moving toward the taa.",
    ),
)


def phrase_phonemes(service) -> str:
    """The canonical phonemes of the drill phrase, from the app's own mapper,
    so the guard and the rest of the app can never disagree about the text."""
    words = service._mapper.words(SURAH, AYAH)
    return "".join(ph for _display, ph in words[FIRST_WORD:LAST_WORD + 1])


def phrase_words(service) -> list[dict]:
    words = service._mapper.words(SURAH, AYAH)
    return [
        {"word_index": i, "word": display}
        for i, (display, phonemes) in enumerate(words)
        if FIRST_WORD <= i <= LAST_WORD and phonemes
    ]


def edit_distance(a: str, b: str) -> int:
    if a == b:
        return 0
    if not a or not b:
        return len(a) or len(b)
    previous = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        current = [i]
        for j, cb in enumerate(b, 1):
            current.append(min(previous[j] + 1, current[j - 1] + 1,
                               previous[j - 1] + (ca != cb)))
        previous = current
    return previous[-1]


def phrase_distance(service, audio_bytes: bytes) -> tuple[float, str]:
    """(phoneme error rate against the phrase, what the recogniser heard)."""
    reference = phrase_phonemes(service)
    tokens, _ = service._decode(audio_bytes)
    heard = "".join(tokens)
    return edit_distance(heard, reference) / len(reference), heard


def verdicts(v1_results: dict) -> list[dict]:
    """v1's raw per-task output, reshaped around what the reciter needs."""
    out = []
    for rule in RULES:
        r = v1_results[rule.task]
        out.append({
            "rule": rule.name,
            "rule_id": rule.rule_id,
            "task": rule.task,
            "word_index": rule.word_index,
            "correct": r["correct"],
            "confidence": round(r["confidence"], 4),
            "probability_correct": round(r["raw_probability"], 4),
            "where": rule.where,
            "how": rule.how,
        })
    return out
