"""
Synthesizes all music and sound effects for The Last Lantern (original, royalty-free).
Requires numpy and ffmpeg (for .ogg music).  Usage: python tools/audio/gen_audio.py assets/audio
"""
import numpy as np, wave, os, sys, subprocess

SR = 44100
OUT = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else 'assets/audio')
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)


def t_(dur):
    return np.arange(int(dur * SR)) / SR


def note(n):  # MIDI -> Hz
    return 440.0 * 2 ** ((n - 69) / 12)


def env(n, a=0.005, d=0.1, s=0.7, r=0.2, total=None):
    total = total or n / SR
    t = np.arange(n) / SR
    e = np.where(t < a, t / a, s + (1 - s) * np.exp(-(t - a) / max(d, 1e-4)))
    rel_start = max(total - r, a)
    e = e * np.where(t > rel_start, np.exp(-(t - rel_start) / max(r / 4, 1e-4)), 1)
    return e


def fft_filter(x, lo=None, hi=None):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    g = np.ones_like(f)
    if hi:
        g *= 1 / np.sqrt(1 + (f / hi) ** 4)
    if lo:
        g *= 1 / np.sqrt(1 + (lo / np.maximum(f, 1)) ** 4)
    return np.fft.irfft(X * g, len(x))


def additive(freq, dur, harm=12, roll=1.0, decay=None, detune=0.0, phase_rand=True):
    t = t_(dur)
    y = np.zeros_like(t)
    for h in range(1, harm + 1):
        amp = 1.0 / h ** roll
        if decay is not None:
            amp = amp * np.exp(-t * decay * (1 + h * 0.6))
        ph = rng.uniform(0, 2 * np.pi) if phase_rand else 0
        y += amp * np.sin(2 * np.pi * freq * h * t * (1 + detune) + ph)
    return y


def noise(dur):
    return rng.uniform(-1, 1, int(dur * SR))


def reverb(x, secs=2.4, wet=0.3, seed=1):
    r = np.random.default_rng(seed)
    n = int(secs * SR)
    ir = r.uniform(-1, 1, n) * np.exp(-np.arange(n) / SR * (6.0 / secs))
    ir = fft_filter(ir, hi=5000)
    ir /= np.sqrt(np.sum(ir ** 2))
    L = len(x) + n
    N = 1 << (L - 1).bit_length()
    y = np.fft.irfft(np.fft.rfft(x, N) * np.fft.rfft(ir, N), N)[:L]
    out = np.zeros(L)
    out[:len(x)] += x * (1 - wet)
    out += y * wet
    return out


def norm(x, peak=0.89):
    m = np.max(np.abs(x)) or 1
    return x / m * peak


def write_wav(name, x, peak=0.89):
    x = norm(x, peak)
    if x.ndim == 1:
        x = np.stack([x, x], 1)
    data = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes(data.tobytes())


def write_ogg(name, x):
    tmp = os.path.join(OUT, '_tmp.wav')
    x = norm(x, 0.85)
    data = (x * 32767).astype(np.int16)
    with wave.open(tmp, 'wb') as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes(data.tobytes())
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', tmp, '-c:a', 'libvorbis', '-q:a', '5', os.path.join(OUT, name + '.ogg')], check=True)
    os.remove(tmp)


def place(buf, x, at):
    i = int(at * SR)
    j = min(len(buf), i + len(x))
    if i < len(buf):
        buf[i:j] += x[:j - i]


# ================================================================== SFX
def sweep(f0, f1, dur, shape='sin'):
    t = t_(dur)
    f = f0 * (f1 / f0) ** (t / dur)
    ph = 2 * np.pi * np.cumsum(f) / SR
    if shape == 'sin':
        return np.sin(ph)
    if shape == 'tri':
        return 2 / np.pi * np.arcsin(np.sin(ph))
    if shape == 'saw':
        return ((ph / (2 * np.pi)) % 1) * 2 - 1
    return np.sign(np.sin(ph))


