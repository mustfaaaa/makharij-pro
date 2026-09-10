"""Cuts a single word out of a reference Qari's recitation.

Being told an elongation was short is worth much more next to the sound of it
done properly. The results screen already plays back the reciter's own word --
this supplies the other half of the comparison, from the same word of the same
ayah.

The Qari clips are per *ayah*, so the word boundaries have to be found. They are
found the same way the app finds them in the user's own audio: the recognizer
returns a timestamp per token, and analyze_range attributes those to words. So
the Qari's word 4 is located by exactly the process that located the reciter's
word 4, which is what makes the two clips comparable rather than merely adjacent.

Timings are computed once per (qari, ayah) and cached on disk -- 258 clips at
roughly half a second each is a minute of work that should not repeat on every
request, or every restart.

Coverage is 15 surahs (Al-Fatihah and 101-114), the 86 ayahs the repository
actually holds audio for. Callers get a 404 naming what is available rather than
a bare failure.
"""
import io
import json
import logging
from pathlib import Path

import librosa
import numpy as np
import soundfile as sf

logger = logging.getLogger(__name__)

RECITATIONS_DIR = Path(__file__).resolve().parent / "static" / "recitations"
CACHE_PATH = Path(__file__).resolve().parent.parent / "models_cache" / "reference_word_timings.json"

SAMPLE_RATE = 16000

# The same padding the reciter's own playback uses, for the same reason: word
# timings mark where sound was detected, and a clip cut exactly on that boundary
# sounds clipped -- particularly on a Qari's long, softly-fading madd.
PADDING_SEC = 0.12
MIN_LENGTH_SEC = 0.05


class ReferenceWordAudio:
    """Serves per-word slices of the reference recitations."""

    def __init__(self, analysis_service, recitations_dir: Path = RECITATIONS_DIR,
                 cache_path: Path = CACHE_PATH):
        self._service = analysis_service
        self._dir = recitations_dir
        self._cache_path = cache_path
        self._cache: dict[str, list] = {}
        if cache_path.exists():
            try:
                self._cache = json.loads(cache_path.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError):
                logger.warning("Reference word-timing cache unreadable, rebuilding on demand")

    def available_qaris(self) -> list[str]:
        return sorted(p.name for p in self._dir.iterdir() if p.is_dir()) if self._dir.exists() else []

    def clip_path(self, qari_id: str, surah: int, ayah: int) -> Path:
        return self._dir / qari_id / f"{surah:03d}{ayah:03d}.mp3"

    def has(self, qari_id: str, surah: int, ayah: int) -> bool:
        return self.clip_path(qari_id, surah, ayah).is_file()

    def timings(self, qari_id: str, surah: int, ayah: int) -> list[dict]:
        """[{word, start_sec, end_sec}] for every word of this ayah, cached."""
        key = f"{qari_id}:{surah}:{ayah}"
        if key in self._cache:
            return self._cache[key]

        path = self.clip_path(qari_id, surah, ayah)
        if not path.is_file():
            return []

        results = self._service.analyze_range(path.read_bytes(), surah, ayah, ayah)
        timings = [
            {"word": r.display_word, "start_sec": r.start_sec, "end_sec": r.end_sec}
            for r in results
            # A Qari recites the whole ayah, so anything not "recited" here is a
            # word the recognizer failed to place -- not a gap in the audio.
            if r.recited
        ]
        self._cache[key] = timings
        try:
            self._cache_path.parent.mkdir(parents=True, exist_ok=True)
            self._cache_path.write_text(
                json.dumps(self._cache, ensure_ascii=False), encoding="utf-8")
        except OSError:
            logger.warning("Could not write the reference word-timing cache")
        return timings

    def word_wav(self, qari_id: str, surah: int, ayah: int, word_index: int) -> bytes | None:
        """That word as a standalone WAV, or None if it can't be located."""
        timings = self.timings(qari_id, surah, ayah)
        if not 0 <= word_index < len(timings):
            return None
        t = timings[word_index]
        if t["end_sec"] <= t["start_sec"]:
            return None

        y, _ = librosa.load(str(self.clip_path(qari_id, surah, ayah)), sr=SAMPLE_RATE, mono=True)
        start = max(0, int((t["start_sec"] - PADDING_SEC) * SAMPLE_RATE))
        end = min(len(y), int((t["end_sec"] + PADDING_SEC) * SAMPLE_RATE))
        if end - start < MIN_LENGTH_SEC * SAMPLE_RATE:
            return None

        buf = io.BytesIO()
        sf.write(buf, np.clip(y[start:end], -1.0, 1.0).astype(np.float32),
                 SAMPLE_RATE, format="WAV")
        return buf.getvalue()
