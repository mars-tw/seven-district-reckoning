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


# R1 feedback set: swing whoosh, objective chime, mission jingle, chain snap and
# UI click. Separate RNG keeps the three original clips byte-identical.
def write(name, data, rate=22050):
    frames = b"".join(struct.pack("<h", max(-32767, min(32767, int(v * 32767)))) for v in data)
    with wave.open(str(out / (name + ".wav")), "wb") as f:
        f.setparams((1, 2, rate, len(data), "NONE", "not compressed"))
        f.writeframes(frames)


def tone(freq, duration, rate=22050, volume=0.45, attack=0.005, decay=6.0, harmonics=(1.0, 0.35, 0.12)):
    data = []
    for i in range(int(duration * rate)):
        t = i / rate
        env = min(1.0, t / attack) * math.exp(-decay * t)
        v = sum(a * math.sin(2 * math.pi * freq * (k + 1) * t) for k, a in enumerate(harmonics))
        data.append(v * env * volume / sum(harmonics))
    return data


def mix(*tracks):
    length = max(len(t) for t in tracks)
    return [sum(t[i] for t in tracks if i < len(t)) for i in range(length)]


def delay(track, seconds, rate=22050):
    return [0.0] * int(seconds * rate) + track


fx = random.Random(2026)
rate = 22050
# Swing: band-limited noise sweep (one-pole low-pass with rising cutoff).
swing, low, duration = [], 0.0, 0.26
for i in range(int(duration * rate)):
    t = i / rate
    cutoff = 0.05 + 0.5 * (t / duration)
    low += cutoff * (fx.uniform(-1, 1) - low)
    env = math.sin(math.pi * min(1.0, t / duration)) ** 1.5
    swing.append(low * env * 1.6)
write("swing", swing)
write("objective", mix(tone(784, 0.35), delay(tone(1175, 0.45), 0.09)))
write("mission", mix(tone(523, 0.5), delay(tone(659, 0.5), 0.12), delay(tone(784, 0.55), 0.24), delay(tone(1047, 0.9, decay=3.5), 0.36)))
snap = []
for i in range(int(0.32 * rate)):
    t = i / rate
    clank = math.sin(2 * math.pi * 1880 * t) * 0.4 + math.sin(2 * math.pi * 2630 * t) * 0.3 + math.sin(2 * math.pi * 3410 * t) * 0.2
    snap.append((clank * math.exp(-14 * t) + fx.uniform(-1, 1) * math.exp(-60 * t) * 0.8) * 0.55)
write("chain", snap)
write("ui", tone(1320, 0.08, decay=40.0, volume=0.35))
print("Generated 5 R1 feedback clips.")
