#!/usr/bin/env python3
"""Short PCM SFX. No OST loops — clicky hell stingers you can actually hear."""
from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

SR = 22050
OUT = Path(__file__).resolve().parents[1] / "assets" / "audio" / "sfx"


def clip(x: float) -> float:
    return max(-0.98, min(0.98, x))


def write_wav(name: str, samples: list[float]) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / name
    with wave.open(str(path), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = b"".join(struct.pack("<h", int(clip(s) * 32000)) for s in samples)
        w.writeframes(frames)
    print(path.name, "samples", len(samples))


def env(i: int, n: int, attack: float = 0.02) -> float:
    a = min(1.0, i / max(1, int(SR * attack)))
    rel = 1.0 - i / max(1, n)
    return a * rel * rel


def square(freq: float, t: float) -> float:
    return 1.0 if math.sin(2 * math.pi * freq * t) >= 0 else -1.0


def shoot() -> list[float]:
    n = int(SR * 0.09)
    out = []
    rng = random.Random(3)
    for i in range(n):
        t = i / SR
        e = env(i, n, 0.004)
        click = square(880 - 4200 * t, t) * 0.45
        hiss = (rng.random() * 2 - 1) * 0.22
        out.append((click + hiss) * e)
    return out


def hit() -> list[float]:
    n = int(SR * 0.14)
    out = []
    rng = random.Random(9)
    for i in range(n):
        t = i / SR
        e = env(i, n, 0.002)
        thud = square(92 + 40 * math.sin(t * 40), t) * 0.55
        crunch = (rng.random() * 2 - 1) * 0.18
        out.append((thud + crunch) * e)
    return out


def pickup() -> list[float]:
    n = int(SR * 0.18)
    out = []
    for i in range(n):
        t = i / SR
        e = env(i, n, 0.01)
        f = 520.0 if t < 0.08 else 780.0
        out.append(square(f, t) * 0.38 * e)
    return out


def door() -> list[float]:
    n = int(SR * 0.22)
    out = []
    rng = random.Random(21)
    for i in range(n):
        t = i / SR
        e = env(i, n, 0.01)
        grind = square(48 + 12 * math.sin(t * 30), t) * 0.35
        stone = (rng.random() * 2 - 1) * 0.28
        out.append((grind + stone) * e)
    return out


def unlock() -> list[float]:
    n = int(SR * 0.28)
    notes = [392.0, 523.0, 659.0]
    out = [0.0] * n
    for k, f in enumerate(notes):
        start = int(SR * (0.02 + k * 0.07))
        dur = int(SR * 0.12)
        for i in range(dur):
            if start + i >= n:
                break
            t = i / SR
            e = env(i, dur, 0.008)
            out[start + i] += square(f, t) * 0.32 * e
    return out


def talk() -> list[float]:
    n = int(SR * 0.05)
    out = []
    rng = random.Random(4)
    f = 640.0 + rng.random() * 80
    for i in range(n):
        t = i / SR
        e = env(i, n, 0.004)
        out.append(square(f, t) * 0.34 * e)
    return out


def death() -> list[float]:
    n = int(SR * 0.45)
    out = []
    for i in range(n):
        t = i / SR
        e = env(i, n, 0.01)
        f = 220.0 * (1.0 - t * 1.4)
        out.append(square(max(40.0, f), t) * 0.42 * e)
    return out


def cry() -> list[float]:
    n = int(SR * 0.32)
    out = []
    for i in range(n):
        t = i / SR
        e = env(i, n, 0.02)
        f = 420.0 + 90.0 * math.sin(t * 18)
        wob = 0.55 + 0.45 * math.sin(t * 30)
        out.append(square(f, t) * 0.28 * e * wob)
    return out


def ambience() -> list[float]:
    n = int(SR * 1.6)
    out = []
    rng = random.Random(77)
    for i in range(n):
        t = i / SR
        drone = square(46.0, t) * 0.08 + square(69.0, t) * 0.05
        hiss = (rng.random() * 2 - 1) * 0.03
        out.append(drone + hiss)
    return out


def main() -> None:
    write_wav("shoot.wav", shoot())
    write_wav("hit.wav", hit())
    write_wav("pickup.wav", pickup())
    write_wav("door.wav", door())
    write_wav("unlock.wav", unlock())
    write_wav("talk.wav", talk())
    write_wav("death.wav", death())
    write_wav("cry.wav", cry())
    write_wav("ambience.wav", ambience())


if __name__ == "__main__":
    main()