def dk(dur, k):
    return np.exp(-t_(dur) * k)


def sfx():
    S = {}
    S['shoot'] = fft_filter(sweep(900, 380, 0.12, 'tri') * dk(0.12, 25) + noise(0.12) * dk(0.12, 60) * 0.3, hi=4000)
    S['hit'] = fft_filter(noise(0.07) * dk(0.07, 50), lo=300, hi=3000) + sweep(260, 120, 0.07, 'sq') * dk(0.07, 45) * 0.25
    S['kill'] = fft_filter(noise(0.18) * dk(0.18, 20), lo=200, hi=2500) * 0.8 + sweep(420, 90, 0.18, 'tri') * dk(0.18, 18) * 0.6
    S['gem'] = sweep(1200, 1700, 0.09, 'sin') * dk(0.09, 30) + sweep(2400, 3400, 0.09) * dk(0.09, 40) * 0.25
    S['coin'] = np.concatenate([sweep(1320, 1320, 0.05, 'sq') * dk(0.05, 30), sweep(1980, 1980, 0.14, 'sq') * dk(0.14, 22)]) * 0.5
    S['pickup'] = sweep(500, 1300, 0.25) * dk(0.25, 8)
    lv = np.zeros(int(0.9 * SR))
    for i, n in enumerate([72, 76, 79, 84, 88]):
        place(lv, additive(note(n), 0.5, 8, 1.2, decay=5), i * 0.07)
    S['levelup'] = reverb(lv, 1.2, 0.3)
    ch = np.zeros(int(1.3 * SR))
    for i, n in enumerate([67, 72, 76, 79, 84, 88, 91]):
        place(ch, additive(note(n), 0.6, 8, 1.1, decay=4), i * 0.06)
    S['chest'] = reverb(ch, 1.5, 0.35)
    S['hurt'] = fft_filter(sweep(240, 70, 0.3, 'saw') * dk(0.3, 10) + noise(0.3) * dk(0.3, 14) * 0.6, hi=2200)
    S['pulse'] = reverb(sweep(160, 520, 0.45) * dk(0.45, 6) + fft_filter(noise(0.45), hi=900) * dk(0.45, 8) * 0.5, 1.0, 0.25)
    S['explode'] = reverb(fft_filter(noise(0.8), hi=700) * dk(0.8, 6) + sweep(110, 35, 0.8) * dk(0.8, 5) * 0.9, 1.4, 0.25)
    z = noise(0.18) * dk(0.18, 18)
    z = fft_filter(z * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 70 * t_(0.18)))), lo=1500)
    S['zap'] = z + sweep(1800, 500, 0.18, 'saw') * dk(0.18, 25) * 0.3
    S['freeze'] = reverb(sum(sweep(f, f * 0.95, 0.35) * dk(0.35, 9) for f in (1800, 2400, 3100)) / 3 + fft_filter(noise(0.35), lo=4000) * dk(0.35, 12) * 0.4, 1.0, 0.3)
    S['whoosh'] = fft_filter(noise(0.35) * np.sin(np.pi * t_(0.35) / 0.35) ** 2, lo=500, hi=2500)
    roar = fft_filter(sweep(90, 55, 2.2, 'saw') + sweep(92, 56, 2.2, 'saw') + noise(2.2) * 0.6, hi=900) * env(int(2.2 * SR), 0.2, 1.0, 0.6, 0.8)
    S['boss_roar'] = reverb(roar, 2.5, 0.35)
    S['boss_shot'] = fft_filter(sweep(500, 200, 0.3, 'sq') * dk(0.3, 10), hi=2500)
    S['dash'] = fft_filter(noise(0.5) * np.sin(np.pi * t_(0.5) / 0.5), lo=200, hi=1500) + sweep(80, 200, 0.5, 'saw') * dk(0.5, 4) * 0.4
    a = np.zeros(int(1.4 * SR))
    for i, n in enumerate([79, 86, 91]):
        place(a, additive(note(n), 1.0, 6, 1.4, decay=2.5), i * 0.12)
    S['achievement'] = reverb(a, 1.8, 0.35)
    S['click'] = sweep(1400, 900, 0.04, 'tri') * dk(0.04, 60)
    S['hover'] = sweep(2200, 2000, 0.025) * dk(0.025, 90) * 0.5
    b = np.zeros(int(0.5 * SR)); place(b, additive(note(76), 0.3, 6, 1.3, decay=8), 0); place(b, additive(note(83), 0.4, 6, 1.3, decay=7), 0.07)
    S['buy'] = b
    S['deny'] = fft_filter(sweep(180, 150, 0.22, 'sq') * dk(0.22, 9), hi=1500)
    S['death'] = reverb(fft_filter(sweep(300, 40, 2.0, 'saw') * dk(2.0, 1.6) + noise(2.0) * dk(2.0, 2.5) * 0.5, hi=1200), 2.5, 0.4)
    v = np.zeros(int(4.0 * SR))
    for i, n in enumerate([62, 66, 69, 74, 78, 81, 86]):
        place(v, additive(note(n), 2.5, 10, 1.2, decay=0.8), i * 0.13)
    for n in (50, 57, 62):
        place(v, additive(note(n), 3.5, 8, 1.5) * env(int(3.5 * SR), 0.3, 1.0, 0.8, 1.5) * 0.6, 0.9)
    S['victory'] = reverb(v, 3.0, 0.4)
    S['revive'] = reverb(sweep(200, 1200, 1.0, 'tri') * env(int(1.0 * SR), 0.05, 0.4, 0.6, 0.4), 1.5, 0.4)
    S['footstep'] = fft_filter(noise(0.06) * dk(0.06, 70), lo=100, hi=900)
    for k, x in S.items():
        write_wav(k, x)
    print('sfx:', len(S))


