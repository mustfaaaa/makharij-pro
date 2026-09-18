"""Trains the SRS's model -- MFCC features, an LSTM -- on the job it can
actually do, and on data from the right distribution.

Why this exists. The Track A model (`makharijpro_tajweed_model_v1`) is a CNN
trained on QDAT: 1,323 clips of a fixed phrase set. It scores 95.6 / 79.1 /
74.8% on QDAT's own test split, and AUC 0.527 -- chance -- on 773 recordings of
real learners. That is a dataset-shift result, not a coding error: QDAT's fixed
phrases are not what people actually recite.

So this keeps the architecture the SRS specifies (MFCC -> LSTM) and changes the
two things that were wrong:

  - the data: real learner recitations, the distribution the app serves;
  - the question: not "which of three QDAT rules was broken" but the one a
    whole-clip model can honestly answer -- "did this recitation contain a
    mistake at all". That is exactly the signal the word-level detector lacks,
    where it wrongly flags 42.8% of correct recitations.

Two numbers to beat, both measured, not assumed:
    majority class      54.3% accuracy  (420 of 773 clips have a mistake)
    Track A on this set AUC 0.527

Honest about the size: 773 clips is small, and an LSTM can memorise that. The
split is grouped by speaker so it cannot memorise voices, and the test pool
takes no part in training or early stopping. If it lands at chance, that is the
result and it gets reported as one.

    python ml/train/train_lstm_clip_classifier.py
"""
import argparse
import csv
import json
import random
import sys
import time
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT / "backend"))

import numpy as np

EVAL = ROOT / "ml" / "data" / "quranic_audio_dataset" / "evalset"
OUT = ROOT / "ml" / "models" / "makharijpro_clip_lstm_v1"

SEED = 42
# The SRS's feature contract, identical to Track A's so the two are comparable.
N_MFCC = 13
SAMPLE_RATE = 16000
FRAME_MS, HOP_MS = 25, 10
# Median clip is 4.7s; 10s covers the 90th percentile. Longer clips are
# truncated rather than padded-to-longest, which would make most of every batch
# padding and teach the model to read padding.
MAX_FRAMES = 1000
FIT_SPEAKER_SHARE = 0.75


def extract(path: Path) -> np.ndarray:
    """MFCC(13) + delta -> (frames, 26), the same pipeline Track A used."""
    import librosa

    y, sr = librosa.load(str(path), sr=SAMPLE_RATE, mono=True)
    peak = np.max(np.abs(y))
    if peak > 0:
        y = y / peak
    mfcc = librosa.feature.mfcc(
        y=y, sr=sr, n_mfcc=N_MFCC,
        n_fft=int(SAMPLE_RATE * FRAME_MS / 1000),
        hop_length=int(SAMPLE_RATE * HOP_MS / 1000),
    )
    delta = librosa.feature.delta(mfcc, order=1)
    return np.concatenate([mfcc, delta], axis=0).T.astype(np.float32)


def load_features(rows, cache: Path):
    """Features for every clip, cached so re-runs don't re-extract."""
    cache.parent.mkdir(parents=True, exist_ok=True)
    if cache.exists():
        blob = np.load(cache, allow_pickle=True)
        return list(blob["feats"])

    feats, started = [], time.time()
    for i, row in enumerate(rows, 1):
        feats.append(extract(EVAL / row["file"]))
        if i % 150 == 0:
            print(f"  extracted {i}/{len(rows)}  ({i / (time.time() - started):.0f} clips/s)", flush=True)
    np.savez_compressed(cache, feats=np.array(feats, dtype=object))
    return feats


def speaker_split(rows):
    """train / val grouped by speaker; the unknown-speaker pool is the test set.

    Grouping matters more than usual here: 88 reciters produced 773 clips, so
    an ungrouped split would put the same voice on both sides and report a
    number that is mostly voice recognition.
    """
    known = [i for i, r in enumerate(rows) if r["reciter_id"] != "Unknown"]
    test = [i for i, r in enumerate(rows) if r["reciter_id"] == "Unknown"]

    speakers = sorted({rows[i]["reciter_id"] for i in known})
    random.Random(SEED).shuffle(speakers)
    fit_speakers = set(speakers[: int(len(speakers) * FIT_SPEAKER_SHARE)])

    train = [i for i in known if rows[i]["reciter_id"] in fit_speakers]
    val = [i for i in known if rows[i]["reciter_id"] not in fit_speakers]
    assert not ({rows[i]["reciter_id"] for i in train} & {rows[i]["reciter_id"] for i in val})
    return train, val, test


def pad(feats, idx, mean, std):
    x = np.zeros((len(idx), MAX_FRAMES, N_MFCC * 2), dtype=np.float32)
    for n, i in enumerate(idx):
        f = ((feats[i] - mean) / std)[:MAX_FRAMES]
        x[n, : len(f)] = f
    return x


