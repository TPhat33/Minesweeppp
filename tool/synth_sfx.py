#!/usr/bin/env python3
"""Synthesizes the game's sound effects as short WAV files.

No external sound libraries or assets: everything here is generated from
scratch with basic oscillators and noise, which sidesteps licensing entirely
and happens to fit a sci-fi salvage rig better than realistic foley would.

Run: python3 synth_sfx.py <output_dir>
"""
import math
import random
import struct
import sys
import wave

SR = 44100


def _samples(duration):
    return int(SR * duration)


def silence(duration):
    return [0.0] * _samples(duration)


def sine(freq, duration, phase=0.0):
    n = _samples(duration)
    return [math.sin(2 * math.pi * freq * (i / SR) + phase) for i in range(n)]


def square(freq, duration, duty=0.5):
    n = _samples(duration)
    period = SR / freq
    out = []
    for i in range(n):
        pos = (i % period) / period
        out.append(1.0 if pos < duty else -1.0)
    return out


def triangle(freq, duration):
    n = _samples(duration)
    period = SR / freq
    out = []
    for i in range(n):
        pos = (i % period) / period
        out.append(4 * abs(pos - 0.5) - 1.0)
    return out


def saw(freq, duration):
    n = _samples(duration)
    period = SR / freq
    return [2 * ((i % period) / period) - 1.0 for i in range(n)]


def white_noise(duration, seed=0):
    rng = random.Random(seed)
    n = _samples(duration)
    return [rng.uniform(-1.0, 1.0) for _ in range(n)]


def sweep(f0, f1, duration, wave_fn=sine, exponential=True):
    """A tone that glides from f0 to f1 over duration, built sample-by-sample
    so the instantaneous frequency actually changes (a naive per-block
    concatenation of separate tones clicks at every seam)."""
    n = _samples(duration)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / n if n > 1 else 0
        if exponential:
            freq = f0 * (f1 / f0) ** t
        else:
            freq = f0 + (f1 - f0) * t
        phase += 2 * math.pi * freq / SR
        out.append(math.sin(phase))
    return out


def envelope(samples, attack=0.005, decay=0.05, sustain=0.6, release=0.1):
    """Simple ADSR applied in place (returns a new list)."""
    n = len(samples)
    a = min(_samples(attack), n)
    d = min(_samples(decay), max(n - a, 0))
    r = min(_samples(release), n)
    s_len = max(n - a - d - r, 0)

    out = [0.0] * n
    for i in range(a):
        out[i] = samples[i] * (i / a if a else 1)
    for i in range(d):
        idx = a + i
        if idx >= n:
            break
        level = 1.0 - (1.0 - sustain) * (i / d if d else 1)
        out[idx] = samples[idx] * level
    for i in range(s_len):
        idx = a + d + i
        if idx >= n:
            break
        out[idx] = samples[idx] * sustain
    for i in range(r):
        idx = n - r + i
        if idx < 0 or idx >= n:
            continue
        level = sustain * (1 - i / r if r else 0)
        out[idx] = samples[idx] * level
    return out


def linear_fade(samples, fade_in=0.0, fade_out=0.0):
    n = len(samples)
    fi = min(_samples(fade_in), n)
    fo = min(_samples(fade_out), n)
    out = list(samples)
    for i in range(fi):
        out[i] *= i / fi if fi else 1
    for i in range(fo):
        idx = n - 1 - i
        out[idx] *= i / fo if fo else 1
    return out


def gain(samples, factor):
    return [s * factor for s in samples]


def pad_to(samples, length):
    if len(samples) >= length:
        return samples[:length]
    return samples + [0.0] * (length - len(samples))


def mix(*tracks):
    length = max(len(t) for t in tracks) if tracks else 0
    out = [0.0] * length
    for track in tracks:
        for i, s in enumerate(track):
            out[i] += s
    return out


def concat(*tracks):
    out = []
    for t in tracks:
        out.extend(t)
    return out


def normalize(samples, peak=0.92):
    m = max((abs(s) for s in samples), default=0)
    if m == 0:
        return samples
    factor = peak / m
    return [s * factor for s in samples]


def lowpass(samples, alpha):
    """A trivial one-pole lowpass: alpha close to 1 means heavy smoothing.
    Used to take the digital edge off noise bursts (an explosion "thump"
    rather than a hiss)."""
    out = []
    prev = 0.0
    for s in samples:
        prev = prev + alpha * (s - prev)
        out.append(prev)
    return out