def halloween_sfx():
    """Sounds added with the Halloween update. Run with --halloween to (re)build only these."""
    S = {}
    # Gourdling fuse: a sizzling hiss that rises in pitch
    t = t_(0.75)
    hiss = fft_filter(noise(0.75), lo=3000) * (0.4 + 0.6 * t / 0.75)
    crackle = (np.random.default_rng(7).random(len(t)) > 0.985) * 1.0
    S['fuse'] = hiss * 0.6 + fft_filter(crackle, lo=1500) * 0.5 + sweep(600, 1400, 0.75, 'tri') * 0.08
    # Pumpkin smash: hollow thump + wet crunch
    thump = sweep(180, 60, 0.35) * dk(0.35, 12)
    crunch = fft_filter(noise(0.35) * dk(0.35, 16), lo=400, hi=3500)
    S['smash'] = reverb(thump * 0.9 + crunch * 0.7, 0.6, 0.15)
    # Shrine kindled: warm bell chord over a soft swell
    b = np.zeros(int(2.6 * SR))
    for i, n in enumerate([64, 71, 76, 83]):
        place(b, additive(note(n), 2.0, 10, 1.3, decay=1.6), i * 0.09)
    swell = sum(additive(note(n), 2.4, 6, 1.6) for n in (52, 59, 64)) * env(int(2.4 * SR), 0.6, 1.0, 0.7, 1.0) * 0.25
    place(b, swell, 0.0)
    S['shrine'] = reverb(b, 2.4, 0.4)
    # Trick: a wobbling, descending spooky tone
    t = t_(1.0)
    f = 520 * (0.55 ** (t / 1.0)) * (1 + 0.06 * np.sin(2 * np.pi * 7 * t))
    ph = 2 * np.pi * np.cumsum(f) / SR
    S['trick'] = reverb(np.sin(ph) * env(len(t), 0.05, 0.3, 0.8, 0.4) * 0.8 + np.sin(ph * 1.5) * 0.2 * dk(1.0, 2), 1.4, 0.35)
    # Awakening: a bright rising shimmer
    a = np.zeros(int(2.2 * SR))
    for i, n in enumerate([72, 79, 84, 88, 91, 96]):
        place(a, additive(note(n), 1.2, 6, 1.0, decay=2.0) * 0.8, i * 0.08)
    place(a, sweep(300, 2400, 1.0, 'tri') * env(int(1.0 * SR), 0.1, 0.5, 0.5, 0.4) * 0.3, 0)
    S['awaken'] = reverb(a, 2.0, 0.35)
    # Dialogue blip
    S['talk'] = sweep(700, 640, 0.05, 'tri') * dk(0.05, 50) * 0.5
    for k, x in S.items():
        write_wav(k, x)
    print('halloween sfx:', len(S))


