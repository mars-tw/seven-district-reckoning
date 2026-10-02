"""Generate original short feedback sounds; output license is CC BY 4.0."""
import math
import random
import struct
import wave
from pathlib import Path

root = Path(__file__).resolve().parents[1]
out = root / "godot/assets/audio"
out.mkdir(parents=True, exist_ok=True)
rng = random.Random(47)
for name, duration, frequency in [("hit", 0.18, 110), ("pickup", 0.22, 660), ("engine", 1.0, 85)]:
    rate = 22050
    samples = []
    for i in range(int(duration * rate)):
        t = i / rate
        envelope = max(0, 1 - t / duration) if name != "engine" else 0.5
        tone = math.sin(2 * math.pi * frequency * t)
        noise = rng.uniform(-1, 1) * (0.6 if name == "hit" else 0.1)
        samples.append(struct.pack("<h", int((tone * 0.5 + noise) * envelope * 16000)))
    with wave.open(str(out / (name + ".wav")), "wb") as f:
        f.setparams((1, 2, rate, len(samples), "NONE", "not compressed"))
        f.writeframes(b"".join(samples))
print("Generated 3 original audio clips.")
