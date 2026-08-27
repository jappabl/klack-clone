#!/usr/bin/env python3
"""For each text run: the shift that best aligns clone to reference, and the
residual left at that shift. A non-zero best shift is a bug I can fix; a
zero shift with residual left is rasteriser difference."""
import sys, numpy as np
from PIL import Image
import os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def load(p): return np.asarray(Image.open(p).convert('L'), dtype=float)

def fit(ref, clo, box, name, rng=4):
    x0,y0,x1,y1 = box
    a = ref[y0:y1, x0:x1]
    best=None
    for dy in range(-rng, rng+1):
        for dx in range(-rng, rng+1):
            b = clo[y0+dy:y1+dy, x0+dx:x1+dx]
            if b.shape != a.shape: continue
            e = np.abs(a-b).mean()
            if best is None or e < best[0]: best=(e,dx,dy)
    e0 = np.abs(a - clo[y0:y1, x0:x1]).mean()
    pct0 = (np.abs(a - clo[y0:y1, x0:x1])>6).mean()*100
    e,dx,dy = best
    bb = clo[y0+dy:y1+dy, x0+dx:x1+dx]
    pctb = (np.abs(a-bb)>6).mean()*100
    flag = '   <-- SHIFTED' if (dx,dy)!=(0,0) else ''
    print(f'  {name:22s} at 0,0: mean|d|={e0:5.2f} diff={pct0:5.1f}%   best dx={dx:+d} dy={dy:+d}: mean|d|={e:5.2f} diff={pctb:5.1f}%{flag}')

if __name__=='__main__':
    which = sys.argv[1]
    ref = load(f'{ROOT}/shots/ref-{which}.png')
    clo = load(f'{ROOT}/shots/clone/clone-{which}.png')
    def B(x,y,w,h): return (int(x*2),int(y*2),int((x+w)*2),int((y+h)*2))
    if which=='pop':
        runs=[('"Klack"',B(24,17,50,22.5)),('"Sound"',B(24,60.5,50,20)),
              ('"Switches"',B(24,127.5,70,20)),('"Version 2.2"',B(24,262.5,80,20)),
              ('"Klack Settings..."',B(24,288.5,120,22.5)),('"Quit Klack"',B(24,332,80,22.5)),
              ('toggle',B(218,15,50,25)),('slider thumb',B(170,84,40,20)),
              ('slider fill end',B(180,90,30,8))]
    else:
        runs=[('"CherryMX"',B(24,24,80,20)),('"Japanese Black"',B(50,38.75,110,22.5)),
              ('"Crystal Purple"',B(50,113.75,100,22.5)),('"Super Red"',B(50,376.75,75,22.5)),
              ('"New" badge',B(128,374,40,20)),('swatch 1',B(24,41,18,18)),
              ('play btn 1',B(280,38,24,24)),('ellipsis',B(140,498,50,28))]
    print(f'[{which}]')
    for n,b in runs: fit(ref,clo,b,n)