# ================================================================== MUSIC
def kick(dur=0.45):
    return sweep(150, 42, dur) * dk(dur, 7) + fft_filter(noise(0.01), hi=3000) * 0.3 if False else sweep(150, 42, dur) * dk(dur, 7)


def snare(dur=0.25):
    return fft_filter(noise(dur), lo=600, hi=7000) * dk(dur, 16) + sweep(200, 160, dur, 'tri') * dk(dur, 22) * 0.6


def hat(dur=0.06):
    return fft_filter(noise(dur), lo=7000) * dk(dur, 60)


def tom(f, dur=0.6):
    return sweep(f * 1.6, f, dur) * dk(dur, 5) + fft_filter(noise(dur), hi=800) * dk(dur, 12) * 0.4


def pad(freqs, dur, bright=1.6, vowel=False):
    y = np.zeros(int(dur * SR))
    for f in freqs:
        for d in (-0.004, 0.0, 0.0045):
            h = additive(f, dur, 14, bright, detune=d)
            if vowel:  # crude "aah" formants for a choir-like texture
                h = fft_filter(h, lo=250, hi=1300) * 1.6 + h * 0.3
            y += h
    y *= env(len(y), min(0.6, dur / 3), 1.0, 1.0, min(0.8, dur / 3))
    return y


def pluck(f, dur, bright=1.0, decay=3.0):
    return additive(f, dur, 10, bright, decay=decay) * env(int(dur * SR), 0.002, 0.3, 0.5, 0.05)


def bass(f, dur):
    return fft_filter(additive(f, dur, 10, 1.0), hi=500) * env(int(dur * SR), 0.01, 0.15, 0.6, 0.05)


def loopify(x, length):
    """Fold the reverb tail back onto the start so the loop is seamless."""
    n = int(length * SR)
    out = x[:n].copy()
    tail = x[n:]
    out[:len(tail)] += tail[:n]
    return out


def stereo(l, r):
    return np.stack([l, r], 1)


