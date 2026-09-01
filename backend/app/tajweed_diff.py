"""Turns a per-word expected-vs-predicted phoneme diff into a *typed* Tajweed
finding with a human-readable explanation, instead of a bare edit distance.

This is possible because the Quran-Lab phoneme alphabet
(models_cache/quran-lab-zipformer/phoneme_units.json) encodes the Tajweed
features directly into the character stream rather than as separate symbols:

  - elongation (madd)  -> a run of repeated  ا / ۥ / ۦ , run length == madd count
  - ghunnah            -> a run of 3+ repeated  م / ن
  - shaddah            -> a consonant written twice ( رر , لل , تت , ... )
  - ikhfa              -> the dedicated  ں  (noon) /  ۾  (meem) symbols
  - qalqalah           -> the  ڇ  marker

So collapsing both strings into (character, repeat-count) runs and diffing the
runs recovers *which* rule was broken, not just that something differed.

Tolerances: the recognizer's own documented phoneme error rate is ~3.65% on
real audio, and its resolution on madd/ghunnah run-lengths is coarser than
that -- measured directly here, it transcribes Abdurrahmaan As-Sudais's
ٱلرَّحِيمِ as ررَحِۦۦم (2 counts) where the reference sequence says
ررَحِۦۦۦۦم (4 counts). Flagging that would tell a user that a professional
Qari made a mistake, so the length thresholds below are deliberately loose:
they fire on a *dropped* or *grossly* wrong elongation, not on the recognizer's
own +/-2 count jitter. False negatives are recoverable here; false positives
destroy the user's trust in every other verdict on the screen.
"""
from dataclasses import dataclass

# Vowel-lengthening carriers. A run of N of these means "held for N counts".
ELONGATION_CHARS = frozenset("اۥۦ")
# Nasalized letters. A run of 3+ is the ghunnah hum; a run of exactly 2 is a
# plain shaddah on that letter, handled by the shaddah branch instead.
NASAL_CHARS = frozenset("من")
# Dedicated ikhfa markers (noon / meem hidden into the following letter).
IKHFA_CHARS = frozenset("ں۾")
# Marks that ride on a letter rather than being letters themselves. A diff in
# these alone is below the recognizer's reliable resolution, so it never flags
# a word on its own.
MARK_CHARS = frozenset("َُؙِ۪ۜڇـ")

# See the module docstring: these are recognizer-jitter guards, not Tajweed
# leniency. A madd is only called wrong when it is off by more than this many
# counts, or when it was essentially not held at all.
MADD_COUNT_TOLERANCE = 2
MADD_DROPPED_MAX = 1       # <=1 count heard where >=4 were required == not held
GHUNNAH_COUNT_TOLERANCE = 2
GHUNNAH_DROPPED_MAX = 1

# Error type ids -- these are the strings the Flutter client maps to its
# TajweedErrorType enum, so they must stay in sync with
# frontend/lib/models/tajweed_error.dart.
MADD = "madd"
GHUNNAH = "ghunnah"
SHADDAH = "shaddah"
MAKHRAJ = "makhraj"
SKIPPED = "skipped"


# Which finding gets to speak for the word when several fire at once. A named
# rule the user can actually go and practise beats a generic "that letter was
# off", so the specific rules rank above MAKHRAJ.
SEVERITY_ORDER = (SKIPPED, MADD, GHUNNAH, SHADDAH, MAKHRAJ)
MAX_REPORTED_FINDINGS = 2
# Past this many findings the word wasn't "mispronounced in one way", it just
# didn't match -- listing every letter reads as noise and isn't actionable.
GARBLED_FINDING_COUNT = 4

