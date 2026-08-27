#!/usr/bin/env python3
"""Cut individual key-down and key-up transients out of the CC0 typing recordings.

A keystroke on a mechanical switch is two events: the down-stroke (loud) and the
release (quieter), typically 40-140 ms later. Detect onsets, pair them, window
and normalise each one, and write per-switch variant sets.
"""
import json, os, subprocess, sys, glob
import numpy as np
import wave
import os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

SR = 48000
SRC = f"{ROOT}/ref/audio"
OUT = f"{ROOT}/assets/switches"

def decode(path):
    p = subprocess.run(["ffmpeg","-v","error","-i",path,"-ac","1","-ar",str(SR),
                        "-f","f32le","-"], capture_output=True)
    return np.frombuffer(p.stdout, dtype=np.float32).copy()

def envelope(x, win=96):                     # ~2 ms RMS
    k = np.ones(win, dtype=np.float32) / win
    return np.sqrt(np.convolve(x*x, k, mode="same") + 1e-12)

def onsets(x, env, thr_mult=3.0, min_gap_ms=28):
    med = np.median(env[env > 1e-5]) if (env > 1e-5).any() else 1e-5
    thr = med * thr_mult
    gap = int(SR * min_gap_ms / 1000)
    cand = []
    i, n = 0, len(env)
    while i < n:
        if env[i] > thr:
            j = min(n, i + gap)
            pk = i + int(np.argmax(env[i:j]))
            cand.append(pk)
            i = pk + gap
        else:
            i += 1
    return cand, thr

def biquad(x, b0, b1, b2, a1, a2):
    y = np.empty_like(x)
    x1 = x2 = y1 = y2 = 0.0
    for i, v in enumerate(x):
        o = b0*v + b1*x1 + b2*x2 - a1*y1 - a2*y2
        x2, x1 = x1, v; y2, y1 = y1, o; y[i] = o
    return y

def highpass(x, f0=120.0, q=0.707):
    w = 2*np.pi*f0/SR; c, sn = np.cos(w), np.sin(w); al = sn/(2*q)
    b0 = (1+c)/2; b1 = -(1+c); b2 = (1+c)/2; a0 = 1+al; a1 = -2*c; a2 = 1-al
    return biquad(x, b0/a0, b1/a0, b2/a0, a1/a0, a2/a0)

def highshelf(x, f0=4000.0, gain_db=4.0, s_=0.8):
    A = 10**(gain_db/40); w = 2*np.pi*f0/SR; c, sn = np.cos(w), np.sin(w)
    al = sn/2*np.sqrt((A+1/A)*(1/s_-1)+2); tw = 2*np.sqrt(A)*al
    b0 =    A*((A+1)+(A-1)*c+tw)
    b1 = -2*A*((A-1)+(A+1)*c)
    b2 =    A*((A+1)+(A-1)*c-tw)
    a0 =       (A+1)-(A-1)*c+tw
    a1 =   2*((A-1)-(A+1)*c)
    a2 =       (A+1)-(A-1)*c-tw
    return biquad(x, b0/a0, b1/a0, b2/a0, a1/a0, a2/a0)

