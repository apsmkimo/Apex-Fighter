#!/usr/bin/env python3
# 產生復古風佔位音檔（8-bit PCM WAV）。正式音效只要用同名檔案覆蓋即可。
# 執行：python3 tools/generate_audio_placeholders.py

import math
import os
import struct
import wave

SR = 11025
ROOT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "audio")
BGM_DIR = os.path.join(ROOT, "bgm")
SFX_DIR = os.path.join(ROOT, "sfx")


def _clamp(v: float) -> int:
    return 128 + max(-127, min(127, int(v * 127.0)))


def write_wav(path: str, samples: list) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    peak = max((abs(s) for s in samples), default=1.0)
    gain = 0.86 / peak if peak > 0.001 else 1.0
    data = bytes(_clamp(s * gain) for s in samples)
    with wave.open(path, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(1)
        wf.setframerate(SR)
        wf.writeframes(data)
    print("wrote %s  %.2fs  %d bytes" % (os.path.relpath(path, os.path.dirname(ROOT)), len(samples) / SR, os.path.getsize(path)))


def fade_edges(buf: list, n: int) -> None:
    n = min(n, len(buf) // 4)
    for i in range(n):
        k = i / n
        buf[i] *= k
        buf[-1 - i] *= k


def lowpass(buf: list, cutoff: float) -> None:
    dt = 1.0 / SR
    rc = 1.0 / (2.0 * math.pi * cutoff)
    a = dt / (rc + dt)
    y = 0.0
    for i, s in enumerate(buf):
        y += a * (s - y)
        buf[i] = y


def noise(i: int) -> float:
    x = (i * 1103515245 + 12345) & 0x7FFFFFFF
    return ((x >> 16) & 255) / 127.5 - 1.0


def square(phase: float, duty: float = 0.5) -> float:
    return 1.0 if (phase % 1.0) < duty else -1.0


def add_tone(buf: list, start: int, dur: float, freq: float, amp: float, duty: float = 0.5, wave_kind: str = "square") -> None:
    n = max(1, int(dur * SR))
    if start >= len(buf) or freq <= 0.0 or amp <= 0.0:
        return
    n = min(n, len(buf) - start)
    attack = max(1, int(0.008 * SR))
    release = max(1, int(min(0.04, dur * 0.35) * SR))
    for i in range(n):
        t = i / SR
        env = 1.0
        if i < attack:
            env = i / attack
        if i > n - release:
            env *= max(0.0, (n - i) / release)
        phase = freq * t
        if wave_kind == "sine":
            osc = math.sin(phase * math.tau)
        elif wave_kind == "tri":
            p = phase % 1.0
            osc = 4.0 * abs(p - 0.5) - 1.0
        else:
            osc = square(phase, duty)
        buf[start + i] += osc * amp * env


def add_noise(buf: list, start: int, dur: float, amp: float, decay: float = 4.0) -> None:
    n = max(1, int(dur * SR))
    if start >= len(buf):
        return
    n = min(n, len(buf) - start)
    for i in range(n):
        env = math.exp(-decay * i / n)
        buf[start + i] += noise(start + i) * amp * env


def add_sweep(buf: list, start: int, dur: float, f0: float, f1: float, amp: float, kind: str = "square") -> None:
    n = max(1, int(dur * SR))
    if start >= len(buf):
        return
    n = min(n, len(buf) - start)
    phase = 0.0
    for i in range(n):
        k = i / n
        freq = f0 + (f1 - f0) * k
        phase += freq / SR
        env = math.sin(k * math.pi) ** 0.6
        if kind == "sine":
            osc = math.sin(phase * math.tau)
        else:
            osc = square(phase, 0.35)
        buf[start + i] += osc * amp * env


NOTE_PC = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def midi_of(name: str) -> int:
    if name in ("R", "REST"):
        return 0
    acc = 0
    i = 1
    if len(name) > 1 and name[1] in ("#", "b"):
        acc = 1 if name[1] == "#" else -1
        i = 2
    octave = int(name[i:])
    return 12 * (octave + 1) + NOTE_PC[name[0]] + acc


def freq_of(midi: int) -> float:
    if midi <= 0:
        return 0.0
    return 440.0 * (2.0 ** ((midi - 69) / 12.0))


def render_song(bpm: float, pattern: str, bass: str, duty: float = 0.25) -> list:
    beat = 60.0 / bpm
    # token: NOTE/beats  例如 A4/1 或 R/0.5
    def parse(text: str):
        out = []
        for tok in text.split():
            name, length = tok.split("/")
            out.append((midi_of(name), float(length)))
        return out

    lead_notes = parse(pattern)
    bass_notes = parse(bass)
    beats = max(sum(n[1] for n in lead_notes), sum(n[1] for n in bass_notes))
    total = int(beats * beat * SR)
    # 多渲染一點，用來把迴圈接點交叉淡化
    tail = int(0.02 * SR)
    buf = [0.0] * (total + tail)
    hat_amp = 0.07

    def place(notes, amp, octave_shift, wave_kind, note_duty):
        t = 0.0
        for midi, length in notes:
            start = int(t * beat * SR)
            dur = length * beat * 0.92
            if midi > 0:
                add_tone(buf, start, dur, freq_of(midi + octave_shift), amp, note_duty, wave_kind)
            t += length

    place(lead_notes, 0.34, 0, "square", duty)
    place(bass_notes, 0.28, 0, "square", 0.4)
    # 八分音符輕踩鑔
    step = beat * 0.5
    i = 0
    while i * step < beats * beat:
        add_noise(buf, int(i * step * SR), 0.03, hat_amp if i % 2 == 0 else hat_amp * 0.45, 6.0)
        i += 1
    lowpass(buf, 3200.0)
    # 無縫迴圈：把多出來的尾巴混進開頭
    for i in range(tail):
        k = i / tail
        buf[i] = buf[i] * k + buf[total + i] * (1.0 - k)
    return buf[:total]


SONGS = {
    "title": (
        96,
        "E4/1 G4/1 A4/1 C5/1 E5/1 C5/1 A4/1 G4/1",
        "A2/2 E3/2 A2/2 G2/2",
        0.25,
    ),
    "ship_select": (
        112,
        "C5/0.5 E5/0.5 G5/1 A5/0.5 G5/0.5 E5/1 D5/0.5 E5/0.5 C5/1 G4/1 C5/1",
        "C3/2 G2/2 A2/2 E2/2",
        0.3,
    ),
    "stage": (
        144,
        "A4/0.5 A4/0.5 C5/0.5 E5/1 D5/0.5 C5/0.5 A4/0.5 E5/1 D5/0.5 C5/0.5 A4/1.5",
        "A2/1 A2/1 E2/1 E2/1 F2/1 E2/1 A2/1 A2/1",
        0.25,
    ),
    "mid_boss": (
        150,
        "E4/0.5 G4/0.5 Bb4/1 A4/0.5 G4/0.5 E4/0.5 D4/1 E4/0.5 G4/1 Bb4/0.5 A4/1.5",
        "E2/1 E2/1 Bb2/1 A2/1 E2/1 G2/1 D2/1 E2/1",
        0.2,
    ),
    "boss": (
        132,
        "A3/1 C4/0.5 Eb4/1 D4/0.5 C4/1 A3/0.5 G3/1 A3/0.5 Eb4/1 D4/0.5 C4/0.5",
        "A2/1 A2/1 F2/1 E2/1 D2/1 E2/1 A2/2",
        0.18,
    ),
    "result": (
        108,
        "C5/0.5 E5/0.5 G5/1 C6/1 B5/0.5 A5/0.5 G5/1 E5/1 D5/0.5 E5/0.5 C5/1",
        "C3/2 G2/2 A2/2 C3/2",
        0.35,
    ),
}


def gen_bgm() -> None:
    for name, (bpm, lead, bass, duty) in SONGS.items():
        buf = render_song(bpm, lead, bass, duty)
        write_wav(os.path.join(BGM_DIR, name + ".wav"), buf)


def silence(dur: float) -> list:
    return [0.0] * int(dur * SR)


def gen_sfx() -> None:
    def finish(name: str, buf: list, cutoff: float = 4200.0) -> None:
        lowpass(buf, cutoff)
        fade_edges(buf, int(0.004 * SR))
        write_wav(os.path.join(SFX_DIR, name + ".wav"), buf)

    # 武器種類後備音
    b = silence(0.09)
    add_noise(b, 0, 0.04, 0.55, 8.0)
    add_tone(b, 0, 0.07, 920, 0.45, 0.2)
    finish("shot_bullet", b)

    b = silence(0.12)
    add_sweep(b, 0, 0.12, 1400, 420, 0.4, "sine")
    finish("shot_laser", b, 5000)

    b = silence(0.11)
    add_noise(b, 0, 0.09, 0.7, 5.0)
    add_tone(b, 0, 0.05, 1800, 0.25, 0.15)
    finish("shot_arc", b, 5000)

    weapons = {
        "vulcan": 980,
        "crimson_cannon": 160,
        "halo_lance": 720,
        "nova_wave": 540,
        "plasma_blaster": 400,
        "shadow_needle": 1280,
        "thunder_spread": 280,
        "tide_twin": 460,
        "venom_rail": 220,
        "blue_laser": 1100,
        "arc_thunder": 640,
    }
    for wid, freq in weapons.items():
        b = silence(0.09)
        if wid in ("blue_laser",):
            add_sweep(b, 0, 0.1, freq, freq * 0.45, 0.42, "sine")
        elif wid in ("arc_thunder",):
            add_noise(b, 0, 0.08, 0.65, 6.0)
            add_tone(b, 0, 0.04, freq, 0.3, 0.12)
        elif freq < 250:
            add_tone(b, 0, 0.09, freq, 0.55, 0.35)
            add_noise(b, 0, 0.05, 0.35, 7.0)
        else:
            add_tone(b, 0, 0.06, freq, 0.48, 0.22)
            add_noise(b, 0, 0.03, 0.3, 9.0)
        finish("shot_" + wid, b)

    b = silence(0.05)
    add_tone(b, 0, 0.04, 340, 0.4, 0.4)
    add_noise(b, 0, 0.03, 0.25, 10.0)
    finish("enemy_hit", b)

    b = silence(0.22)
    add_noise(b, 0, 0.2, 0.85, 3.2)
    add_tone(b, 0, 0.12, 180, 0.4, 0.5)
    finish("explode_small", b, 3000)

    b = silence(0.4)
    add_noise(b, 0, 0.36, 0.9, 2.4)
    add_sweep(b, 0, 0.28, 220, 60, 0.55, "sine")
    finish("explode_large", b, 2400)

    b = silence(0.7)
    add_noise(b, 0, 0.62, 1.0, 1.8)
    add_sweep(b, 0, 0.5, 160, 40, 0.7, "sine")
    add_tone(b, int(0.05 * SR), 0.4, 70, 0.45, 0.5, "sine")
    finish("explode_boss", b, 1800)

    b = silence(0.14)
    add_tone(b, 0, 0.06, 880, 0.35, 0.25)
    add_tone(b, int(0.06 * SR), 0.08, 1320, 0.4, 0.25)
    finish("item", b, 5000)

    b = silence(0.32)
    for i, f in enumerate((523, 659, 784, 1046)):
        add_tone(b, int(i * 0.07 * SR), 0.1, f, 0.38, 0.25)
    finish("power", b, 5000)

    b = silence(0.45)
    add_noise(b, 0, 0.4, 0.9, 2.0)
    add_sweep(b, 0, 0.4, 300, 70, 0.55, "square")
    finish("bomb", b, 2200)

    b = silence(0.28)
    add_sweep(b, 0, 0.26, 660, 1320, 0.35, "sine")
    add_tone(b, int(0.04 * SR), 0.22, 1760, 0.15, 0.5, "sine")
    finish("shield", b, 5500)

    b = silence(0.16)
    add_tone(b, 0, 0.14, 1480, 0.4, 0.25, "sine")
    add_tone(b, 0, 0.08, 1960, 0.2, 0.25, "sine")
    finish("shield_block", b, 5500)

    b = silence(0.22)
    add_sweep(b, 0, 0.2, 500, 1400, 0.4, "square")
    add_noise(b, 0, 0.12, 0.25, 5.0)
    finish("missile", b, 4500)

    b = silence(0.16)
    add_noise(b, 0, 0.12, 0.7, 4.0)
    add_sweep(b, 0, 0.14, 440, 120, 0.45, "square")
    finish("player_hit", b, 3000)

    b = silence(0.55)
    add_sweep(b, 0, 0.5, 520, 80, 0.5, "square")
    add_noise(b, 0, 0.35, 0.55, 2.5)
    finish("player_death", b, 2400)

    b = silence(0.55)
    add_tone(b, 0, 0.22, 880, 0.4, 0.25)
    add_tone(b, int(0.26 * SR), 0.24, 740, 0.42, 0.25)
    finish("warning", b, 4000)

    b = silence(0.36)
    add_tone(b, 0, 0.18, 196, 0.5, 0.3)
    add_tone(b, int(0.08 * SR), 0.22, 155, 0.4, 0.3)
    add_noise(b, 0, 0.12, 0.35, 4.0)
    finish("boss_phase", b, 2500)

    b = silence(0.55)
    add_noise(b, 0, 0.4, 0.5, 2.2)
    add_sweep(b, 0, 0.45, 90, 40, 0.6, "sine")
    finish("ultimate", b, 1600)

    b = silence(0.7)
    for i, f in enumerate((523, 659, 784, 1046, 1318)):
        add_tone(b, int(i * 0.1 * SR), 0.22, f, 0.36, 0.3)
    finish("stage_clear", b, 5000)

    b = silence(0.05)
    add_tone(b, 0, 0.045, 1500, 0.4, 0.25)
    finish("ui", b, 5500)

    b = silence(0.1)
    add_tone(b, 0, 0.05, 660, 0.32, 0.25)
    add_tone(b, int(0.04 * SR), 0.06, 990, 0.34, 0.25)
    finish("ship_select", b, 5000)


if __name__ == "__main__":
    gen_bgm()
    gen_sfx()
