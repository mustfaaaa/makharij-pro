"""Version identifiers for every persisted recitation analysis.

The acoustic model id alone is not enough to reproduce a verdict: audio
quality policy, enhancement, alignment and Tajweed post-processing can change
while the ONNX file stays byte-for-byte identical.  Keep one explicit pipeline
version beside the model id so old and new sessions are never mixed silently
in evaluation or a future verifier training set.
"""

PHONEME_MODEL_ID = "quran-lab-zipformer-p-arabic-v3.1"
ANALYSIS_VERSION = "word-verifier-2026.10.01-v1"
AUDIO_QUALITY_VERSION = "energy-quality-v1"
ENHANCEMENT_VERSION = "highpass-spectral-floor-v1"
