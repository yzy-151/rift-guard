
from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

RATE = 48_000
ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "game" / "assets" / "sfx" / "boss"


def envelope(t: float, duration: float, attack: float = 0.025, release: float = 0.30) -> float:
    return min(1.0, t / attack) * min(1.0, (duration - t) / release)


def render(name: str, duration: float, sample_fn) -> None:
    rng = random.Random(name)
    frames = bytearray()
    for index in range(int(duration * RATE)):
        t = index / RATE
        value = max(-1.0, min(1.0, sample_fn(t, duration, rng)))
        left = int(value * 29_000)
        right = int(value * (0.94 + 0.04 * math.sin(t * 19.0)) * 29_000)
        frames.extend(struct.pack("<hh", left, right))
    path = OUTPUT / f"{name}.wav"
    with wave.open(str(path), "wb") as target:
        target.setnchannels(2)
        target.setsampwidth(2)
        target.setframerate(RATE)
        target.writeframes(frames)


def laser(t: float, duration: float, rng: random.Random) -> float:
    charge = math.sin(2 * math.pi * (75 + 210 * t) * t) * min(1.0, t / 0.52)
    beam = (math.sin(2 * math.pi * 56 * t) + 0.42 * math.sin(2 * math.pi * 112 * t)) if t > 0.48 else 0.0
    crackle = (rng.random() * 2 - 1) * (0.20 if t > 0.48 else 0.05)
    return envelope(t, duration, 0.02, 0.38) * (0.34 * charge + 0.52 * beam + crackle)


def orbs(t: float, duration: float, rng: random.Random) -> float:
    pulse = 0.0
    for hit in range(9):
        local = t - (0.10 + hit * 0.105)
        if 0.0 <= local <= 0.18:
            pulse += math.sin(2 * math.pi * (290 - hit * 13) * local) * math.exp(-local * 17.0)
    hum = math.sin(2 * math.pi * 92 * t) * 0.20
    return envelope(t, duration, 0.01, 0.34) * (0.68 * pulse + hum)


def overhead(t: float, duration: float, rng: random.Random) -> float:
    charge = math.sin(2 * math.pi * (120 + 360 * t * t) * t) * min(1.0, t / 0.38)
    strike_t = max(0.0, t - 0.40)
    thunder = (rng.random() * 2 - 1) * math.exp(-strike_t * 4.8) if t >= 0.40 else 0.0
    body = math.sin(2 * math.pi * 47 * strike_t) * math.exp(-strike_t * 2.8) if t >= 0.40 else 0.0
    return envelope(t, duration, 0.012, 0.42) * (0.24 * charge + 0.46 * thunder + 0.52 * body)


def storm(t: float, duration: float, rng: random.Random) -> float:
    value = math.sin(2 * math.pi * 42 * t) * 0.24
    for ring in range(5):
        local = t - (0.12 + ring * 0.22)
        if 0.0 <= local <= 0.34:
            sweep = math.sin(2 * math.pi * (76 + ring * 18) * local)
            value += sweep * math.exp(-local * 7.5) * 0.52
    value += (rng.random() * 2 - 1) * 0.08
    return envelope(t, duration, 0.015, 0.45) * value


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    render("rift_laser", 1.65, laser)
    render("rift_orbs", 1.45, orbs)
    render("rift_overhead", 1.85, overhead)
    render("rift_storm", 1.75, storm)


if __name__ == "__main__":
    main()
