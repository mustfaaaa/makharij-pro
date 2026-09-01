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
# How much wider than the recognized tail the expected-text window may be.
# Just enough slack for the word currently being spoken, no more -- see
# live_advance for what a wide window does to a short tail.
LIVE_WINDOW_SLACK = 1.5

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
        if not pred_tail:
            return None
        words = self._range_words(surah, from_ayah, self.ayah_count(surah))
        if from_word >= len(words):
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
        window, used = [], 0
        for w in words[from_word:from_word + LIVE_LOOKAHEAD_WORDS]:
            if window and used >= budget:
                break
            window.append(w)
            used += len(w[3])
        if not window:
            return None

        pred_by_word, matched, _errors = self._attribute(pred_tail, window)
        heard = self._heard_flags(matched, window)

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
            if len(pred_tail) < LIVE_RESYNC_TAIL_CHARS:
                return None
            resync = next((i for i, h in enumerate(heard) if h), None)
            if resync is None:
                return None
            advanced = resync + 1

        last = advanced - 1
        # Consume every tail character attributed to any confirmed word, not
        # just the final one: a character the alignment parked on an earlier
        # word would otherwise stay in the tail and be re-matched next round.
        assigned = [i for w in pred_by_word[:advanced] for i in w]
        consumed = max(assigned) + 1 if assigned else 0
        ayah, word_index, _display, _expected = window[last]
        return ayah, word_index, from_word + last, consumed

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
    def _recited_span(word_pred_chars, word_matched, considered):
        """Find [first, last] word indices the recording actually covers.

        Two different questions, deliberately kept apart:
          heard   -- enough of this word matched to be sure the user reached it
          touched -- some of the recording was consumed here, even if it matched
                     badly (i.e. a genuinely mispronounced word)
        The span runs from the first *touched* word to the last *heard* one.
        Using `heard` at both ends marked a badly-recited opening ayah as "never
        recited" instead of as the mistake it was; using `touched` at the far end
        would let alignment drift past the point the user actually stopped.
        """
        heard = PhonemeAnalysisService._heard_flags(word_matched, considered)
        heard_idxs = [i for i, h in enumerate(heard) if h]
        if not heard_idxs:
            return None, None
        touched = [heard[i] or bool(word_pred_chars[i]) for i in range(len(considered))]
        return next(i for i, t in enumerate(touched) if t), heard_idxs[-1]

    def analyze_range(
        self, audio_bytes: bytes, surah: int, from_ayah: int = 1, to_ayah: int | None = None
    ) -> list[WordPhonemeResult]:
        """Align a continuous recitation against ayahs [from_ayah, to_ayah] of `surah`.

        Words the user never reached come back with `recited=False` and no
        error -- they are not mistakes, they are simply where the recording
        stopped.
        """
        if to_ayah is None:
            to_ayah = self.ayah_count(surah)
        if to_ayah < from_ayah or self.ayah_count(surah) == 0:
            raise ValueError(f"No phoneme reference for surah {surah} ayahs {from_ayah}-{to_ayah}")
        to_ayah = min(to_ayah, self.ayah_count(surah))

        words = self._range_words(surah, from_ayah, to_ayah)
        if not words:
            raise ValueError(f"No phoneme reference for surah {surah} ayahs {from_ayah}-{to_ayah}")

        pred_tokens, pred_times = self._decode(audio_bytes)
        pred_chars: list[str] = []
        pred_char_token_idx: list[int] = []
        for tok_i, tok in enumerate(pred_tokens):
            # Tokens like "للَ" or "ۦۦۦۦ" are several characters; remember which
            # token each character came from so timestamps stay attributable.
            for ch in tok:
                pred_chars.append(ch)
                pred_char_token_idx.append(tok_i)
        pred_str = "".join(pred_chars)

        if not pred_str:
            # Nothing recognized at all (silence, or an unusable recording).
            return [self._unrecited(w) for w in words]

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
        first_ayah_chars = sum(len(w[3]) for w in words if w[0] == from_ayah)
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
        prefix_len = (
            self._mapper.basmala_prefix_len(surah, from_ayah) if from_ayah == 1 else 0
        )
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
            first_heard, last_heard = self._recited_span(word_pred_chars, word_matched, considered)
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
            considered = considered[:last_heard + 1]
            word_pred_chars, word_matched, word_errors = self._attribute(pred_chars, considered)
            first_heard, _ = self._recited_span(word_pred_chars, word_matched, considered)
            first_heard = first_heard if first_heard is not None else 0
            last_heard = len(considered) - 1
        beyond = words[len(considered):]

        results: list[WordPhonemeResult] = []
        for i, (ayah, idx_in_ayah, display, expected_word) in enumerate(considered):
            in_span = first_heard is not None and first_heard <= i <= last_heard
            if not in_span:
                results.append(self._unrecited(considered[i]))
                continue

            pred_idxs = word_pred_chars[i]
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
            ))

        results.extend(self._unrecited(w) for w in beyond)
        return [self._unrecited(w) for w in skipped_prefix] + results

    @staticmethod
    def _unrecited(word: tuple[int, int, str, str]) -> WordPhonemeResult:
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
        )

    def analyze(self, audio_bytes: bytes, surah: int, ayah: int) -> list[WordPhonemeResult]:
        """Single-ayah convenience wrapper over [analyze_range]."""
        return self.analyze_range(audio_bytes, surah, ayah, ayah)
