"""Canonical MFCC+delta feature extraction.

This MUST stay in exact sync with the pipeline that produced
ml/models/makharijpro_tajweed_model_v1/model_card.json's "feature_config" --
see ml/notebooks/02_qdat_manifest.ipynb section 7. Any change here invalidates
the trained model's normalization stats and calibrated thresholds.

One deliberate deviation from training: QDAT's audio was already 16kHz, so
training asserted the sample rate rather than resampling. Real user uploads
won't always arrive at 16kHz, so this module resamples instead of asserting --
the resulting features are still computed at the same 16kHz the model expects.
"""
import librosa
import numpy as np


def extract_mfcc_delta(y: np.ndarray, sr: int, feature_config: dict) -> np.ndarray:
    target_sr = feature_config["sample_rate"]
    if sr != target_sr:
        y = librosa.resample(y, orig_sr=sr, target_sr=target_sr)
        sr = target_sr

    peak = np.max(np.abs(y))
    if peak > 0:
        y = y / peak

    y_trimmed, _ = librosa.effects.trim(y, top_db=feature_config["trim_top_db"])
    if len(y_trimmed) < feature_config["frame_length_samples"]:
        y_trimmed = y  # near-silent clip after trim -- fall back to untrimmed rather than error

    mfcc = librosa.feature.mfcc(
        y=y_trimmed, sr=sr, n_mfcc=feature_config["n_mfcc"],
        n_fft=feature_config["frame_length_samples"],
        hop_length=feature_config["hop_length_samples"],
    )
    delta = librosa.feature.delta(mfcc, order=feature_config["delta_order"])
    features = np.concatenate([mfcc, delta], axis=0)  # (26, T)
    return features.T.astype(np.float32)  # (T, 26) -- time-major, matches training


def compute_model_inputs(y: np.ndarray, sr: int, feature_config: dict) -> tuple[np.ndarray, np.float32]:
    """Returns (normalized_mfcc_delta [T, 26], normalized_duration_scalar), matching
    the exact two-input contract in model_card.json's feature_config["model_inputs"]."""
    if y.ndim > 1:
        # Downmix defensively -- callers may hand us either soundfile's (samples, channels)
        # or librosa's (channels, samples) convention. Channel count is always the smaller
        # dimension in practice (1-2 channels vs. thousands of samples), so average over that
        # axis rather than assuming a fixed layout. QDAT's source files are stereo even though
        # training's decode path (HF's Audio feature) downmixes to mono before features are
        # ever computed -- this must too, or features silently drift off the training distribution.
        channel_axis = int(np.argmin(y.shape))
        y = y.mean(axis=channel_axis)

    duration_seconds = len(y) / sr

    raw_features = extract_mfcc_delta(y, sr, feature_config)
    norm_mean = np.array(feature_config["normalization_mean"], dtype=np.float32)
    norm_std = np.array(feature_config["normalization_std"], dtype=np.float32)
    normalized_features = (raw_features - norm_mean) / norm_std

    duration_mean = feature_config["duration_normalization_mean"]
    duration_std = feature_config["duration_normalization_std"]
    normalized_duration = np.float32((duration_seconds - duration_mean) / duration_std)

    return normalized_features, normalized_duration
