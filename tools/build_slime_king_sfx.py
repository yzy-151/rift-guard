from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

RATE = 48_000
ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "game" / "assets" / "sfx" / "boss"


def env(t: float, duration: float, attack: float = 0.015, release: float = 0.30) -> float:
    return min(1.0, t / attack) * min(1.0, max(0.0, duration - t) / release)


def render(name: str, duration: float, voice) -> None:
    rng = random.Random(name)
    frames = bytearray()
    for index in range(int(duration * RATE)):
        t = index / RATE
        sample = max(-1.0, min(1.0, voice(t, duration, rng)))
        pan = 0.96 + 0.035 * math.sin(t * 17.0)
        frames.extend(struct.pack("<hh", int(sample * 28_000), int(sample * pan * 28_000)))
    OUTPUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUTPUT / f"{name}.wav"), "wb") as out:
        out.setnchannels(2)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(frames)


def bounce(t: float, duration: float, rng: random.Random) -> float:
    value = 0.16 * math.sin(2 * math.pi * (105 + 52 * math.sin(t * 8)) * t)
    for hit in range(5):
        local = t - (0.18 + hit * 0.17)
        if 0 <= local < 0.26:
            value += math.sin(2 * math.pi * (82 - hit * 4) * local) * math.exp(-local * 15) * 0.72
            value += math.sin(2 * math.pi * 320 * local) * math.exp(-local * 24) * 0.20
    return env(t, duration, 0.01, 0.30) * value


def burst(t: float, duration: float, rng: random.Random) -> float:
    value = 0.10 * math.sin(2 * math.pi * 72 * t)
    for glob in range(10):
        local = t - (0.06 + glob * 0.075)
        if 0 <= local < 0.20:
            chirp = 220 + glob * 18 + local * 620
            value += math.sin(2 * math.pi * chirp * local) * math.exp(-local * 18) * 0.44
            value += (rng.random() * 2 - 1) * math.exp(-local * 30) * 0.16
    return env(t, duration, 0.01, 0.26) * value


def reflux(t: float, duration: float, rng: random.Random) -> float:
    sweep = math.sin(2 * math.pi * (190 - 105 * t / duration) * t) * (0.25 + 0.34 * t / duration)
    vortex = math.sin(2 * math.pi * 43 * t + 6 * math.sin(t * 10)) * 0.32
    impact_t = max(0.0, t - 0.92)
    impact = math.sin(2 * math.pi * 54 * impact_t) * math.exp(-impact_t * 5.0) if t >= 0.92 else 0.0
    return env(t, duration, 0.03, 0.40) * (sweep + vortex + impact * 0.72 + (rng.random() * 2 - 1) * 0.05)


def court(t: float, duration: float, rng: random.Random) -> float:
    value = math.sin(2 * math.pi * 96 * t) * 0.12
    for charge in range(10):
        local = t - (0.10 + charge * 0.085)
        if 0 <= local < 0.24:
            value += math.sin(2 * math.pi * (410 - charge * 14) * local) * math.exp(-local * 17) * 0.42
    finale = max(0.0, t - 0.92)
    if t >= 0.92:
        value += math.sin(2 * math.pi * 48 * finale) * math.exp(-finale * 5.5) * 0.82
        value += (rng.random() * 2 - 1) * math.exp(-finale * 9.0) * 0.24
    return env(t, duration, 0.01, 0.38) * value


def main() -> None:
    render("slime_bounce", 1.30, bounce)
    render("slime_burst", 1.25, burst)
    render("slime_reflux", 1.65, reflux)
    render("slime_court", 1.55, court)


if __name__ == "__main__":
    main()