def write_wav(path, samples, samplerate=SR):
    clipped = [max(-1.0, min(1.0, s)) for s in samples]
    frames = struct.pack('<%dh' % len(clipped), *(int(s * 32767) for s in clipped))
    with wave.open(path, 'wb') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(samplerate)
        f.writeframes(frames)


# --------------------------------------------------------------- sound bank


def make_reveal():
    """One cell opening: a short, soft digital tick."""
    tone = sweep(1300, 850, 0.05, exponential=True)
    tone = envelope(tone, attack=0.002, decay=0.02, sustain=0.3, release=0.03)
    return gain(tone, 0.5)


def make_reveal_wave():
    """A big flood reveal: three quick ticks climbing in pitch, like the
    ripple animation reading itself out loud."""
    notes = []
    freqs = [700, 950, 1250]
    for i, f in enumerate(freqs):
        tone = sweep(f, f * 0.85, 0.045)
        tone = envelope(tone, attack=0.002, decay=0.015, sustain=0.25, release=0.025)
        notes.append(gain(tone, 0.42))
        notes.append(silence(0.02))
    return concat(*notes)


def make_flag():
    """Placing a flag: a firm little clank."""
    tone = square(520, 0.05)
    tone = envelope(tone, attack=0.001, decay=0.02, sustain=0.25, release=0.02)
    click = gain(white_noise(0.008, seed=1), 0.15)
    click = envelope(click, attack=0.0005, decay=0.006, sustain=0.1, release=0.001)
    return mix(gain(tone, 0.45), pad_to(click, len(tone)))


def make_unflag():
    """Removing a flag: the same clank, pitched down and shorter."""
    tone = square(360, 0.045)
    tone = envelope(tone, attack=0.001, decay=0.018, sustain=0.2, release=0.018)
    return gain(tone, 0.4)


def make_select():
    """Marking a flag for salvage: a bright two-tone targeting chirp."""
    a = sweep(900, 1400, 0.04)
    a = envelope(a, attack=0.002, decay=0.01, sustain=0.4, release=0.02)
    b = sweep(1400, 1900, 0.05)
    b = envelope(b, attack=0.001, decay=0.015, sustain=0.35, release=0.03)
    return concat(gain(a, 0.4), gain(b, 0.4))


def make_deselect():
    """Same chirp, reversed and softer: the batch just got smaller."""
    tone = make_select()
    tone = list(reversed(tone))
    return gain(tone, 0.7)


def _chime_note(freq, duration, gain_amt):
    tone = mix(
        gain(sine(freq, duration), 0.7),
        gain(sine(freq * 2, duration), 0.18),
        gain(sine(freq * 3.005, duration), 0.06),
    )
    tone = envelope(tone, attack=0.004, decay=0.06, sustain=0.35, release=duration * 0.6)
    return gain(tone, gain_amt)


def make_salvage_small():
    """A single mine recovered: a clean two-note chime (a fifth apart)."""
    root = _chime_note(660, 0.18, 0.55)
    fifth = _chime_note(990, 0.22, 0.45)
    fifth = concat(silence(0.03), fifth)
    return mix(root, pad_to(fifth, max(len(root), len(fifth))))


def make_salvage_batch():
    """A bigger batch: a richer three-note major arpeggio with a shimmer
    layer, because this is the moment the game wants to reward."""
    notes = [523.25, 659.25, 783.99, 1046.5]  # C5 E5 G5 C6
    tracks = []
    offset = 0.0
    for i, f in enumerate(notes):
        note = _chime_note(f, 0.22, 0.5 - i * 0.04)
        tracks.append(concat(silence(offset), note))
        offset += 0.045
    shimmer = sweep(1800, 2600, 0.5, exponential=True)
    shimmer = envelope(shimmer, attack=0.05, decay=0.1, sustain=0.15, release=0.3)
    tracks.append(gain(shimmer, 0.06))
    length = max(len(t) for t in tracks)
    return mix(*[pad_to(t, length) for t in tracks])


