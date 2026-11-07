"""Writes AZSGW2UI/Sounds/party_1.mp3 ... party_8.mp3: a 24 second techno loop made from scratch (numpy + scipy, then ffmpeg for the
mp3 pieces), and cuts songs of your own into such pieces.

Own music, nothing sampled: a four-on-the-floor kick, offbeat hats, claps on 2 and 4, a pumping saw bass (sidechained to the
kick), a supersaw pad, a sixteenth arpeggio with an echo and an eight-bar lead, at 160 BPM in A minor (Am F C G, four
times). 16 bars of 1.5 s = exactly 24 s, so the loop is a whole number of beats.

usage: make_sounds.py [out folder]                        the song that comes with the addon
       make_sounds.py split <song.mp3> <name> [out folder]  cut a song of your own into <name>_1.mp3 ... <name>_N.mp3
needs ffmpeg and ffprobe with libmp3lame in the PATH.
"""
import math, os, subprocess, sys, tempfile
import numpy as np
from scipy import signal

SR = 44100
BPM = 160
BEAT = 60.0 / BPM                     # 0.375 s
STEP = BEAT / 4                       # one sixteenth
BAR = BEAT * 4                        # 1.5 s
BARS = 16
N = int(round(BAR * BARS * SR))
rng = np.random.default_rng(160)


def t_of(n):
    return np.arange(n) / SR


def put(buf, start_s, sig, gain=1.0):
    i = int(round(start_s * SR))
    if i >= len(buf):
        return
    j = min(len(buf), i + len(sig))
    buf[i:j] += sig[:j - i] * gain


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12.0)