def song(bpm, bars, prog, layers, intensity, seed, pad_vowel=False, lead=None):
    beat = 60 / bpm
    bar = beat * 4
    length = bars * bar
    total = int((length + 4) * SR)
    L = np.zeros(total); R = np.zeros(total)
    drums = np.zeros(total)
    r = np.random.default_rng(seed)
    for b in range(bars):
        root, quality = prog[b % len(prog)]
        third = 3 if quality == 'm' else 4
        chord = [root, root + third, root + 7]
        t0 = b * bar
        if 'pad' in layers:
            p = pad([note(n + 12) for n in chord], bar + 0.4, 1.7, pad_vowel) * 0.07
            place(L, p, t0); place(R, np.roll(p, 300), t0)
        if 'bass' in layers:
            pattern = [0, 0.5, 1.5, 2, 2.5, 3.5] if intensity >= 2 else [0, 2]
            for k in pattern:
                place(L, bass(note(root - 12), beat * 0.48) * 0.35, t0 + k * beat)
                place(R, bass(note(root - 12), beat * 0.48) * 0.35, t0 + k * beat)
        if 'arp' in layers:
            seq = [0, 1, 2, 3, 2, 1, 2, 3] if intensity >= 1 else [0, 2, 3, 2]
            step = bar / len(seq) / (2 if intensity >= 2 else 1)
            for i in range(int(round(bar / step))):
                idx = seq[i % len(seq)]
                n = chord[idx] + 24 if idx < 3 else chord[0] + 36
                pl = pluck(note(n), 0.6, 1.3, 4) * (0.06 if i % 2 else 0.08)
                pan = 0.5 + 0.35 * np.sin(i * 0.7)
                place(L, pl * (1 - pan), t0 + i * step); place(R, pl * pan, t0 + i * step)
        if 'bell' in layers and b % 2 == 0:
            n = chord[r.integers(0, 3)] + 36
            bl = additive(note(n), 3.0, 6, 1.8, decay=0.8) * 0.06
            place(L, bl, t0 + r.choice([0, 1, 2]) * beat); place(R, bl, t0 + r.choice([0, 1, 2]) * beat + 0.01)
        if 'drums' in layers:
            for k in range(4):
                if k in (0, 2) or (intensity >= 3 and k == 3):
                    place(drums, kick() * 0.9, t0 + k * beat)
                if k in (1, 3) and intensity >= 2:
                    place(drums, snare() * 0.45, t0 + k * beat)
                for hh in range(2 if intensity < 3 else 4):
                    place(drums, hat() * (0.18 if hh % 2 == 0 else 0.1), t0 + k * beat + hh * beat / (2 if intensity < 3 else 4))
            if b % 4 == 3:
                for i, f in enumerate((140, 120, 100, 80)):
                    place(drums, tom(f) * 0.5, t0 + 2 * beat + i * beat / 2)
        if lead and b >= bars // 2:
            mel = lead[(b - bars // 2) % len(lead)]
            for k, n in enumerate(mel):
                if n is None:
                    continue
                d = beat * 0.95
                ld = (additive(note(n), d + 0.3, 7, 1.4) * env(int((d + 0.3) * SR), 0.03, 0.3, 0.7, 0.2)) * 0.05
                vib = 1 + 0.004 * np.sin(2 * np.pi * 5 * t_(d + 0.3))
                place(L, ld * vib, t0 + k * beat); place(R, ld * vib, t0 + k * beat + 0.012)
    L = reverb(L, 3.0, 0.38, 1)[:total]
    R = reverb(R, 3.0, 0.38, 2)[:total]
    d = reverb(drums, 1.2, 0.15, 3)[:total]
    L += d; R += d
    return stereo(loopify(L, length), loopify(R, length))


def music():
    D, Bb, F, C, G, A, Gm, Eb = 50, 46, 53, 48, 43, 45, 55, 51
    menu = song(70, 16, [(D, 'm'), (Bb, 'M'), (Gm - 12, 'm'), (A, 'M')], ['pad', 'bell', 'arp'], 0, 11)
    write_ogg('music_menu', menu)
    lead = [[74, None, 77, 76], [74, 72, 69, None], [70, None, 72, 74], [72, 69, 67, 69]]
    battle = song(112, 16, [(D, 'm'), (Bb, 'M'), (F, 'M'), (C, 'M')], ['pad', 'bass', 'arp', 'drums'], 2, 12, lead=lead)
    write_ogg('music_battle', battle)
    boss = song(132, 16, [(D, 'm'), (Eb, 'M'), (D, 'm'), (C, 'M')], ['pad', 'bass', 'arp', 'drums'], 3, 13, pad_vowel=True,
                lead=[[74, 75, 74, 72], [74, None, 69, None], [74, 75, 77, 75], [74, 72, 70, 69]])
    write_ogg('music_boss', boss)
    print('music done')


if '--halloween' in sys.argv:
    halloween_sfx()
else:
    sfx()
    halloween_sfx()
    music()
