"""Real end-to-end test across several real Rattil clips -- one match isn't
enough evidence, this checks a small honest sample across different surahs
and qaris before trusting the model at all.
"""
import sys
import json
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

import sherpa_onnx
import numpy as np
import librosa

MODEL_DIR = Path(__file__).resolve().parent.parent / "models_cache" / "quran-lab-zipformer"
RECIT_DIR = Path(__file__).resolve().parent.parent / "app" / "static" / "recitations"

# (qari_id, surah, ayah) -- a small honest spread across different content
# and different reciters, not cherry-picked to only repeat the one that
# already worked.
CASES = [
    ("abdurrahmaan_as_sudais", 1, 1),
    ("abdurrahmaan_as_sudais", 1, 2),
    ("abdurrahmaan_as_sudais", 112, 1),
    ("abdurrahmaan_as_sudais", 112, 2),
    ("abdurrahmaan_as_sudais", 108, 1),
    ("yasser_ad_dussary", 1, 1),
    ("yasser_ad_dussary", 114, 1),
    ("alafasy", 113, 1),
]


def edit_distance(a, b):
    dp = [[0] * (len(b) + 1) for _ in range(len(a) + 1)]
    for i in range(len(a) + 1):
        dp[i][0] = i
    for j in range(len(b) + 1):
        dp[0][j] = j
    for i in range(1, len(a) + 1):
        for j in range(1, len(b) + 1):
            dp[i][j] = dp[i-1][j-1] if a[i-1] == b[j-1] else 1 + min(dp[i-1][j], dp[i][j-1], dp[i-1][j-1])
    return dp[-1][-1]


def main():
    # ordered_quran_phonemes.json is indexed by "surah:ayah" directly and
    # covers all 6236 ayat, unlike quran_text2phoneme.json's text-matched
    # 9112 entries which turned out not to include every ayah as a whole
    # unit -- this is the reliable source for expected phonemes.
    with open(MODEL_DIR / "ordered_quran_phonemes.json", encoding="utf-8") as f:
        ordered = json.load(f)

    recognizer = sherpa_onnx.OnlineRecognizer.from_zipformer2_ctc(
        tokens=str(MODEL_DIR / "tokens.txt"),
        model=str(MODEL_DIR / "zipformer_p_arabic_v3.1.int8.onnx"),
        num_threads=2, sample_rate=16000, feature_dim=80,
        decoding_method="greedy_search", provider="cpu",
    )

    total_dist = 0
    total_len = 0
    results = []
    for qari, surah, ayah in CASES:
        audio_path = RECIT_DIR / qari / f"{surah:03d}{ayah:03d}.mp3"
        if not audio_path.exists():
            print(f"SKIP {qari} {surah}:{ayah} -- no audio file")
            continue

        entry = ordered.get(f"{surah}:{ayah}")
        if entry is None:
            print(f"SKIP {qari} {surah}:{ayah} -- no phoneme table entry")
            continue
        expected_clean = entry["aya_phoneme"].replace(" ", "").strip()

        y, sr = librosa.load(str(audio_path), sr=16000, mono=True)
        stream = recognizer.create_stream()
        stream.accept_waveform(16000, y.astype(np.float32))
        stream.accept_waveform(16000, np.zeros(int(0.5 * 16000), dtype=np.float32))
        stream.input_finished()
        while recognizer.is_ready(stream):
            recognizer.decode_stream(stream)
        pred = recognizer.get_result(stream).strip()

        dist = edit_distance(pred, expected_clean)
        total_dist += dist
        total_len += len(expected_clean)
        results.append((qari, surah, ayah, dist, len(expected_clean), pred, expected_clean))
        pct = 100 * dist / max(len(expected_clean), 1)
        print(f"{qari:24s} {surah:3d}:{ayah:<3d}  dist={dist:2d}/{len(expected_clean):2d}  ({pct:5.1f}%)")

    print(f"\n=== {len(results)} clips tested ===")
    print(f"Aggregate: {total_dist}/{total_len} chars ({100*total_dist/max(total_len,1):.1f}% edit-distance error, crude sanity check)")

    print("\n--- Details for any non-exact matches ---")
    for qari, surah, ayah, dist, ln, pred, exp in results:
        if dist > 0:
            print(f"{qari} {surah}:{ayah}")
            print(f"  pred: {pred!r}")
            print(f"  exp:  {exp!r}")


if __name__ == "__main__":
    main()
