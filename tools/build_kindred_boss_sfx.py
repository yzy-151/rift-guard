import math
import random
import struct
import wave
from pathlib import Path

ROOT = Path(r"C:\Users\23081\Desktop\codex\rift-guard\game\assets\sfx\boss")
ROOT.mkdir(parents=True, exist_ok=True)
SR = 44100
random.seed(7313)


def edge_env(t, dur, attack=0.008, release=0.22):
    return min(1.0, t / max(attack, 1e-4)) * min(1.0, max(0.0, dur - t) / max(release, 1e-4))


def burst(t, start, freq, decay, gain=1.0):
    if t < start:
        return 0.0
    x = t - start
    return gain * math.sin(2 * math.pi * freq * x) * math.exp(-decay * x)


def hiss(t, start, decay, gain=1.0):
    if t < start:
        return 0.0
    return gain * (random.random() * 2.0 - 1.0) * math.exp(-decay * (t - start))


def write(name, dur, synth):
    values = []
    for index in range(int(SR * dur)):
        t = index / SR
        values.append(math.tanh(synth(t, dur) * edge_env(t, dur) * 1.15))
    peak = max(0.001, max(abs(value) for value in values))
    scale = 0.92 / peak
    frames = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, value * scale)) * 32767)) for value in values)
    with wave.open(str(ROOT / name), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(SR)
        output.writeframes(frames)


def dance(t, dur):
    chirp = math.sin(2 * math.pi * (520 + 2100 * t) * t) * math.exp(-2.6 * t)
    twang = burst(t, 0.05, 170, 13, 0.55) + burst(t, 0.14, 230, 15, 0.34)
    sub = burst(t, 0.0, 54, 8, 0.50)
    volley = sum(burst(t, start, 920 + shot * 120, 28, 0.24) + hiss(t, start, 34, 0.11) for shot, start in enumerate((0.18, 0.27, 0.36, 0.45)))
    return 0.34 * chirp + twang + sub + volley


def wolf(t, dur):
    growl = (math.sin(2 * math.pi * (46 + 7 * math.sin(t * 11)) * t) + 0.46 * math.sin(2 * math.pi * 92 * t)) * (0.58 + 0.42 * math.sin(math.pi * t / dur))
    impact = burst(t, 0.16, 58, 6.2, 0.72) + hiss(t, 0.16, 4.4, 0.34)
    claws = sum(burst(t, start, 310 + index * 80, 18, 0.22) for index, start in enumerate((0.38, 0.62, 0.86, 1.10)))
    return 0.38 * growl + impact + claws


def dread(t, dur):
    pulses = 0.0
    for index, start in enumerate((0.02, 0.34, 0.68)):
        pulses += burst(t, start, 190 + index * 85, 12 - index * 1.4, 0.44 + index * 0.17)
        pulses += hiss(t, start, 22 - index * 3, 0.11 + index * 0.05)
    final_bass = burst(t, 0.68, 48, 5.0, 0.76)
    tension = 0.18 * math.sin(2 * math.pi * (70 + 220 * t) * t)
    return pulses + final_bass + tension


def hunt(t, dur):
    draw = 0.28 * math.sin(2 * math.pi * (110 + 820 * min(t, 0.34)) * t) * min(1.0, t / 0.28)
    release = burst(t, 0.31, 62, 5.0, 0.82) + burst(t, 0.31, 215, 10, 0.54) + hiss(t, 0.31, 3.0, 0.42)
    swarm = 0.0
    for index in range(14):
        start = 0.38 + index * 0.065
        swarm += burst(t, start, 720 + (index % 5) * 170, 24, 0.13) + hiss(t, start, 30, 0.055)
    tail = burst(t, 0.72, 44, 2.8, 0.48)
    return draw + release + swarm + tail


def respite(t, dur):
    bloom = min(1.0, t / 0.42) * min(1.0, (dur - t) / 0.60)
    pad = sum(gain * math.sin(2 * math.pi * freq * t + math.sin(t * 1.7) * 0.10) for freq, gain in ((110, 0.27), (165, 0.20), (220, 0.17), (330, 0.12), (440, 0.08)))
    pulse = sum(burst(t, start, 74, 6, 0.34) for start in (0.05, 0.62, 1.19, 1.76))
    shimmer = 0.10 * math.sin(2 * math.pi * (760 + 140 * math.sin(t * 2.2)) * t)
    return bloom * (pad + shimmer) + pulse


write("kindred_dance.wav", 1.10, dance)
write("kindred_wolf.wav", 1.58, wolf)
write("kindred_dread.wav", 1.42, dread)
write("kindred_hunt.wav", 1.92, hunt)
write("kindred_respite.wav", 2.50, respite)
print("generated pressure-layered kindred boss sfx")