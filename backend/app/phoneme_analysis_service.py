"""Real word-level Tajweed analysis via the Quran-Lab phoneme model
(user-approved integration, see makharij_audit). Replaces the earlier
wav2vec2+DTW approach, which depended on a checkpoint that never finished
downloading -- this model gives both phoneme recognition AND per-token
timestamps from a single streaming pass, verified end-to-end against 8 real
Rattil clips (6/8 exact matches, 4.1% aggregate character error, consistent
with the model's own documented ~3.65% real-audio phoneme error rate).

Not a black box: every word-level verdict below traces back to (a) the
model's actual predicted phoneme tokens and their real timestamps, and
(b) the model's own documented expected phoneme sequence for that exact
ayah (ordered_quran_phonemes.json) -- never a fabricated or random result.

Scope note: analysis runs over an *ayah range* (a whole surah by default), not
a single ayah. A user recites continuously and stops wherever they stop, so
scoring one hardcoded ayah made every word after it look like a mistake --
the recognizer transcribed the rest of the surah correctly and the comparison
had nowhere to put it. `analyze_range` aligns the whole recitation against the
whole range and reports how far the user actually got, so words beyond that
point are reported as "not recited" rather than as errors.
"""
import io
import json
import logging
import threading
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path

import librosa
import numpy as np
import sherpa_onnx

from . import tajweed_diff
from .tajweed_diff import align as _align
from .word_mapping import WordMapper

logger = logging.getLogger(__name__)

MODEL_DIR = Path(__file__).resolve().parent.parent / "models_cache" / "quran-lab-zipformer"
SAMPLE_RATE = 16000

# A word counts as actually heard when at least this fraction of its expected
# phoneme characters matched, and at least this many characters matched
# outright. Below either bar the word is skipped (inside the recited span) or
# never reached (outside it). The absolute floor matters as much as the ratio:
# Arabic phoneme strings share a handful of very common characters, so a long
# unrecited word can pick up a 1-in-3 "match" purely by chance from alignment
# spill -- measured, ٱلضَّآلِّينَ scored 0.35 off a recitation that stopped two
# ayahs earlier, which was enough to claim the user had recited the whole surah.
HEARD_MATCH_RATIO = 0.5
HEARD_MATCH_MIN_CHARS = 3

# A word may only *extend* the recited span on stronger evidence than a word
# sitting inside it. Measured over 213 stop points built from reference Qari
# recitations (ml/eval/crossmodel/measure_recited_spill.py): 25.4% of them
# reported words the recording did not contain, 4.5 on average, and the first
# spilled word was *always* the opening word of the next ayah. That is the tail
# of the real recitation being attributed forward across the boundary.
#
# The asymmetry decides the thresholds. A weak match inside the span is a
# mispronunciation worth reporting. A weak match at the very end is usually
# audio that does not exist, and showing a reciter words they never said as
# "recited" costs far more trust than greying out one genuinely-final word that
# was cut short. So the tail is judged strictly and the interior is not.
#
# 0.75 was the first value tried and it left a clear failure behind: stopping
# Al-Fatihah at "al-'aalameen" still dragged three words of ayah 4 in, because
# ad-deen scored exactly 0.75 off the tail of al-'aalameen -- the two share
# their whole ending. Re-measured over the same 213 stop points, with the
# zero-evidence rule below also in force:
#
#     tail 0.75 -> 17/213 cases spill, 45 words wrong
#     tail 0.85 ->  9/213 cases spill, 27 words wrong
#
# That measurement looked only at truncated recitations, which turned out to be
# half the picture. Sweeping the labelled learner corpus (773 *finished*
# recitations) against the same 213 truncation points showed the two regimes
# pulling in opposite directions:
#
#     ratio   learner: caught   wrongly unread  | truncated: spill
#      0.5            73.3%           14.2%     |   14.1%  (66 words)
#      0.65           69.8%           15.9%     |    8.0%  (45 words)
#      0.75           67.9%           16.8%     |    8.0%  (45 words)
#      0.85           61.7%           25.3%     |    4.2%  (27 words)
#
# No single value is good at both, and choosing one is the wrong move anyway:
# the regimes are distinguishable. The bar exists to stop the span reaching into
# text the reciter never got to, and when the span already ends at the last word
# of the requested range there is no such text for it to protect. So
# _recited_span exempts that case (see its `at_range_end`), which keeps this
# strict for the reciter who stopped part-way without charging the reciter who
# finished for it.
TAIL_EXTEND_RATIO = 0.85
TAIL_EXTEND_MIN_CHARS = 4

# How many words past the last confidently-heard one to keep in view when
# re-aligning. A word the user only got halfway through never clears the
# "heard" bar itself, so trimming exactly at the last heard word would push its
# audio onto the previous word instead.
TRAILING_MARGIN_WORDS = 2
# The re-align loop converges in one or two rounds in practice; the cap only
# guards against a pathological input oscillating.
MAX_REALIGN_ROUNDS = 3

