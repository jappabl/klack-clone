#!/usr/bin/env python3
"""Ink extents of a text run: top/bottom rows and vertical centroid, in device px.
Compares reference vs clone so the baseline model can be calibrated, not guessed."""
import sys, numpy as np
from PIL import Image
import os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
def load(p): return np.asarray(Image.open(p).convert('L'), dtype=float)
def ink(img, box, dark=True):
    x0,y0,x1,y1=box
    a=img[y0:y1,x0:x1]
    bg=np.median(a)
    d=(bg-a) if dark else (a-bg)
    d=np.clip(d,0,None)
    rows=d.sum(axis=1)
    thr=rows.max()*0.06
    idx=np.where(rows>thr)[0]
    if len(idx)==0: return None
    cen=(rows*np.arange(len(rows))).sum()/rows.sum()
    return y0+idx[0], y0+idx[-1], y0+cen
def main(which, runs):
    ref=load(f'{ROOT}/shots/ref-{which}.png')
    clo=load(f'{ROOT}/shots/clone/clone-{which}.png')
    print(f'[{which}]  (device px; 2 device px = 1 logical px)')
    print(f'  {"run":22s} {"ref top/bot/centroid":>28s} {"clone top/bot/centroid":>28s}   dCentroid')
    for name,box,lt,fs in runs:
        r=ink(ref,box); c=ink(clo,box)
        if not r or not c: print(f'  {name:22s} (no ink)'); continue
        print(f'  {name:22s} {r[0]:8d}{r[1]:6d}{r[2]:10.2f} {c[0]:12d}{c[1]:6d}{c[2]:10.2f}   {c[2]-r[2]:+7.2f}   [fs={fs} lineTop={lt}]')
if __name__=='__main__':
    def B(x,y,w,h): return (int(x*2),int(y*2),int((x+w)*2),int((y+h)*2))
    if sys.argv[1]=='pop':
        main('pop',[('"Klack" 15/700',B(24,14,50,28),17,15),
                    ('"Sound" 14/600',B(24,57,50,26),60.5,14),
                    ('"Switches" 14/600',B(24,124,70,26),127.5,14),
                    ('"Version" 14/600',B(24,259,60,26),262.5,14),
                    ('"Klack Set..." 15/500',B(24,285,120,28),288.5,15),
                    ('"Quit Klack" 15/500',B(24,329,80,28),332,15)])
    else:
        main('sw',[('"CherryMX" 14/600',B(24,21,80,26),24,14),
                   ('"Japanese Bl" 15/500',B(50,36,110,28),38.75,15),
                   ('"Everglide" 14/600',B(24,71,70,26),74,14),
                   ('"Crystal P" 15/500',B(50,111,100,28),113.75,15),
                   ('"Cream" 15/500',B(50,449,60,28),451.75,15)])