def auc(scores, labels) -> float:
    order = np.argsort(scores)
    ranks = np.empty(len(scores), dtype=float)
    ranks[order] = np.arange(1, len(scores) + 1)
    labels = np.asarray(labels)
    pos, neg = labels.sum(), (labels == 0).sum()
    if pos == 0 or neg == 0:
        return float("nan")
    return (ranks[labels == 1].sum() - pos * (pos + 1) / 2) / (pos * neg)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--epochs", type=int, default=60)
    parser.add_argument("--units", type=int, default=48)
    args = parser.parse_args()

    import tensorflow as tf

    tf.keras.utils.set_random_seed(SEED)   # weights, dropout and shuffling
    random.seed(SEED)
    np.random.seed(SEED)

    rows = list(csv.DictReader(open(EVAL / "manifest.csv", encoding="utf-8")))
    labels = np.array([0 if r["recited_correctly"] == "1" else 1 for r in rows])
    print(f"clips: {len(rows)}  ({(labels == 0).sum()} correct, {labels.sum()} with a mistake)")

    print("extracting MFCC(13)+delta ...")
    feats = load_features(rows, OUT / "features.npz")

    train, val, test = speaker_split(rows)
    print(f"  train {len(train):4}  ({len({rows[i]['reciter_id'] for i in train})} reciters)")
    print(f"  val   {len(val):4}  ({len({rows[i]['reciter_id'] for i in val})} reciters, none shared)")
    print(f"  test  {len(test):4}  (reciter unknown, never trained or tuned on)")

    # Normalisation fitted on the training split only.
    stacked = np.concatenate([feats[i] for i in train])
    mean, std = stacked.mean(0), stacked.std(0) + 1e-8

    x_train, x_val, x_test = (pad(feats, s, mean, std) for s in (train, val, test))
    y_train, y_val, y_test = labels[train], labels[val], labels[test]

    model = tf.keras.Sequential([
        tf.keras.layers.Input(shape=(MAX_FRAMES, N_MFCC * 2)),
        # Padded frames are exactly zero; masking stops the LSTM reading them
        # as if they were audio.
        tf.keras.layers.Masking(mask_value=0.0),
        tf.keras.layers.LSTM(args.units, dropout=0.3, recurrent_dropout=0.0),
        tf.keras.layers.Dropout(0.4),
        tf.keras.layers.Dense(1, activation="sigmoid"),
    ])
    model.compile(
        optimizer=tf.keras.optimizers.Adam(1e-3),
        loss="binary_crossentropy",
        metrics=[tf.keras.metrics.AUC(name="auc")],
    )
    print(f"\nLSTM({args.units}) over MFCC(13)+delta -- {model.count_params():,} params")

    history = model.fit(
        x_train, y_train,
        validation_data=(x_val, y_val),
        epochs=args.epochs,
        batch_size=16,
        verbose=2,
        callbacks=[
            # Stop on validation AUC, and keep the best weights rather than the
            # last -- with 300-odd training clips the last epoch is rarely best.
            tf.keras.callbacks.EarlyStopping(
                monitor="val_auc", mode="max", patience=12, restore_best_weights=True
            ),
        ],
    )

    print("\n=== results ===")
    majority = max((y_test == 0).mean(), (y_test == 1).mean())
    scores = model.predict(x_test, verbose=0).ravel()
    test_auc = auc(scores, y_test)
    acc = ((scores >= 0.5).astype(int) == y_test).mean()

    val_scores = model.predict(x_val, verbose=0).ravel()
    print(f"  validation AUC   : {auc(val_scores, y_val):.3f}")
    print(f"  HELD-OUT AUC     : {test_auc:.3f}     (Track A on the same clips: 0.527)")
    print(f"  HELD-OUT accuracy: {acc:.1%}     (majority class: {majority:.1%})")

    tp = int(((scores >= 0.5) & (y_test == 1)).sum())
    fp = int(((scores >= 0.5) & (y_test == 0)).sum())
    fn = int(((scores < 0.5) & (y_test == 1)).sum())
    tn = int(((scores < 0.5) & (y_test == 0)).sum())
    print(f"  confusion (test) : TP={tp}  FP={fp}  FN={fn}  TN={tn}")

    verdict = ("beats both baselines" if test_auc > 0.60 and acc > majority
               else "no better than chance -- reported as a negative result")
    print(f"\n  {verdict}")

    OUT.mkdir(parents=True, exist_ok=True)
    model.save(OUT / "model.keras")
    (OUT / "result.json").write_text(json.dumps({
        "architecture": f"Masking -> LSTM({args.units}) -> Dropout -> Dense(1, sigmoid)",
        "features": f"MFCC({N_MFCC})+delta = {N_MFCC * 2} dims, {FRAME_MS}ms/{HOP_MS}ms, {SAMPLE_RATE}Hz",
        "task": "clip-level: did this recitation contain a mistake",
        "data": "RetaSy/quranic_audio_dataset, 773 labelled learner clips",
        "split": {"train": len(train), "val": len(val), "test": len(test),
                  "grouped_by": "reciter_id", "seed": SEED},
        "params": int(model.count_params()),
        "epochs_run": len(history.history["loss"]),
        "val_auc": round(float(auc(val_scores, y_val)), 4),
        "test_auc": round(float(test_auc), 4),
        "test_accuracy": round(float(acc), 4),
        "majority_baseline": round(float(majority), 4),
        "track_a_auc_same_clips": 0.527,
        "confusion_test": {"tp": tp, "fp": fp, "fn": fn, "tn": tn},
        "verdict": verdict,
    }, indent=2), encoding="utf-8")
    print(f"  written to {OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