# How many words ahead of the live cursor `live_advance` looks. Two ayahs'
# worth is far more than a reciter covers between updates, and keeping it small
# is what stops the cursor from matching identical text elsewhere in the surah.
LIVE_LOOKAHEAD_WORDS = 12
# Phonemes the live cursor will let pile up unmatched before it gives up on the
# word it is waiting for and resynchronizes onto the next word it did hear --
# roughly two words' worth, so a single mispronounced word doesn't freeze the
# highlight for the rest of the recitation.
LIVE_RESYNC_TAIL_CHARS = 20
# The same wait, but at the very opening, where the cursor has not confirmed a
# single word yet. The expected text starts at the Basmala; a reciter may begin
# at the ayah itself, or say the ta'awwudh first. With the general wait the
# highlight sat still for a measured 5 seconds at the top of Al-Mulk -- the
# whole of its first ayah. Nothing is being tracked yet, so there is no cursor
# to lose: about one word of phonemes is evidence enough for where they began,
# and the frontier bar below still has to be cleared before anything lights up.
LIVE_START_RESYNC_TAIL_CHARS = 10
# How much wider than the recognized tail the expected-text window may be.
# Just enough slack for the word currently being spoken, no more -- see
# live_advance for what a wide window does to a short tail.
LIVE_WINDOW_SLACK = 1.5
# The word at the *frontier* of a live advance -- the one the cursor is about
# to claim the reciter has just finished -- is judged by the same stricter bar
# the final analysis uses for the end of its span, and for the same reason.
#
# Live it matters more, not less. The frontier word is by construction still
# being spoken: audio for it is only half-arrived, so half its phonemes match,
# so the lenient interior bar (HEARD_MATCH_RATIO, 0.5) clears it and the
# highlight steps onto a word the reciter has not reached. That is what makes
# the highlight run a word -- and at an ayah boundary, a whole line -- ahead of
# the voice.
#
# Holding a word back costs nothing here: the cursor is retried a few times a
# second, so a word withheld now is claimed ~0.35s later once its audio has
# actually arrived. The unconsumed phonemes stay in the tail and are re-matched
# on the next round, so nothing is lost by waiting.
# Pinned rather than tied to TAIL_EXTEND_RATIO. The two happen to share a value
# but answer different questions and were measured separately, so a change to one
# must not silently move the other. This one judges a word still being spoken:
# at 0.85 the live cursor ran ahead of the voice on 0 of 850 updates, against 13
# without it (ml/eval/crossmodel/measure_live_overrun.py).
LIVE_FRONTIER_RATIO = 0.85
LIVE_FRONTIER_MIN_CHARS = TAIL_EXTEND_MIN_CHARS

# How much of the recording's opening is compared against the optional Basmala
# prefix, as a multiple of the Basmala's own phoneme length.
PREFIX_PROBE_SLACK = 1.25

# Alignment is O(len(predicted) x len(expected)) in pure Python. A recitation
# is always a prefix of the requested range, so the expected side is trimmed to
# what the audio could plausibly have covered before the DP runs; anything past
# that is reported as not recited without being aligned at all.
#
# The floor exists only to give a short/garbled recognition (background noise
# eating most of the emitted characters) enough room to still find the words
# it did say -- it must NOT be large enough to admit whole extra ayahs, because
# the re-align loop below only ever *shrinks* this window, never grows it back.
# Measured failure at the old floor of 200: a 3-second, 30-character Bismillah
# recognition got an initial window spanning into ayah 3 -- and because Al-
# Fatihah's ayah 3 ("الرحمن الرحيم") is phonetically identical to the tail of
# ayah 1's Basmala, that distant text scored as a genuine match and never got
# trimmed back out, reporting ayah 2 as confidently mispronounced/skipped
# despite never having been recited at all. 60 chars is roughly one extra
# ayah's worth of slack -- enough for recognizer noise, not enough to reach a
# repeated phrase several ayahs away.
EXPECTED_LENGTH_SLACK = 1.8
EXPECTED_LENGTH_FLOOR = 30
MAX_DP_CELLS = 12_000_000

# ── Long recitations, and recitations that run on into the next surah ────────
#
# One alignment over the whole recording stops working past a few minutes.
# MAX_DP_CELLS caps the expected side at 12M / (recognised characters), and a
# reciter produces 7-8 phoneme characters a second (measured on the bundled
# Qari clips), so past ~2,600 characters the expected text the aligner may see
# is shorter than what was recited. Measured: 18 minutes of Sudais from 2:57 to
# 2:110 came back as 166 of 1,196 words recited, "reached" 2:62, with the rest
# of the audio piled onto the last word it did see.
#
# So a recording longer than SINGLE_PASS_MAX_CHARS is aligned a window at a
# time, each window the same steps as before on a bounded stretch of audio.
# Only words whose audio ends SETTLE_MARGIN_CHARS before the window does are
# settled in it; the rest are aligned again, with what follows them, in the
# next window. Recordings up to SINGLE_PASS_MAX_CHARS (about five minutes)
# take exactly the one pass they always did, so everything measured on them
# still holds.
SINGLE_PASS_MAX_CHARS = 2400
WINDOW_CHARS = 1600
SETTLE_MARGIN_CHARS = 160

# At a surah boundary the next surah is analysed as a segment of its own, from
# its ayah 1, so the optional Basmala check above decides whether the reciter
# said it -- the same check a recitation beginning at that surah gets. While
# the first surah is aligned, the text that follows it is aligned too (at
# least this many words, and as far as the budget reaches), and never scored:
# without somewhere to go, the next surah's audio would pile onto the last
# word of this one (the failure the final cut in _score exists for).
GUARD_WORDS = 12
# Fewer recognised characters than this after a surah's last word is the tail
# of that word or noise, not the start of the next surah.
CONTINUE_MIN_CHARS = 8


@dataclass
class WordPhonemeResult:
    ayah_number: int
    word_index: int          # index of this word within its own ayah
    display_word: str
    predicted_phonemes: str
    expected_phonemes: str
    start_sec: float
    end_sec: float
    correct: bool
    recited: bool            # False == the user never got this far (or started later)
    edit_distance: int
    confidence: float
    error_type: str | None
    explanation: str | None
    # Last, and defaulted, so results built positionally elsewhere still work.
    # A recitation can run from one surah into the next, so an ayah number
    # alone no longer says where a word is.
    surah_number: int = 0


@dataclass
class _Scored:
    """What one alignment pass over part of a recitation concluded."""
    results: list[WordPhonemeResult]
    # How many of the words handed in are decided -- all of them, unless the
    # pass was asked to settle only what lies well before its window's end.
    settled: int
    # How many of the window's recognised characters those words account for.
    consumed: int


