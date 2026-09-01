"""First real end-to-end test of the Quran-Lab phoneme model on real audio.

Loads the model via sherpa-onnx's own tested streaming-CTC decoder (not a
hand-rolled one), feeds it a real Rattil recitation clip, and compares the
output against the model's own documented expected phoneme string for that
exact ayah (from quran_text2phoneme.json).
"""
import sys
import json
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

import sherpa_onnx
import soundfile as sf
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from app.phoneme_text_norm import norm

MODEL_DIR = Path(__file__).resolve().parent.parent / "models_cache" / "quran-lab-zipformer"
AUDIO_PATH = Path(__file__).resolve().parent.parent / "app" / "static" / "recitations" / "abdurrahmaan_as_sudais" / "001001.mp3"
QURAN_JSON = Path(__file__).resolve().parent.parent.parent / "frontend" / "assets" / "quran" / "quran_full.json"



def get_ground_truth_text(surah: int, ayah: int) -> str:
    with open(QURAN_JSON, encoding="utf-8") as f:
        data = json.load(f)
    s = next(x for x in data["surahs"] if x["number"] == surah)
    a = next(x for x in s["ayahs"] if x["number"] == ayah)
    return a["arabicText"]


def load_audio_16k_mono(path: Path) -> np.ndarray:
    # mp3 needs librosa (soundfile alone can't decode mp3 on all platforms);
    # reuse the same approach already proven throughout this backend.
    import librosa
    y, sr = librosa.load(str(path), sr=16000, mono=True)
    return y.astype(np.float32)


def main():
    print("Loading recognizer...")
    recognizer = sherpa_onnx.OnlineRecognizer.from_zipformer2_ctc(
        tokens=str(MODEL_DIR / "tokens.txt"),
        model=str(MODEL_DIR / "zipformer_p_arabic_v3.1.int8.onnx"),
        num_threads=2,
        sample_rate=16000,
        feature_dim=80,
        decoding_method="greedy_search",
        provider="cpu",
    )
    print("Recognizer loaded OK")

    print(f"Loading audio: {AUDIO_PATH}")
    audio = load_audio_16k_mono(AUDIO_PATH)
    print(f"Audio: {len(audio)/16000:.2f}s")

    stream = recognizer.create_stream()
    stream.accept_waveform(16000, audio)
    # Flush with trailing silence so the final chunk's context completes.
    stream.accept_waveform(16000, np.zeros(16000 // 2, dtype=np.float32))
    tail_paddings = np.zeros(int(0.3 * 16000), dtype=np.float32)
    stream.accept_waveform(16000, tail_paddings)
    stream.input_finished()

    while recognizer.is_ready(stream):
        recognizer.decode_stream(stream)

    result = recognizer.get_result(stream)
    print(f"\nRAW MODEL OUTPUT:\n{result!r}\n")

    ground_truth = get_ground_truth_text(1, 1)
    with open(MODEL_DIR / "quran_text2phoneme.json", encoding="utf-8") as f:
        table = json.load(f)
    norm_table = {norm(k): v for k, v in table.items()}
    expected = norm_table.get(norm(ground_truth))

    print(f"GROUND TRUTH TEXT: {ground_truth}")
    print(f"EXPECTED PHONEMES (from quran_text2phoneme.json): {expected!r}")

    if expected is None:
        print("\nWARNING: lookup miss -- normalization didn't match any table key")
    else:
        # crude edit distance for a quick sanity number, not a real PER calc
        def edit_distance(a, b):
            dp = [[0] * (len(b) + 1) for _ in range(len(a) + 1)]
            for i in range(len(a) + 1):
                dp[i][0] = i
            for j in range(len(b) + 1):
                dp[0][j] = j
            for i in range(1, len(a) + 1):
                for j in range(1, len(b) + 1):
                    if a[i-1] == b[j-1]:
                        dp[i][j] = dp[i-1][j-1]
                    else:
                        dp[i][j] = 1 + min(dp[i-1][j], dp[i][j-1], dp[i-1][j-1])
            return dp[-1][-1]

        pred = result.strip()
        # tokens.txt has no space/word-separator symbol -- the model's raw
        # output is necessarily space-less, so strip the reference's spaces
        # too or every ayah would show one spurious edit per word boundary.
        exp = expected.replace(" ", "").strip()
        dist = edit_distance(pred, exp)
        print(f"EXPECTED (spaces stripped for comparison): {exp!r}")
        print(f"\nCharacter edit distance: {dist} / {len(exp)} expected chars "
              f"({100*dist/max(len(exp),1):.1f}% error, crude sanity check only)")

    print("\nDONE")


if __name__ == "__main__":
    main()