def window(x, pk, pre_ms=0.6, dur_ms=95):
    """Trim tight to the onset, filter, and fade only enough to avoid a step.

    Measured on the previous build: a 1.2 ms fade-in stretched the 10-90%
    attack to 1.34 ms, 28% of the energy sat below 150 Hz (room rumble, not
    switch), and only 9% sat above 4 kHz."""
    a = max(0, pk - int(SR*pre_ms/1000))
    b = min(len(x), a + int(SR*dur_ms/1000))
    s = x[a:b].astype(np.float32).copy()
    if len(s) < 64: return None
    s = highpass(s).astype(np.float32)          # drop the rumble
    s = highshelf(s).astype(np.float32)         # restore the top the source lost
    fi = min(max(4, int(SR*0.00015)), len(s)//4)
    fo = min(int(SR*0.010), len(s)//3)
    if fi > 0: s[:fi] *= np.linspace(0,1,fi, dtype=np.float32)
    if fo > 0: s[-fo:] *= np.linspace(1,0,fo, dtype=np.float32)
    p = np.abs(s).max()
    if p < 1e-4: return None
    return s / p * 0.92          # peak-normalised here; the set is loudness-matched below

def write_wav(path, x):
    d = (np.clip(x,-1,1) * 32767).astype("<i2").tobytes()
    with wave.open(path,"wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(d)

man = json.load(open(f"{SRC}/CREDITS.json"))
os.makedirs(OUT, exist_ok=True)
summary = []
for e in man:
    x = decode(f"{SRC}/{e['file']}")
    if x.size == 0:
        print(f"{e['switch']}: decode failed"); continue
    x = x / (np.abs(x).max() + 1e-9)
    env = envelope(x)
    pks, thr = onsets(x, env)
    # pair: a down followed 40-140 ms later by a quieter onset = its release
    downs, ups = [], []
    used = set()
    for i, p in enumerate(pks):
        if i in used: continue
        ep = env[p]
        rel = None
        for j in range(i+1, min(i+4, len(pks))):
            dt = (pks[j]-p)/SR*1000
            if 40 <= dt <= 150 and env[pks[j]] < ep*0.75:
                rel = j; break
        if rel is not None:
            downs.append((ep, p)); ups.append((env[pks[rel]], pks[rel]))
            used.add(rel)
    if len(downs) < 6:      # fall back: loudest half are downs
        pk_sorted = sorted(pks, key=lambda p: -env[p])
        downs = [(env[p], p) for p in pk_sorted[:16]]
        ups   = [(env[p], p) for p in pk_sorted[16:32]]
    # keep the cleanest, most representative takes
    downs.sort(key=lambda t: -t[0]); ups.sort(key=lambda t: -t[0])
    d = os.path.join(OUT, e["switch"].replace(" ","_"))
    os.makedirs(d, exist_ok=True)
    # Only well-isolated strokes are usable. Measured on the first pass: 16 of
    # 70 slices had a neighbouring keystroke inside the window, i.e. ~23% of the
    # library played as a double-tap. Candidates are now scored by how much
    # silence surrounds them, and any window that still contains a second onset
    # is thrown away rather than shipped.
    def gaps(pk, others):
        prev = max([o for o in others if o < pk], default=-10**9)
        nxt  = min([o for o in others if o > pk], default=10**9)
        return (pk - prev) / SR * 1000, (nxt - pk) / SR * 1000

    def clean(sl, guard_ms=20, ratio=0.40, max_peak_ms=3.0):
        """Reject a slice with a second transient after the initial one, or one
        whose transient arrives late.

        Late-peak rejection was added after a single Crystal Purple variant --
        peak 10.3 ms in, 60% of its energy ahead of it -- pulled that set's
        measured attack from ~0.4 ms to 11 ms on its own. Re-aligning slices to
        their own transient was tried first and made every set worse
        (0.61 -> 1.18 ms mean), because the walk-back runs a long way up a slow
        ramp. Dropping the offending take is the smaller, better change."""
        e = envelope(sl, 48)
        pk = int(np.argmax(e))
        if pk > SR * max_peak_ms / 1000: return False
        tail = e[pk + int(SR * guard_ms / 1000):]
        return not (len(tail) and tail.max() > e.max() * ratio)

    allpk = list(pks)
    def harvest(cands, want_ms, min_ms, before_ms, want):
        """Size each window to the silence actually available after the stroke.
        A dense recording yields short takes rather than none; the transient
        that carries the character is in the first ~15 ms either way."""
        out = []
        for _, pk in cands:
            if len(out) >= want: break
            gb, ga = gaps(pk, allpk)
            if gb < before_ms: continue
            dur = min(want_ms, max(0.0, ga - 8))
            if dur < min_ms: continue
            sl = window(x, pk, dur_ms=dur)
            if sl is None or not clean(sl): continue
            out.append(sl)
        return out

    TARGET_RMS = 0.055
    dsl = harvest(downs, 95, 48, 55, 10)
    usl = harvest(ups,   60, 38, 38, 10)
    if dsl:
        setrms = float(np.sqrt(np.mean([np.mean(a*a) for a in dsl])))
        g = min(TARGET_RMS / max(setrms, 1e-6),
                1.0 / max(max(np.abs(a).max() for a in dsl+usl), 1e-6) * 0.95)
    else:
        g = 1.0
    nd = nu = 0
    for f in glob.glob(os.path.join(d, "*.wav")): os.remove(f)
    for a in dsl: write_wav(f"{d}/down_{nd:02d}.wav", a*g); nd += 1
    for a in usl: write_wav(f"{d}/up_{nu:02d}.wav",   a*g); nu += 1
    summary.append((e["switch"], len(pks), nd, nu))
    print(f"{e['switch']:16s} onsets={len(pks):4d}  down variants={nd:2d}  up variants={nu:2d}")
print()
print("total slices:", sum(s[2]+s[3] for s in summary))