# How many generic articulation findings a word needs before it is called a
# makhraj mistake.
#
# MADD / GHUNNAH / SHADDAH / SKIPPED each measure a specific, named quantity, so
# one of them is evidence on its own. MAKHRAJ is the catch-all for "these
# letters did not match", which is also where the recognizer's own error lands:
# on 773 labelled learner recordings it accounted for 168 of the 249 wrongly
# flagged words.
#
# Left at 1 after being fitted properly (ml/eval/calibrate_thresholds.py,
# speaker-split, 54 settings). Raising it does cut false accusations, but buys
# them at close to 1:1 in missed mistakes, and separation gets *worse* --
# measured on the held-out split:
#
#     1  ->  46.6% false positives, 74.6% detection, 64.0% balanced
#     2  ->  28.1% false positives, 52.0% detection, 62.0% balanced
#     3  ->  23.6% false positives, 36.4% detection, 56.4% balanced
#
# So this constant is not what is limiting the detector, and no value of it
# rescues a 46% false-accusation rate on learner voices. That needs a
# recognizer that holds up on those voices -- see ml/eval/README.md.
MAKHRAJ_MIN_FINDINGS = 1


@dataclass
class Finding:
    error_type: str
    explanation: str


def runs(s: str) -> list[tuple[str, int]]:
    """Collapse a phoneme string into (character, repeat-count) runs."""
    out: list[tuple[str, int]] = []
    for ch in s:
        if out and out[-1][0] == ch:
            out[-1] = (ch, out[-1][1] + 1)
        else:
            out.append((ch, 1))
    return out


def align(a, b) -> tuple[int, list[tuple[int | None, int | None]]]:
    """Levenshtein DP with backtrace over any two sequences (str or list).

    Returns (distance, pairs) where each pair is (index_in_a | None,
    index_in_b | None) in left-to-right order: a match/substitution pairs two
    indices, a deletion (extra element in `a`) has None on the b side, and an
    insertion (element of `b` missing from `a`) has None on the a side.
    """
    n, m = len(a), len(b)
    dp = [[0] * (m + 1) for _ in range(n + 1)]
    for i in range(n + 1):
        dp[i][0] = i
    for j in range(m + 1):
        dp[0][j] = j
    for i in range(1, n + 1):
        ai = a[i - 1]
        row, prev = dp[i], dp[i - 1]
        for j in range(1, m + 1):
            if ai == b[j - 1]:
                row[j] = prev[j - 1]
            else:
                row[j] = 1 + min(prev[j], row[j - 1], prev[j - 1])

    i, j = n, m
    pairs: list[tuple[int | None, int | None]] = []
    while i > 0 or j > 0:
        if i > 0 and j > 0 and a[i - 1] == b[j - 1] and dp[i][j] == dp[i - 1][j - 1]:
            pairs.append((i - 1, j - 1)); i -= 1; j -= 1
        elif i > 0 and j > 0 and dp[i][j] == dp[i - 1][j - 1] + 1:
            pairs.append((i - 1, j - 1)); i -= 1; j -= 1  # substitution
        elif i > 0 and dp[i][j] == dp[i - 1][j] + 1:
            pairs.append((i - 1, None)); i -= 1           # deletion (extra predicted)
        else:
            pairs.append((None, j - 1)); j -= 1           # insertion (missing predicted)
    pairs.reverse()
    return dp[n][m], pairs


def _kind(ch: str, count: int) -> str:
    if ch in ELONGATION_CHARS:
        return MADD
    if ch in NASAL_CHARS and count >= 3:
        return GHUNNAH
    if ch in IKHFA_CHARS:
        return "ikhfa"
    if count >= 2:
        return SHADDAH
    return MAKHRAJ