class SpanWords:
    """The words a recitation is expected to follow, from where it begins,
    across surah boundaries, read a surah at a time as the cursor needs them.

    Index i is the i-th word of the recitation -- what the live cursor's
    global index counts. Building the rest of the Quran up front for a
    recitation that may stop after three ayahs would be waste, so each surah's
    words are only fetched when the cursor comes within reach of them.
    """

    def __init__(self, service: "PhonemeAnalysisService", start_surah: int, start_ayah: int,
                 end_surah: int, end_ayah: int | None):
        self._service = service
        self._end = (end_surah, end_ayah)
        self._next: tuple[int, int] | None = (start_surah, start_ayah)
        # (index of the segment's first word, surah, the segment's words)
        self._segments: list[tuple[int, int, list]] = []
        self._count = 0

    def _extend(self) -> bool:
        if self._next is None:
            return False
        surah, ayah = self._next
        end_surah, end_ayah = self._end
        last = end_ayah if surah == end_surah and end_ayah is not None else self._service.ayah_count(surah)
        words = self._service._range_words(surah, ayah, last)
        self._segments.append((self._count, surah, words))
        self._count += len(words)
        self._next = (surah + 1, 1) if surah < end_surah and surah < 114 else None
        return True

    def _reach(self, index: int) -> bool:
        while index >= self._count:
            if not self._extend():
                return False
        return True

    def window(self, start: int, size: int) -> list[tuple[int, tuple]]:
        """Up to [size] words from index [start], each as (surah, word)."""
        out: list[tuple[int, tuple]] = []
        index = start
        while len(out) < size and self._reach(index):
            for first, surah, words in self._segments:
                if first <= index < first + len(words):
                    take = words[index - first:index - first + size - len(out)]
                    out.extend((surah, w) for w in take)
                    index += len(take)
                    break
        return out

    def starts_segment(self, index: int) -> bool:
        """Whether word [index] opens a surah -- the recitation's first word, or
        the first of a surah it has run on into."""
        self._reach(index)
        return any(first == index for first, _surah, _words in self._segments)

    def first_segment_length(self) -> int:
        self._reach(0)
        return len(self._segments[0][2]) if self._segments else 0


