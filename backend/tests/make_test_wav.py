import numpy as np
import soundfile as sf

sr = 16000
duration = 6.0
t = np.linspace(0, duration, int(sr * duration), dtype=np.float32)
y = 0.3 * np.sin(2 * np.pi * 220 * t) + 0.02 * np.random.randn(len(t)).astype(np.float32)
sf.write("tests/test_clip.wav", y, sr)
print("wrote tests/test_clip.wav")
