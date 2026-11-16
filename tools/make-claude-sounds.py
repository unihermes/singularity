#!/usr/bin/env python3
"""Renders Claude's notification sounds into qs/sounds/ (a bell chime: three
notes a fifth apart, reverb and an octave shimmer). Seeded, so reruns match."""
import wave
from pathlib import Path
import numpy as np

SR = 44100
OUT = Path(__file__).resolve().parent.parent / "dotfiles/quickshell/.config/quickshell/sounds"
BELL = [(1, 1, 1), (2.76, .35, .5), (5.4, .12, .3), (2, .22, .5)]  # last is the shimmer

def chime(notes, root, ratio, gap, decay, attack=.025, tail=.7):
    n = int(((notes - 1) * gap + attack + decay + tail) * SR)
    out = np.zeros(n)
    for i in range(notes):
        f, t0 = root * ratio ** i, int(i * gap * SR)
        for mult, amp, scale in BELL:
            d = decay * scale
            t = np.arange(int((attack + d + .05) * SR)) / SR
            env = np.where(t < attack, t / attack, 0.0) * amp * .5
            env = np.where(t >= attack, amp * .5 * np.power(.0001 / (amp * .5), (t - attack) / d), env)
            env[t > attack + d] = 0
            seg = np.sin(2 * np.pi * f * mult * t) * env
            out[t0:t0 + len(seg)] += seg[:n - t0]
    rng = np.random.default_rng(1)
    ir = rng.uniform(-1, 1, int(SR * .6)) * (1 - np.arange(int(SR * .6)) / (SR * .6)) ** 2.2
    wet = np.convolve(out, ir)[:n] * .35
    out = out + wet
    return out * (.5 / np.abs(out).max())

def save(name, x):
    OUT.mkdir(exist_ok=True)
    with wave.open(str(OUT / name), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())

save("claude-done.wav", chime(3, 523.25, 1.5, .07, .45))
save("claude-waiting.wav", chime(3, 523.25, 1.5, .16, .8))