def make_salvage_fail():
    """A wrong pick: a harsh, dissonant descending buzz."""
    a = sweep(420, 140, 0.3, exponential=True, wave_fn=saw)
    a = [2 * (x - math.floor(x + 0.5)) for x in a]  # crude saw-ify of the sweep
    a = envelope(a, attack=0.001, decay=0.05, sustain=0.55, release=0.12)
    b = sweep(300, 90, 0.32, exponential=True)
    b = envelope(b, attack=0.001, decay=0.05, sustain=0.4, release=0.15)
    noise = gain(white_noise(0.06, seed=2), 0.3)
    noise = envelope(noise, attack=0.0005, decay=0.02, sustain=0.1, release=0.03)
    length = max(len(a), len(b))
    return mix(gain(pad_to(a, length), 0.35), gain(pad_to(b, length), 0.3), pad_to(noise, length))


def make_explode():
    """Stepping on a mine: a low thump plus a filtered noise burst."""
    thump = sine(75, 0.35)
    thump = envelope(thump, attack=0.001, decay=0.08, sustain=0.3, release=0.22)
    sub = sine(45, 0.4)
    sub = envelope(sub, attack=0.001, decay=0.1, sustain=0.25, release=0.28)
    noise = white_noise(0.35, seed=3)
    noise = lowpass(noise, 0.35)
    noise = envelope(noise, attack=0.0005, decay=0.12, sustain=0.15, release=0.2)
    crack = white_noise(0.02, seed=4)
    crack = envelope(crack, attack=0.0005, decay=0.008, sustain=0.2, release=0.008)
    length = max(len(thump), len(sub), len(noise), len(crack))
    return mix(
        gain(pad_to(thump, length), 0.55),
        gain(pad_to(sub, length), 0.5),
        gain(pad_to(noise, length), 0.5),
        gain(pad_to(crack, length), 0.4),
    )


def make_timeout():
    """The clock runs out: a two-tone descending alarm."""
    tones = []
    for i in range(3):
        f0 = 880 - i * 90
        f1 = f0 - 260
        tone = sweep(f0, f1, 0.16)
        tone = envelope(tone, attack=0.005, decay=0.03, sustain=0.5, release=0.06)
        tones.append(gain(tone, 0.5))
        tones.append(silence(0.03))
    return concat(*tones)


def make_win():
    """Board clear: a bright ascending fanfare landing on a bell."""
    notes = [523.25, 659.25, 783.99, 1046.5, 1318.5]  # C E G C E
    tracks = []
    offset = 0.0
    for i, f in enumerate(notes):
        dur = 0.55 if i == len(notes) - 1 else 0.16
        g = 0.5 if i == len(notes) - 1 else 0.38
        note = _chime_note(f, dur, g)
        tracks.append(concat(silence(offset), note))
        offset += 0.11
    length = max(len(t) for t in tracks)
    return mix(*[pad_to(t, length) for t in tracks])


def make_boost():
    """Spending energy for time: a rising power-up whoosh."""
    tone = sweep(220, 1600, 0.28, exponential=True)
    tone = envelope(tone, attack=0.01, decay=0.05, sustain=0.6, release=0.12)
    shimmer = sweep(1600, 2200, 0.28, exponential=True)
    shimmer = envelope(shimmer, attack=0.05, decay=0.05, sustain=0.3, release=0.15)
    length = max(len(tone), len(shimmer))
    return mix(gain(pad_to(tone, length), 0.4), gain(pad_to(shimmer, length), 0.15))


def make_pause():
    """Opening the pause menu: a soft two-note descend, the opposite feel of
    a UI confirm."""
    a = _chime_note(700, 0.09, 0.35)
    b = _chime_note(520, 0.14, 0.3)
    return concat(a, silence(0.01), b)


BANK = {
    'reveal': make_reveal,
    'reveal_wave': make_reveal_wave,
    'flag': make_flag,
    'unflag': make_unflag,
    'select': make_select,
    'deselect': make_deselect,
    'salvage_small': make_salvage_small,
    'salvage_batch': make_salvage_batch,
    'salvage_fail': make_salvage_fail,
    'explode': make_explode,
    'timeout': make_timeout,
    'win': make_win,
    'boost': make_boost,
    'pause': make_pause,
}


def main():
    out_dir = sys.argv[1] if len(sys.argv) > 1 else '.'
    for name, factory in BANK.items():
        samples = factory()
        samples = linear_fade(samples, fade_in=0.001, fade_out=0.004)
        samples = normalize(samples, peak=0.88)
        path = f'{out_dir}/{name}.wav'
        write_wav(path, samples)
        print(f'{name}.wav  {len(samples) / SR * 1000:.0f}ms')


if __name__ == '__main__':
    main()
