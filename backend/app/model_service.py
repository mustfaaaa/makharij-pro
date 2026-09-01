import io
import json
import logging

import librosa
import numpy as np
import tensorflow as tf

from . import config
from .audio_features import compute_model_inputs

logger = logging.getLogger(__name__)

TASKS = ["separate_tide", "the_tight_noon", "concealment"]


class TajweedModelService:
    """Loads the exported model once and serves predictions.

    Deliberately a plain class instantiated once at app startup (see main.py),
    not re-loaded per request -- model.keras + TF graph construction is not
    cheap, and nothing about the model needs per-request state.
    """

    def __init__(self, model_path=config.MODEL_PATH, model_card_path=config.MODEL_CARD_PATH):
        if not model_path.exists():
            raise FileNotFoundError(
                f"Model not found at {model_path}. Expected the Track A export at "
                f"ml/models/makharijpro_tajweed_model_v1/ -- see ml/README.md."
            )
        if not model_card_path.exists():
            raise FileNotFoundError(f"model_card.json not found at {model_card_path}")

        with open(model_card_path, "r", encoding="utf-8") as f:
            self.model_card = json.load(f)

        self.feature_config = self.model_card["feature_config"]
        self.thresholds = self.model_card["calibrated_thresholds"]
        self.tasks_meta = self.model_card["tasks"]

        logger.info(f"Loading model from {model_path}")
        self.model = tf.keras.models.load_model(str(model_path))
        logger.info("Model loaded")

    def predict_from_audio_bytes(self, audio_bytes: bytes) -> dict:
        y, sr = librosa.load(io.BytesIO(audio_bytes), sr=None, mono=True)
        return self.predict_from_waveform(y, sr)

    def predict_from_waveform(self, y: np.ndarray, sr: int) -> dict:
        features, duration_norm = compute_model_inputs(y, sr, self.feature_config)

        # Model expects a batch dimension: (1, T, 26) and (1,).
        seq_input = features[np.newaxis, ...]
        dur_input = np.array([duration_norm], dtype=np.float32)

        raw_preds = self.model.predict([seq_input, dur_input], verbose=0)

        results = {}
        for task in TASKS:
            proba = float(np.asarray(raw_preds[task]).flatten()[0])
            threshold = self.thresholds[task]
            predicted_label = 1 if proba >= threshold else 0
            results[task] = {
                "tajweed_rule": self.tasks_meta[task]["tajweed_rule"],
                "correct": bool(predicted_label == 1),
                "confidence": proba if predicted_label == 1 else 1.0 - proba,
                "raw_probability": proba,
                "threshold_used": threshold,
            }
        return results