def lowpass(x, fc, order=2):
    sos = signal.butter(order, fc, btype="low", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def highpass(x, fc, order=2):
    sos = signal.butter(order, fc, btype="high", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def bandpass(x, lo, hi, order=2):
    sos = signal.butter(order, [lo, hi], btype="band", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def saw(freq, n, maxf=9000.0, phase=0.0):
    """band limited saw (additive)"""
    t = t_of(n)
    k = int(max(1, min(60, maxf // freq)))
    out = np.zeros(n)
    for h in range(1, k + 1):
        out += np.sin(2 * math.pi * freq * h * t + phase * h) / h
    return out * (2 / math.pi)


def square(freq, n, maxf=7000.0):
    t = t_of(n)
    k = int(max(1, min(40, maxf // freq)))
    out = np.zeros(n)
    for h in range(1, k + 1, 2):
        out += np.sin(2 * math.pi * freq * h * t) / h
    return out * (4 / math.pi) * 0.6


def env_ad(n, attack, decay):
    t = t_of(n)
    a = np.minimum(1.0, t / max(attack, 1e-4))
    return a * np.exp(-t / decay)


def env_gate(n, attack, release_s, hold_s):
    """rises over `attack`, holds for hold_s, falls over release_s"""
    t = t_of(n)
    e = np.minimum(1.0, t / max(attack, 1e-4))
    e *= np.where(t < hold_s, 1.0, np.exp(-(t - hold_s) / max(release_s, 1e-4)))
    return e


# ------------------------------------------------------------------ drums
def kick():
    n = int(0.32 * SR)
    t = t_of(n)
    f = 46 + 150 * np.exp(-t / 0.028)
    ph = 2 * math.pi * np.cumsum(f) / SR
    body = np.sin(ph) * np.exp(-t / 0.13)
    click = rng.standard_normal(n) * np.exp(-t / 0.004) * 0.25
    click = highpass(click, 1800)
    return np.tanh((body * 1.25) + click) * 0.95


def hat(decay, bright=7000):
    n = int(0.25 * SR)
    t = t_of(n)
    x = highpass(rng.standard_normal(n), bright)
    return x * np.exp(-t / decay)


def clap():
    n = int(0.35 * SR)
    t = t_of(n)
    x = bandpass(rng.standard_normal(n), 900, 5200)
    e = np.exp(-t / 0.11) * 0.55
    for off in (0.0, 0.011, 0.022):
        e += np.where((t >= off) & (t < off + 0.008), 1.0, 0.0) * 0.6
    return x * e


def snare_hit():
    n = int(0.2 * SR)
    t = t_of(n)
    x = bandpass(rng.standard_normal(n), 1200, 7500) * np.exp(-t / 0.07)
    tone = np.sin(2 * math.pi * 190 * t) * np.exp(-t / 0.05) * 0.5
    return x * 0.8 + tone


# ------------------------------------------------------------------ the song
# chord per bar of a four bar phrase: root midi (bass), the chord tones (pad / arp)
CHORDS = [
    (33, (57, 60, 64, 69)),     # Am: A1 | A3 C4 E4 A4
    (29, (53, 57, 60, 65)),     # F:  F1 | F3 A3 C4 F4
    (36, (55, 60, 64, 67)),     # C:  C2 | G3 C4 E4 G4
    (31, (55, 59, 62, 67)),     # G:  G1 | G3 B3 D4 G4
]

# the lead, (sixteenth, midi, length in sixteenths), one list per chord of the phrase
LEAD = [
    [(0, 76, 2), (3, 76, 1), (4, 79, 2), (7, 81, 1), (8, 79, 2), (11, 76, 1), (12, 74, 2), (14, 72, 2)],
    [(0, 77, 2), (3, 77, 1), (4, 81, 2), (7, 84, 1), (8, 81, 2), (11, 77, 1), (12, 76, 2), (14, 74, 2)],
    [(0, 76, 2), (3, 76, 1), (4, 79, 2), (7, 84, 1), (8, 83, 2), (11, 79, 1), (12, 76, 2), (14, 72, 2)],
    [(0, 74, 2), (3, 74, 1), (4, 79, 2), (7, 83, 1), (8, 81, 2), (10, 79, 2), (12, 74, 4)],
]
# the answer (bars 13 - 16): the same tune, higher and with a run at the end
LEAD2 = [
    [(0, 88, 2), (3, 88, 1), (4, 91, 2), (7, 93, 1), (8, 91, 2), (11, 88, 1), (12, 86, 2), (14, 84, 2)],
    [(0, 89, 2), (3, 89, 1), (4, 93, 2), (7, 96, 1), (8, 93, 2), (11, 89, 1), (12, 88, 2), (14, 86, 2)],
    [(0, 88, 2), (3, 88, 1), (4, 91, 2), (7, 96, 1), (8, 95, 2), (11, 91, 1), (12, 88, 2), (14, 84, 2)],
    [(0, 86, 2), (3, 86, 1), (4, 91, 2), (7, 95, 1), (8, 93, 1), (9, 91, 1), (10, 88, 1), (11, 86, 1), (12, 83, 1), (13, 79, 1), (14, 76, 2)],
]

ARP = [0, 1, 2, 3, 2, 1, 2, 3, 0, 1, 2, 3, 2, 1, 2, 3]


def build():
    kicks = np.zeros(N)
    drums = np.zeros(N)
    bass = np.zeros(N)
    pad = np.zeros(N)
    arp = np.zeros(N)
    lead = np.zeros(N)
    fx = np.zeros(N)

    K = kick()
    HC = hat(0.025)
    HO = hat(0.085, 6000)
    C = clap()
    S = snare_hit()

    for bar in range(BARS):
        b0 = bar * BAR
        root, tones = CHORDS[bar % 4]
        phase = bar // 4                       # 0 intro, 1 arp + pad, 2 lead, 3 lead answer + build
        last = bar == BARS - 1

        # kick on every beat (the last beat of the last bar is left out: the loop starts with a big one)
        for beat in range(4):
            if last and beat == 3:
                continue
            put(kicks, b0 + beat * BEAT, K, 1.0)
        # hats: closed on the off 16ths, open on the off 8ths
        for st in range(16):
            tt = b0 + st * STEP
            if st % 4 == 2:
                put(drums, tt, HO, 0.30)
            elif st % 2 == 1 and phase >= 1:
                put(drums, tt, HC, 0.17)
        # claps on 2 and 4 (from the second phrase on; the first has only the kick and the hats)
        if phase >= 1:
            for beat in (1, 3):
                if last and beat == 3:
                    continue
                put(drums, b0 + beat * BEAT, C, 0.55)

        # bass: offbeat eighths, a saw and a sub
        for st in (2, 6, 10, 14):
            ln = 3 * STEP
            n = int(ln * SR)
            e = env_gate(n, 0.004, 0.03, ln - 0.03)
            f = hz(root)
            x = saw(f, n, 900.0) * 0.8 + np.sin(2 * math.pi * f * t_of(n)) * 0.7
            put(bass, b0 + st * STEP, x * e, 0.55)

        # pad: three detuned saws per chord tone, the whole bar, slow attack
        if phase >= 1:
            n = int(BAR * SR)
            x = np.zeros(n)
            for m in tones[:3]:
                for det in (-0.007, 0.0, 0.007):
                    x += saw(hz(m + 12) * (1 + det), n, 5000.0, rng.uniform(0, 6.28))
            x = lowpass(x, 2600)
            e = np.minimum(1.0, t_of(n) / 0.12) * np.minimum(1.0, (BAR - t_of(n)) / 0.08)
            put(pad, b0, x * e / 9.0, 0.55)

        # arpeggio: sixteenth squares over the chord tones, short plucks
        if phase >= 1:
            for st in range(16):
                m = tones[ARP[st]] + (12 if phase >= 3 else 0)
                n = int(0.13 * SR)
                x = square(hz(m), n) * env_ad(n, 0.002, 0.045)
                put(arp, b0 + st * STEP, x, 0.30)

        # lead
        if phase >= 2:
            tune = LEAD if phase == 2 else LEAD2
            for (st, m, ln) in tune[bar % 4]:
                n = int((ln * STEP + 0.05) * SR)
                f = hz(m)
                x = np.zeros(n)
                for det in (-0.004, 0.0, 0.004):
                    x += saw(f * (1 + det), n, 7500.0, rng.uniform(0, 6.28))
                x = x / 3.0
                e = env_gate(n, 0.006, 0.05, max(0.02, ln * STEP - 0.02))
                put(lead, b0 + st * STEP, x * e, 0.36)

        # the build: a snare roll in the last bar, a riser over the last two
        if bar >= BARS - 2:
            n = int(BAR * SR)
            t = t_of(n)
            prog = (t + (bar - (BARS - 2)) * BAR) / (2 * BAR)             # 0 .. 1 over two bars
            noise = highpass(rng.standard_normal(n), 2500) * (prog ** 2) * 0.35
            sweep_f = 300 + 3200 * prog
            tone = np.sin(2 * math.pi * np.cumsum(sweep_f) / SR) * (prog ** 2) * 0.12
            put(fx, b0, noise + tone, 1.0)
        if last:
            # sixteenths of snare, louder and louder; the last beat is the pause before the loop starts again
            for st in range(8, 14):
                put(drums, b0 + st * STEP, S, 0.25 + 0.55 * (st - 8) / 5.0)
            for st in (12, 13):
                put(drums, b0 + st * STEP + STEP / 2, S, 0.55 + 0.1 * (st - 12))

    # the sidechain: everything but the drums ducks on every kick and comes back within a beat
    t = t_of(N)
    ph = np.mod(t, BEAT)
    duck = 1.0 - 0.82 * np.exp(-ph / 0.085) * np.minimum(1.0, ph / 0.002 + 0.0)
    # at the very start of each beat the duck is deepest; smooth the jump so it does not click
    duck = 1.0 - 0.82 * np.exp(-ph / 0.085)
    duck = lowpass(duck, 900, 1)
    duck = np.clip(duck, 0.1, 1.0)
    # the last beat of the last bar has no kick, so no duck either
    lastbeat = t >= (BARS * BAR - BEAT)
    duck = np.where(lastbeat, 1.0, duck)

    mix = kicks * 0.62 + drums * 0.95
    mix += (bass * 0.62 + pad * 1.25 + arp * 1.45 + lead * 1.35 + fx * 1.1) * duck
    # a gentle echo on the arp and the lead (a dotted eighth, like the old trance records)
    ech = (arp * 1.3 + lead * 0.8) * duck
    d = int(round(STEP * 3 * SR))
    mix[d:] += ech[:-d] * 0.30
    mix[2 * d:] += ech[:-2 * d] * 0.14
    # glue: highpass the rumble, soft clip, normalise
    mix = highpass(mix, 28, 2)
    mix = np.tanh(mix * 1.1) / np.tanh(1.1)
    mix = mix / max(1e-9, np.max(np.abs(mix))) * 0.72
    return mix


CHUNK = 3.0      # seconds of song in one piece: the same numbers as CHUNK / FADE in AZSGW2UI/Rave.lua
FADE = 0.05      # a piece starts this much early and is this much longer at the end; neighbours cross-fade over 2 * FADE


def probe(path):
    out = subprocess.check_output(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of",
                                   "default=nw=1:nk=1", path])
    return float(out.decode().strip())


def split_song(src, outdir, name, bitrate="128k", channels=2):
    """Cuts a song into name_1.mp3 ... name_N.mp3 (CHUNK seconds each, FADE longer at both ends; neighbours cross-fade linearly
    over 2 * FADE so that they add up to the song again). The game cannot stop a sound that plays, so the addon starts one piece after the
    other and stops starting them when asked to. Returns N."""
    os.makedirs(outdir, exist_ok=True)
    total = probe(src)
    parts = int(math.ceil(total / CHUNK - 1e-9))
    for k in range(1, parts + 1):
        start = (k - 1) * CHUNK - ( FADE if k > 1 else 0.0 )
        end = min(k * CHUNK + FADE, total)
        dur = end - start
        # neighbours overlap by 2 * FADE (from k * CHUNK - FADE to k * CHUNK + FADE): the one fades out and the next fades in over
        # exactly that stretch, linearly, so together they are the song again
        xf = 2 * FADE
        fades = []
        if k > 1:
            fades.append("afade=t=in:st=0:d=%.3f:curve=tri" % xf)
        fades.append("afade=t=out:st=%.3f:d=%.3f:curve=tri" % (max(0.0, dur - xf), min(xf, dur)))
        out = os.path.join(outdir, "%s_%d.mp3" % (name, k))
        subprocess.check_call(["ffmpeg", "-y", "-loglevel", "error", "-ss", "%.3f" % start, "-t", "%.3f" % dur, "-i", src,
                               "-vn", "-map_metadata", "-1", "-af", ",".join(fades), "-ac", str(channels), "-ar", "44100",
                               "-codec:a", "libmp3lame", "-b:a", bitrate, "-write_xing", "0", "-id3v2_version", "0", out])
    return parts


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    sounds = os.path.join(here, "..", "AZSGW2UI", "Sounds")
    # python3 make_sounds.py split <song.mp3> <name> [out folder]  : cut a song of your own into pieces
    if len(sys.argv) >= 4 and sys.argv[1] == "split":
        outdir = sys.argv[4] if len(sys.argv) > 4 else sounds
        parts = split_song(sys.argv[2], outdir, sys.argv[3])
        print("%d pieces in %s; in the game: /gw2 party song %s %d" % (parts, outdir, sys.argv[3], parts))
        return
    # python3 make_sounds.py [out folder]  : the song that comes with the addon, in pieces
    outdir = sys.argv[1] if len(sys.argv) > 1 else sounds
    x = build()
    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with tempfile.TemporaryDirectory() as tmp:
        raw = os.path.join(tmp, "song.raw")
        wav = os.path.join(tmp, "song.wav")
        with open(raw, "wb") as f:
            f.write(pcm.tobytes())
        subprocess.check_call(["ffmpeg", "-y", "-loglevel", "error", "-f", "s16le", "-ar", str(SR), "-ac", "1", "-i", raw, wav])
        parts = split_song(wav, outdir, "party", bitrate="112k", channels=1)
    print("wrote %d pieces (%.0f s) to %s" % (parts, len(x) / SR, outdir))


if __name__ == "__main__":
    main()