def classify(display_word: str, expected: str, predicted: str) -> list[Finding]:
    """Diff one word's expected vs. predicted phonemes into typed findings.

    An empty `predicted` means the word was not heard at all. Returns [] when
    nothing exceeded the tolerances above -- i.e. the word counts as correct.
    """
    if not expected:
        return []
    if not predicted.strip():
        return [Finding(SKIPPED, f"You skipped “{display_word}” — it was not recited.")]

    exp_runs, pred_runs = runs(expected), runs(predicted)
    _dist, pairs = align(pred_runs, exp_runs)

    findings: list[Finding] = []
    for pi, ei in pairs:
        p_ch, p_n = pred_runs[pi] if pi is not None else (None, 0)
        e_ch, e_n = exp_runs[ei] if ei is not None else (None, 0)

        if ei is None:
            # Extra sound the reference does not have. Repeats and hesitations
            # are common and harmless; only an added full letter is worth saying.
            if p_ch not in MARK_CHARS and p_ch not in ELONGATION_CHARS and p_n >= 2:
                findings.append(Finding(
                    MAKHRAJ,
                    f"An extra “{p_ch}” sound was added in “{display_word}”.",
                ))
            continue

        kind = _kind(e_ch, e_n)

        if p_ch is None:
            # Expected run heard nowhere.
            if kind == MADD:
                findings.append(Finding(
                    MADD,
                    f"The elongation (madd) in “{display_word}” was not held at all — "
                    f"it needs about {e_n} counts.",
                ))
            elif kind == GHUNNAH:
                findings.append(Finding(
                    GHUNNAH,
                    f"The ghunnah (nasal hum) in “{display_word}” was missing — "
                    f"hold the nasal sound for about two counts.",
                ))
            elif kind == SHADDAH:
                findings.append(Finding(
                    SHADDAH,
                    f"The shaddah on “{e_ch}” in “{display_word}” was not pronounced — "
                    f"the letter must be doubled.",
                ))
            elif kind == "ikhfa":
                findings.append(Finding(
                    GHUNNAH,
                    f"The ikhfa in “{display_word}” was not applied — the noon/meem should be "
                    f"hidden into the next letter with a nasal hum.",
                ))
            elif e_ch not in MARK_CHARS:
                findings.append(Finding(
                    MAKHRAJ,
                    f"The letter “{e_ch}” in “{display_word}” was not pronounced.",
                ))
            continue

        if p_ch != e_ch:
            # Different letter heard. A difference involving only diacritic
            # marks is below the recognizer's reliable resolution -- never flag
            # a word on that alone.
            if e_ch in MARK_CHARS or p_ch in MARK_CHARS:
                continue
            findings.append(Finding(
                MAKHRAJ,
                f"In “{display_word}” the letter “{e_ch}” came out closer to “{p_ch}” — "
                f"check its articulation point (makhraj).",
            ))
            continue

        # Same character, different hold length.
        if p_n == e_n:
            continue
        if kind == MADD:
            too_short = p_n < e_n
            dropped = too_short and e_n >= 4 and p_n <= MADD_DROPPED_MAX
            if dropped or abs(p_n - e_n) > MADD_COUNT_TOLERANCE:
                how = "too short" if too_short else "too long"
                findings.append(Finding(
                    MADD,
                    f"The elongation (madd) in “{display_word}” was {how} — about {p_n} "
                    f"counts were held where roughly {e_n} are required.",
                ))
        elif kind == GHUNNAH:
            if p_n <= GHUNNAH_DROPPED_MAX or abs(p_n - e_n) > GHUNNAH_COUNT_TOLERANCE:
                findings.append(Finding(
                    GHUNNAH,
                    f"The ghunnah (nasal hum) on “{e_ch}” in “{display_word}” was too short — "
                    f"hold it for about two counts.",
                ))
        elif kind == SHADDAH and p_n < e_n:
            findings.append(Finding(
                SHADDAH,
                f"The shaddah on “{e_ch}” in “{display_word}” was not held — "
                f"the letter must sound doubled.",
            ))

    return findings


def summarize(display_word: str, findings: list[Finding]) -> Finding | None:
    """Reduce a word's findings to the one verdict shown to the user.

    Returns None when the word is correct.
    """
    if not findings:
        return None
    # A word explained only by generic letter mismatches needs enough of them
    # to outweigh recognizer noise; a named rule always speaks for itself.
    if all(f.error_type == MAKHRAJ for f in findings) and len(findings) < MAKHRAJ_MIN_FINDINGS:
        return None
    if len(findings) >= GARBLED_FINDING_COUNT:
        return Finding(
            MAKHRAJ,
            f"Most of “{display_word}” did not match the expected pronunciation — "
            f"recite it again slowly, letter by letter.",
        )
    ranked = sorted(findings, key=lambda f: SEVERITY_ORDER.index(f.error_type)
                    if f.error_type in SEVERITY_ORDER else len(SEVERITY_ORDER))
    kept = ranked[:MAX_REPORTED_FINDINGS]
    return Finding(kept[0].error_type, " ".join(f.explanation for f in kept))