class PhonemeAnalysisService:
    def __init__(self, model_dir: Path = MODEL_DIR):
        self.recognizer = sherpa_onnx.OnlineRecognizer.from_zipformer2_ctc(
            tokens=str(model_dir / "tokens.txt"),
            model=str(model_dir / "zipformer_p_arabic_v3.1.int8.onnx"),
            num_threads=2,
            sample_rate=SAMPLE_RATE,
            feature_dim=80,
            decoding_method="greedy_search",
            provider="cpu",
        )
        # One recitation analysed at a time. The recognizer is a single shared
        # object, and [analyze_range] is now called from two places that do not
        # wait for each other: a POST from the results screen, and the live
        # socket's per-word check, which runs beside its cursor rather than
        # holding it up. Serialising here keeps that invariant in one place
        # instead of in each caller. The live *cursor* decodes its own stream
        # and is deliberately outside this -- it must never wait on an analysis.
        self._analysis_lock = threading.Lock()

        with open(model_dir / "ordered_quran_phonemes.json", encoding="utf-8") as f:
            self._phoneme_table = json.load(f)

        # Translates the model's phonetic units into the words the app actually
        # displays -- they only coincide for 34% of ayahs. See word_mapping.py.
        self._mapper = WordMapper(self._phoneme_table)

        # surah -> highest ayah number present, so a caller can ask for "the
        # whole surah" without a second metadata source that could drift.
        self._ayah_counts: dict[int, int] = {}
        for key in self._phoneme_table:
            s, a = key.split(":")
            s, a = int(s), int(a)
            if a > self._ayah_counts.get(s, 0):
                self._ayah_counts[s] = a

    def ayah_count(self, surah: int) -> int:
        return self._ayah_counts.get(surah, 0)

    def expected_words(self, surah: int, ayah: int) -> list[str] | None:
        """Expected phonemes per *displayed* word (not per phonetic unit)."""
        words = self._mapper.words(surah, ayah)
        return [phonemes for _display, phonemes in words] if words else None

    def _decode(self, audio_bytes: bytes) -> tuple[list[str], list[float]]:
        y, _ = librosa.load(io.BytesIO(audio_bytes), sr=SAMPLE_RATE, mono=True)
        stream = self.recognizer.create_stream()
        stream.accept_waveform(SAMPLE_RATE, y.astype(np.float32))
        return self.finish_stream(stream)

    def finish_stream(self, stream) -> tuple[list[str], list[float]]:
        """Finish a stream that has been given all of a recording -- in one go
        above, or chunk by chunk by the live socket -- and return its tokens
        and their timestamps. The same either way (see analyze_decoded_span)."""
        # Tail padding: the streaming recognizer needs silence after the last
        # real audio before it will emit the final tokens. 0.5s was not enough
        # -- it clipped the closing letters of whatever word the user stopped
        # on, which then got reported as a dropped madd on the last word of
        # every recitation. 1.5s costs nothing and stops that.
        stream.accept_waveform(SAMPLE_RATE, np.zeros(int(1.5 * SAMPLE_RATE), dtype=np.float32))
        stream.input_finished()
        while self.recognizer.is_ready(stream):
            self.recognizer.decode_stream(stream)
        return self.recognizer.tokens(stream), self.recognizer.timestamps(stream)

    @lru_cache(maxsize=16)
    def _range_words(self, surah: int, from_ayah: int, to_ayah: int):
        """Flatten an ayah range into a list of (ayah, index_in_ayah, display, expected).

        Cached: the live streaming endpoint re-derives a surah's word list on
        every audio chunk, and rebuilding Al-Baqarah's ~6,000 entries several
        times a second is pure waste -- the table it reads is immutable.
        """
        out = []
        for ayah in range(from_ayah, to_ayah + 1):
            for i, (display, expected) in enumerate(self._mapper.words(surah, ayah)):
                out.append((ayah, i, display, expected))
        return out

    def live_advance(self, pred_tail: list[str], surah: int, from_word: int, from_ayah: int = 1):
        """Incrementally move a live recitation cursor forward, for highlighting
        words while the user is still reciting.

        Deliberately not the same code path as [analyze_range]: this runs many
        times per recitation on an incomplete transcript and answers only
        "which word are we on now". The authoritative per-word verdicts still
        come from [analyze_range] once the full recording is uploaded -- a
        half-decoded word must never be shown to the user as a mistake.

        It is also deliberately *incremental*. Re-searching the whole surah on
        every update let a partial transcript match identical text far ahead:
        Al-Fatihah's ayah 3 is literally the tail of its ayah 1, and the live
        cursor measurably jumped to ayah 4 and stuck there while the reciter
        was still on ayah 2. Recitation moves forward through the text, so only
        a small window starting at the current cursor is ever considered, which
        removes that failure by construction (and makes each update cheap
        enough to run several times a second on a 286-ayah surah).

        [pred_tail] is the phoneme characters recognized since the cursor last
        moved. Returns (ayah, word_index_in_ayah, global_word_index,
        chars_consumed) or None if nothing new was confidently matched.
        """
        step = self.live_advance_span(pred_tail, SpanWords(self, surah, from_ayah, surah, None), from_word)
        return None if step is None else step[1:]

    def live_advance_span(self, pred_tail: list[str], span: SpanWords, from_word: int):
        """[live_advance] over a recitation that may run on into later surahs.

        Returns (surah, ayah, word_index_in_ayah, global_word_index,
        chars_consumed), or None. The cursor treats the first word of every
        surah it reaches the way it treats the first word of the recitation:
        that surah opens with a Basmala the reciter may or may not say, and
        waiting out the usual stall on it would freeze the highlight at every
        surah boundary.
        """
        if not pred_tail:
            return None
        ahead = span.window(from_word, LIVE_LOOKAHEAD_WORDS)
        if not ahead:
            return None

        # Size the window by how much audio the tail actually represents, not
        # by a fixed word count. Aligning a 5-character tail against 12 words of
        # expected text let Levenshtein scatter those characters across the
        # whole window -- the trailing "مِ" of بِسْمِ matched an "م" two ayahs
        # later because that cost fewer edits than leaving it unmatched, so the
        # cursor consumed too few characters and the leftovers then matched
        # Al-Fatihah's repeated لِلَّهِ / ٱلرَّحِيمِ further on. Keeping the
        # expected side just wider than the tail removes the room to do that.
        budget = max(int(len(pred_tail) * LIVE_WINDOW_SLACK), 1)
        window, surahs, used = [], [], 0
        for surah, w in ahead:
            if window and used >= budget:
                break
            window.append(w)
            surahs.append(surah)
            used += len(w[3])
        if not window:
            return None

        pred_by_word, matched_counts, _errors = self._attribute(pred_tail, window)
        heard = self._heard_flags(matched_counts, window)

        # Advance only over the *contiguous* run of heard words starting at the
        # cursor. Taking the furthest heard word in the window instead let the
        # cursor teleport: Al-Fatihah's ٱلرَّحِيمِ appears in both ayah 1 and
        # ayah 3, so a tail matching "the rahim word" jumped several ayahs
        # ahead and then ran off the end of the surah.
        advanced = 0
        while advanced < len(window) and heard[advanced]:
            advanced += 1

        if advanced == 0:
            # Stalled: the word at the cursor was not recognized (mispronounced,
            # or swallowed by noise). Wait a little in case it is still being
            # decoded, then resynchronize onto the next word we *did* hear
            # rather than freezing the highlight for the rest of the recitation.
            opening = span.starts_segment(from_word)
            if len(pred_tail) < (LIVE_START_RESYNC_TAIL_CHARS if opening
                                 else LIVE_RESYNC_TAIL_CHARS):
                return None
            if opening:
                # Look over the whole opening lookahead rather than the window
                # the tail's length paid for: the reciter may have started
                # several words in (see LIVE_START_RESYNC_TAIL_CHARS), and a
                # short tail buys a window too narrow to contain the word they
                # actually began with.
                window = [w for _surah, w in ahead]
                surahs = [surah for surah, _w in ahead]
                pred_by_word, matched_counts, _errors = self._attribute(pred_tail, window)
                heard = self._heard_flags(matched_counts, window)
            resync = next((i for i, h in enumerate(heard) if h), None)
            if resync is None:
                return None
            advanced = resync + 1

        # Trim the frontier back to the last word that is strongly matched, not
        # merely heard. Interior words of the run keep the lenient bar -- there
        # a weak match means the reciter said the word poorly, and the cursor
        # should still move past it. See LIVE_FRONTIER_RATIO.
        while advanced > 0:
            expected = window[advanced - 1][3]
            if not expected:
                # A waqf mark is silent, so it is no evidence that the reciter
                # has reached it. Never let one anchor the frontier.
                advanced -= 1
                continue
            matched = matched_counts[advanced - 1]
            if (matched >= min(LIVE_FRONTIER_MIN_CHARS, len(expected))
                    and matched / max(len(expected), 1) >= LIVE_FRONTIER_RATIO):
                break
            advanced -= 1

        if advanced == 0:
            # Nothing in the run is confirmed yet. Consume nothing: those
            # phonemes stay in the tail and are re-matched next round, when
            # more of the word has been decoded.
            return None

        last = advanced - 1
        # Consume every tail character attributed to any confirmed word, not
        # just the final one: a character the alignment parked on an earlier
        # word would otherwise stay in the tail and be re-matched next round.
        assigned = [i for w in pred_by_word[:advanced] for i in w]
        consumed = max(assigned) + 1 if assigned else 0
        ayah, word_index, _display, _expected = window[last]
        return surahs[last], ayah, word_index, from_word + last, consumed

    @staticmethod
    def _heard_flags(word_matched, considered) -> list[bool]:
        """Per word: did enough of its expected phonemes actually match?
        See HEARD_MATCH_RATIO / HEARD_MATCH_MIN_CHARS for why both bars exist."""
        # A word with no phonemes at all is a waqf mark -- written as its own
        # token but silent. There is nothing to hear, so it must never block
        # the cursor or be reported as skipped.
        return [
            not considered[i][3]
            or (
                word_matched[i] >= min(HEARD_MATCH_MIN_CHARS, len(considered[i][3]))
                and word_matched[i] / max(len(considered[i][3]), 1) >= HEARD_MATCH_RATIO
            )
            for i in range(len(considered))
        ]

    @staticmethod
    def _attribute(pred_chars: list[str], considered: list[tuple[int, int, str, str]]):
        """Align the predicted character stream against `considered` and hand every
        aligned pair to the word it belongs to.

        Returns (predicted char indices per word, matched count per word,
        mismatched count per word).
        """
        expected_str = "".join(w[3] for w in considered)
        word_end_offsets = []
        cursor = 0
        for w in considered:
            cursor += len(w[3])
            word_end_offsets.append(cursor)

        _dist, pairs = _align(pred_chars, expected_str)

        n_words = len(considered)
        word_pred_chars: list[list[int]] = [[] for _ in range(n_words)]
        word_matched = [0] * n_words
        word_errors = [0] * n_words
        wi = 0
        seen_expected = False
        # Walk the alignment path in order, assigning every pair to "the word we
        # are currently inside", advancing only when an expected character (ei)
        # crosses into the next word's range.
        for pi, ei in pairs:
            if ei is not None:
                seen_expected = True
                while wi < len(word_end_offsets) - 1 and ei >= word_end_offsets[wi]:
                    wi += 1
            elif not seen_expected:
                # Extra audio *before* the first expected character -- the
                # ta'awwudh or basmala a reciter says before the surah itself,
                # or a throat-clear. Attributing it to word 0 used to flag the
                # very first word of every such recitation.
                continue
            if pi is not None:
                word_pred_chars[wi].append(pi)
            if pi is not None and ei is not None and pred_chars[pi] == expected_str[ei]:
                word_matched[wi] += 1
            else:
                word_errors[wi] += 1
        return word_pred_chars, word_matched, word_errors

    @staticmethod
    def _recited_span(word_pred_chars, word_matched, considered,
                      at_range_end: bool = False):
        """Find [first, last] word indices the recording actually covers.

        Two different questions, deliberately kept apart:
          heard   -- enough of this word matched to be sure the user reached it
          touched -- some of the recording was consumed here, even if it matched
                     badly (i.e. a genuinely mispronounced word)
        The span runs from the first *touched* word to the last *heard* one.
        Using `heard` at both ends marked a badly-recited opening ayah as "never
        recited" instead of as the mistake it was; using `touched` at the far end
        would let alignment drift past the point the user actually stopped.

        [at_range_end] says the last entry of `considered` is also the last word
        of the whole requested range. The tail bar exists to stop the span
        reaching into text the reciter never got to -- and past the end of the
        range there is no such text, so there is nothing for it to protect and a
        reciter who finished has their closing word greyed out for nothing. It
        is the difference between the two regimes this analyser sees: someone
        who stopped part-way (guard the tail) and someone who finished (do not).
        """
        heard = PhonemeAnalysisService._heard_flags(word_matched, considered)
        heard_idxs = [i for i, h in enumerate(heard) if h]
        if not heard_idxs:
            return None, None

        # Walk the trailing heard words back to the last one that clears the
        # stricter tail bar. Only the end of the span moves: an interior word
        # that matched weakly stays in, because there it means the reciter said
        # something wrong rather than nothing at all.
        last = heard_idxs[-1]
        while True:
            if at_range_end and last == len(considered) - 1:
                break          # nothing beyond it to spill into
            expected = considered[last][3]
            if not expected:
                # A waqf mark carries no phonemes, so it is no evidence either
                # way -- keep looking further back rather than trusting it.
                strong = False
            else:
                matched = word_matched[last]
                strong = (matched >= min(TAIL_EXTEND_MIN_CHARS, len(expected))
                          and matched / max(len(expected), 1) >= TAIL_EXTEND_RATIO)
            if strong:
                break
            earlier = [i for i in heard_idxs if i < last]
            if not earlier:
                # Nothing in the whole span clears the tail bar. Rather than
                # collapse the span to nothing, keep the original end: a
                # uniformly weak recitation is still a recitation.
                last = heard_idxs[-1]
                break
            last = earlier[-1]

        touched = [heard[i] or bool(word_pred_chars[i]) for i in range(len(considered))]
        return next(i for i, t in enumerate(touched) if t), last

    def analyze_range(
        self, audio_bytes: bytes, surah: int, from_ayah: int = 1, to_ayah: int | None = None
    ) -> list[WordPhonemeResult]:
        """Align a continuous recitation against ayahs [from_ayah, to_ayah] of `surah`.

        Words the user never reached come back with `recited=False` and no
        error -- they are not mistakes, they are simply where the recording
        stopped.

        Callers may be on different threads; see [_analysis_lock].
        """
        with self._analysis_lock:
            return self._analyze_range(audio_bytes, surah, from_ayah, to_ayah)

    def _analyze_range(
        self, audio_bytes: bytes, surah: int, from_ayah: int, to_ayah: int | None
    ) -> list[WordPhonemeResult]:
        if to_ayah is None:
            to_ayah = self.ayah_count(surah)
        if to_ayah < from_ayah or self.ayah_count(surah) == 0:
            raise ValueError(f"No phoneme reference for surah {surah} ayahs {from_ayah}-{to_ayah}")
        to_ayah = min(to_ayah, self.ayah_count(surah))

        words = self._range_words(surah, from_ayah, to_ayah)
        if not words:
            raise ValueError(f"No phoneme reference for surah {surah} ayahs {from_ayah}-{to_ayah}")

        pred_tokens, pred_times = self._decode(audio_bytes)
        pred_chars, pred_char_token_idx = self._flatten(pred_tokens)
        prefix_len = self._mapper.basmala_prefix_len(surah, from_ayah) if from_ayah == 1 else 0
        return self._score(pred_chars, pred_char_token_idx, pred_times, surah, words,
                           prefix_len=prefix_len).results

    @staticmethod
    def _flatten(pred_tokens) -> tuple[list[str], list[int]]:
        pred_chars: list[str] = []
        pred_char_token_idx: list[int] = []
        for tok_i, tok in enumerate(pred_tokens):
            # Tokens like "للَ" or "ۦۦۦۦ" are several characters; remember which
            # token each character came from so timestamps stay attributable.
            for ch in tok:
                pred_chars.append(ch)
                pred_char_token_idx.append(tok_i)
        return pred_chars, pred_char_token_idx

    def _score(
        self,
        pred_chars: list[str],
        pred_char_token_idx: list[int],
        pred_times,
        surah: int,
        words: list[tuple[int, int, str, str]],
        *,
        prefix_len: int = 0,
        guard: tuple = (),
        settle_before: int | None = None,
    ) -> _Scored:
        """Align recognised characters against [words] of [surah] and judge each
        word -- the one alignment everything here is built on.

        With only [prefix_len] given this is exactly what analyze_range has
        always done: the recording is taken to start at words[0] and to stop
        somewhere in [words], and every word comes back judged.

        [prefix_len]: how many leading words are the optional Basmala.
        [guard]: words that follow [words] in the recitation (the next surah).
        They are aligned against, so audio past the last of [words] has
        somewhere to go, and are never scored.
        [settle_before]: the recording continues past this window. Only words
        whose audio ends before this character index are settled and returned;
        the rest are left for the next window, which will see what follows
        them.
        """
        pred_str = "".join(pred_chars)

        if not pred_str:
            # Nothing recognized at all (silence, or an unusable recording).
            return _Scored([self._unrecited(w, surah) for w in words], settled=len(words), consumed=0)

        # Trim the expected side to what this much audio could plausibly cover,
        # then hard-cap the DP size. Both cuts only ever move words into the
        # "not recited" bucket, which is where they belong anyway -- except the
        # floor must never cut *inside* the requested starting ayah itself: for
        # a short surah with a long Basmala (e.g. Al-'Asr), the Basmala's own
        # ~30 characters can consume the whole EXPECTED_LENGTH_FLOOR, trimming
        # `considered` to exactly the Basmala and discarding the real first
        # word before it is ever compared. Measured: a perfect, exact-match
        # recitation of Al-'Asr's actual ayah 1 ("وَلعَصر") came back as 0%
        # recited because of this. Guaranteeing the floor covers at least the
        # whole starting ayah costs nothing -- the re-align loop below still
        # shrinks back to wherever the recording actually stopped.
        first_ayah_chars = sum(len(w[3]) for w in words if w[0] == words[0][0])
        budget = max(EXPECTED_LENGTH_FLOOR, int(len(pred_str) * EXPECTED_LENGTH_SLACK), first_ayah_chars)
        budget = min(budget, max(1, MAX_DP_CELLS // max(1, len(pred_str))))
        considered: list[tuple[int, int, str, str]] = []
        used = 0
        for w in words:
            if considered and used >= budget:
                break
            considered.append(w)
            used += len(w[3])

        # The Basmala the asset prints above ayah 1 is optional in practice:
        # some reciters say it, reference recordings of a surah usually don't.
        # Expecting it unconditionally dragged the whole alignment four words
        # out of step for a recitation that opened straight into the surah --
        # measured on Al-'Asr, where it flagged all 9 correctly-recited words.
        # So probe for it first, and drop it from the comparison when it simply
        # isn't there; those words come back as "not recited", not as mistakes.
        skipped_prefix: list[tuple[int, int, str, str]] = []
        if 0 < prefix_len < len(considered):
            prefix = considered[:prefix_len]
            # Compare against just the opening of the recording, barely longer
            # than the Basmala itself. Handing the probe twice that much audio
            # let unrelated later phonemes drift back and score as matches --
            # Al-'Asr's opening وَلعَصرءِننننَ... "matched" ٱللَّهِ at 57%.
            expected_chars = sum(len(w[3]) for w in prefix)
            probe_chars = int(expected_chars * PREFIX_PROBE_SLACK) + 4
            _pc, probe_matched, _pe = self._attribute(pred_chars[:probe_chars], prefix)
            heard_count = sum(self._heard_flags(probe_matched, prefix))
            if heard_count * 2 < prefix_len:
                skipped_prefix = prefix
                considered = considered[prefix_len:]

        # How many entries of `considered` are this call's own words; any after
        # them are the guard, aligned against and never scored. The guard only
        # joins once every one of `words` is in reach -- until then the words
        # themselves are "what follows" -- and then it continues the expected
        # text under the same budget, as far as this much audio could reach.
        #
        # A fixed few words were not enough. Twelve words of Aal-E-Imran
        # against two minutes of it let the aligner anchor them on a later
        # repetition of the same phrase (3:2's "la ilaha illa huwa" recurs at
        # 3:6), and the audio of 3:1-2 fell onto the last word of Al-Baqarah.
        own = len(considered)
        if guard and len(skipped_prefix) + own == len(words):
            for i, g in enumerate(guard):
                if i >= GUARD_WORDS and used >= budget:
                    break
                considered.append(g)
                used += len(g[3])

        # Does `considered` still reach the final word of the *requested range*?
        #
        # It must be measured against `words`, not against whatever `considered`
        # happens to be: the expected side has already been trimmed to what this
        # much audio could plausibly cover, so for someone who stopped part-way
        # `considered` ends near their stop point. Comparing it to itself would
        # call that "the end of the range" and waive the tail bar exactly where
        # it is needed -- measured, that put spill back from 4.2% to 12.7%.
        #
        # With a guard the recitation's text goes on past `words`, so there is
        # no range end here to waive the bar for.
        def reaches_range_end(window) -> bool:
            return not guard and len(skipped_prefix) + len(window) == len(words)

        # The first alignment runs against the *whole* requested range, so the
        # expected text continues well past wherever the user actually stopped
        # -- and Levenshtein is free to scatter the closing characters of the
        # last recited word forward onto identical letters in text that was
        # never recited (measured: ررَحِۦۦۦۦم decoded perfectly, but its tail
        # got matched into the next ayah's مَاالِكِ, leaving the last word
        # looking like a dropped madd). So: find the stop point, cut the
        # expected side to just past it, and re-align so those characters have
        # nowhere else to go. Each round can reveal one more genuinely-recited
        # word that the previous round's spill was hiding.
        word_pred_chars = word_matched = word_errors = None
        first_heard = last_heard = None
        for _ in range(MAX_REALIGN_ROUNDS):
            word_pred_chars, word_matched, word_errors = self._attribute(pred_chars, considered)
            first_heard, last_heard = self._recited_span(
                word_pred_chars, word_matched, considered,
                at_range_end=reaches_range_end(considered))
            if last_heard is None:
                break
            limit = min(len(considered), last_heard + 1 + TRAILING_MARGIN_WORDS)
            if limit == len(considered):
                break
            considered = considered[:limit]

        # The margin above exists so span *discovery* can see a half-recited
        # trailing word; it must not survive into the final attribution, or the
        # very last word's closing letters leak onto the identical letter in the
        # margin words (ٱلرَّحِيمِ losing its م to the following مَـٰلِكِ).
        # Cut exactly at the stop point and align one last time.
        if last_heard is not None and last_heard < len(considered) - 1:
            # Trim the predicted characters along with the words.
            #
            # Cutting `considered` alone left the whole predicted stream to be
            # aligned against a shorter expected text, and _attribute gives an
            # unmatched character to whatever word it is currently inside -- so
            # every phoneme past the cut piled onto the last surviving word.
            # That word then read as roughly twice its own length and was
            # flagged (almost always as makhraj), while the word after it was
            # reported as never recited.
            #
            # It was the single largest source of false alarms on real learner
            # recordings: a third of the words wrongly flagged on correctly
            # recited clips carried this signature, mean length ratio 2.08, and
            # it hit the Basmala hardest -- 90% of correct recitations of it
            # were flagged, because ٱلرَّحْمَٰنِ and ٱلرَّحِيمِ share an opening
            # and sit at the end where there is no following text to anchor the
            # boundary.
            #
            # The first pass still has the full expected text, so its
            # attribution says where the kept words really end. Slicing a
            # *prefix* keeps every index valid for pred_char_token_idx.
            kept = [p for i in range(last_heard + 1) for p in word_pred_chars[i]]
            cutoff = max(kept) + 1 if kept else 0
            considered = considered[:last_heard + 1]
            word_pred_chars, word_matched, word_errors = self._attribute(
                pred_chars[:cutoff], considered)
            first_heard, _ = self._recited_span(
                word_pred_chars, word_matched, considered,
                at_range_end=reaches_range_end(considered))
            first_heard = first_heard if first_heard is not None else 0
            last_heard = len(considered) - 1
        # Where `considered` actually sits inside `words`. When the reciter did
        # not say the optional Basmala it was dropped from the front, so
        # `considered` starts `len(skipped_prefix)` words in -- and indexing
        # `words` by its length alone then pointed that many words too early,
        # re-emitting the closing words of the ayah a second time as "never
        # recited" underneath the correct verdicts they had already been given.
        #
        # It is why the first ayah of a surah was the worst-scoring ayah in the
        # book: every one of the forty worst ayahs across the whole Quran was an
        # ayah 1, which is exactly where an unspoken Basmala can be dropped.
        own = min(own, len(considered))
        beyond = words[len(skipped_prefix) + own:]

        results: list[WordPhonemeResult] = []
        for i, (ayah, idx_in_ayah, display, expected_word) in enumerate(considered[:own]):
            in_span = first_heard is not None and first_heard <= i <= last_heard
            if not in_span:
                results.append(self._unrecited(considered[i], surah))
                continue

            pred_idxs = word_pred_chars[i]

            # Inside the span, but the aligner consumed no audio here at all.
            #
            # The span deliberately keeps weakly-matched interior words,
            # because there a poor match means the reciter said the word
            # wrong. Zero is different in kind, not in degree: no audio was
            # spent on this word, so there is no recitation of it to judge.
            # Reporting it as recited-and-skipped tells the user they got a
            # word wrong that they never actually reached -- Al-Fatihah ayah 3
            # after stopping at "al-'aalameen" is exactly this case, and both
            # of its words score a flat 0.
            if expected_word and not pred_idxs:
                results.append(self._unrecited(considered[i], surah))
                continue
            predicted_word = "".join(pred_chars[p] for p in pred_idxs)

            if pred_idxs:
                tok_idxs = sorted({pred_char_token_idx[p] for p in pred_idxs})
                start_sec = pred_times[tok_idxs[0]]
                end_sec = pred_times[tok_idxs[-1]]
            else:
                start_sec = end_sec = 0.0

            verdict = tajweed_diff.summarize(
                display, tajweed_diff.classify(display, expected_word, predicted_word)
            )
            confidence = max(0.0, 1.0 - word_errors[i] / max(len(expected_word), 1))

            results.append(WordPhonemeResult(
                ayah_number=ayah,
                word_index=idx_in_ayah,
                display_word=display,
                predicted_phonemes=predicted_word,
                expected_phonemes=expected_word,
                start_sec=round(start_sec, 3),
                end_sec=round(end_sec, 3),
                correct=verdict is None,
                recited=True,
                edit_distance=word_errors[i],
                confidence=round(confidence, 3),
                error_type=verdict.error_type if verdict else None,
                explanation=verdict.explanation if verdict else None,
                surah_number=surah,
            ))

        opening = [self._unrecited(w, surah) for w in skipped_prefix]
        if settle_before is not None:
            # The recording goes on past this window, so its last stretch was
            # aligned without the audio that follows it. Settle only the words
            # whose audio ends well before the window does; the next window
            # aligns the rest again with what comes after them.
            last = -1
            for i in range(own):
                if word_pred_chars[i]:
                    if max(word_pred_chars[i]) >= settle_before:
                        break
                    last = i
            if last < 0:
                return _Scored([], settled=0, consumed=0)
            return _Scored(opening + results[:last + 1],
                           settled=len(skipped_prefix) + last + 1,
                           consumed=max(word_pred_chars[last]) + 1)

        used_chars = [max(word_pred_chars[i]) for i in range(own) if word_pred_chars[i]]
        results.extend(self._unrecited(w, surah) for w in beyond)
        return _Scored(opening + results, settled=len(words),
                       consumed=max(used_chars) + 1 if used_chars else 0)

    @staticmethod
    def _unrecited(word: tuple[int, int, str, str], surah: int = 0) -> WordPhonemeResult:
        ayah, idx_in_ayah, display, expected_word = word
        return WordPhonemeResult(
            ayah_number=ayah,
            word_index=idx_in_ayah,
            display_word=display,
            predicted_phonemes="",
            expected_phonemes=expected_word,
            start_sec=0.0,
            end_sec=0.0,
            correct=False,
            recited=False,
            edit_distance=0,
            confidence=0.0,
            error_type=None,
            explanation=None,
            surah_number=surah,
        )

    # ── Recitations that may be long, or run on into the next surah ────────────

    def analyze_span(
        self,
        audio_bytes: bytes,
        start_surah: int,
        start_ayah: int = 1,
        end_surah: int | None = None,
        end_ayah: int | None = None,
        on_progress=None,
    ) -> list[WordPhonemeResult]:
        """Align a recitation that begins at ayah [start_ayah] of [start_surah]
        and runs on -- through the end of that surah and into the next ones, as
        far as (end_surah, end_ayah) allows and the recording actually goes.

        [end_surah] defaults to [start_surah], and [end_ayah] to the last ayah of
        [end_surah]: (start_surah, from, None, to) asks for exactly what
        analyze_range(audio, start_surah, from, to) does, and a recording short
        enough for one pass gets exactly its answer.

        Each result carries its `surah_number`. Words past where the recording
        stopped come back unrecited through the end of the surah it stopped in;
        surahs it never reached are not listed at all.

        [on_progress] is called with the fraction of the recording aligned so
        far, from the analysing thread.
        """
        with self._analysis_lock:
            span = self._check_span(start_surah, start_ayah, end_surah, end_ayah)
            pred_tokens, pred_times = self._decode(audio_bytes)
            return self._analyze_span(pred_tokens, pred_times, *span, on_progress)

    def analyze_decoded_span(
        self,
        pred_tokens,
        pred_times,
        start_surah: int,
        start_ayah: int = 1,
        end_surah: int | None = None,
        end_ayah: int | None = None,
        on_progress=None,
    ) -> list[WordPhonemeResult]:
        """[analyze_span] on a recording the recogniser has already decoded --
        the live socket's own stream, finished. Decoding it again would give the
        same tokens and timestamps (measured: fed in 200 ms chunks or all at
        once, identical on Al-Fatihah, Al-Mulk 1-6 and Al-Baqarah 280-286), so
        the recording need not be uploaded or decoded a second time."""
        with self._analysis_lock:
            span = self._check_span(start_surah, start_ayah, end_surah, end_ayah)
            return self._analyze_span(list(pred_tokens), list(pred_times), *span, on_progress)

    def _check_span(self, start_surah, start_ayah, end_surah, end_ayah):
        if end_surah is None:
            end_surah = start_surah
        start_count = self.ayah_count(start_surah)
        end_count = self.ayah_count(end_surah)
        if not start_count or not end_count or not 1 <= start_ayah <= start_count:
            raise ValueError(f"No phoneme reference for {start_surah}:{start_ayah} to {end_surah}:{end_ayah}")
        if end_ayah is not None:
            end_ayah = min(end_ayah, end_count)
        if (end_surah, end_ayah if end_ayah is not None else end_count) < (start_surah, start_ayah):
            raise ValueError(f"A recitation cannot end ({end_surah}:{end_ayah}) before it begins "
                             f"({start_surah}:{start_ayah})")
        return start_surah, start_ayah, end_surah, end_ayah

    def _guard_after(self, surah: int, end_surah: int, end_ayah: int | None) -> tuple:
        """The text after [surah], when the recitation's span goes on past it:
        the next surah's Basmala and opening, and the surahs after it when
        those are short -- as much as the longest single pass could align
        against. _score takes what its budget allows."""
        limit = int(SINGLE_PASS_MAX_CHARS * EXPECTED_LENGTH_SLACK)
        out: list = []
        chars = 0
        s = surah + 1
        while chars < limit and s <= min(end_surah, 114):
            last = end_ayah if s == end_surah and end_ayah is not None else self.ayah_count(s)
            for a in range(1, last + 1):
                for w in self._range_words(s, a, a):
                    out.append(w)
                    chars += len(w[3])
                if chars >= limit:
                    break
            s += 1
        return tuple(out)

    def _analyze_span(self, pred_tokens, pred_times, start_surah, start_ayah, end_surah, end_ayah,
                      on_progress=None) -> list[WordPhonemeResult]:
        pred_chars, pred_char_token_idx = self._flatten(pred_tokens)
        total = len(pred_chars)
        results: list[WordPhonemeResult] = []
        p = 0
        surah, ayah = start_surah, start_ayah

        def report():
            if on_progress is not None:
                on_progress(min(p / total, 1.0) if total else 1.0)

        while True:
            last = end_ayah if surah == end_surah and end_ayah is not None else self.ayah_count(surah)
            words = self._range_words(surah, ayah, last)
            guard = self._guard_after(surah, end_surah, end_ayah) if surah < end_surah else ()
            # A surah's Basmala is optional wherever the recitation meets it:
            # at the start, or run into from the surah before.
            prefix_len = self._mapper.basmala_prefix_len(surah, ayah) if ayah == 1 else 0

            segment: list[WordPhonemeResult] = []
            w = 0
            stopped_here = False
            while w < len(words):
                if total - p <= SINGLE_PASS_MAX_CHARS:
                    # The rest of the recording fits one pass: align it all,
                    # stop point and all, exactly as a short recording is.
                    scored = self._score(
                        pred_chars[p:], pred_char_token_idx[p:], pred_times, surah, words[w:],
                        prefix_len=prefix_len if w == 0 else 0, guard=guard)
                    segment += scored.results
                    p += scored.consumed
                    stopped_here = True
                    break
                end = p + WINDOW_CHARS
                scored = self._score(
                    pred_chars[p:end], pred_char_token_idx[p:end], pred_times, surah, words[w:],
                    prefix_len=prefix_len if w == 0 else 0, guard=guard,
                    settle_before=WINDOW_CHARS - SETTLE_MARGIN_CHARS)
                if scored.settled:
                    segment += scored.results
                    p += scored.consumed
                    w += scored.settled
                else:
                    # Nothing in this stretch could be placed against the text
                    # -- it is not recitation of it. Move past it rather than
                    # align the same audio again.
                    logger.info("No words placed in %d characters at %s:%s; skipping them",
                                WINDOW_CHARS - SETTLE_MARGIN_CHARS, surah, words[w][0])
                    p += WINDOW_CHARS - SETTLE_MARGIN_CHARS
                report()

            if results and not any(r.recited for r in segment):
                # A surah the recording never actually got into: leave it out
                # rather than list every word of it as not recited.
                break
            results += segment
            if not guard:
                break
            if stopped_here and (not segment or not segment[-1].recited or total - p < CONTINUE_MIN_CHARS):
                # The reciter stopped inside this surah, or at its very end.
                break
            surah, ayah = surah + 1, 1

        p = total
        report()
        return results

    def analyze(self, audio_bytes: bytes, surah: int, ayah: int) -> list[WordPhonemeResult]:
        """Single-ayah convenience wrapper over [analyze_range]."""
        return self.analyze_range(audio_bytes, surah, ayah, ayah)
