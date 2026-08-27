#!/usr/bin/env python3
"""Measure surface D the same way in the reference frame and in the clone.

The reference is a compressed video frame over an unknown desktop, so a pixel
gate does not apply. Geometry does: these are the quantities that survive
compression, in points, at each image's own scale.
"""
import sys, numpy as np
from PIL import Image
import os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def measure(path, ox, oy, scale, label):
    im = np.asarray(Image.open(path).convert('RGB'), float)
    sat = im.max(axis=2) - im.min(axis=2)
    L = im.mean(axis=2)
    def pt(px): return px / scale
    out = {}

    # sidebar icon tiles: saturated blobs in the icon column
    x0, x1 = int(ox + 14*scale), int(ox + 48*scale)
    colmask = (sat[:, x0:x1] > 45) & (L[:, x0:x1] > 55)
    rows = colmask.sum(axis=1)
    runs, start = [], None
    for i, v in enumerate(rows > 3):
        if v and start is None: start = i
        if not v and start is not None:
            if i - start > 6*scale/2: runs.append((start, i-1))
            start = None
    cent = [pt((a+b)/2 - oy) for a, b in runs]
    out['sidebar_icon_centres_pt'] = [round(c,1) for c in cent]
    if len(cent) >= 3:
        gaps = [round(cent[i+1]-cent[i],1) for i in range(len(cent)-1)]
        out['sidebar_gaps_pt'] = gaps

    # teal toggles / slider: strongly teal pixels
    r, g, b = im[...,0], im[...,1], im[...,2]
    teal = (g > 130) & (g - r > 45) & (b > 100) & (g - b > 5)
    ys, xs = np.nonzero(teal)
    if len(ys):
        # cluster by row bands
        order = np.argsort(ys); ys, xs = ys[order], xs[order]
        bands, cur = [], [0]
        for i in range(1, len(ys)):
            if ys[i] - ys[i-1] > 6*scale/2: bands.append(cur); cur = []
            cur.append(i)
        bands.append(cur)
        tb = []
        for bd in bands:
            if len(bd) < 40: continue
            yy, xx = ys[bd], xs[bd]
            tb.append((round(pt(yy.mean()-oy),1), round(pt(xx.min()-ox),1),
                       round(pt(xx.max()-ox),1), round(pt(yy.max()-yy.min()+1),1)))
        out['teal_bands_(cy,x0,x1,h)_pt'] = tb
        if len(tb) >= 3:
            out['toggle_pitch_pt'] = [round(tb[i+1][0]-tb[i][0],1) for i in range(min(2,len(tb)-1))]
            out['toggle_size_pt'] = (round(tb[0][2]-tb[0][1],1), tb[0][3])
    print(f'--- {label} (scale {scale} px/pt) ---')
    for k, v in out.items(): print(f'  {k}: {v}')
    return out

if __name__ == '__main__':
    a = measure(f'{ROOT}/ref/video/win50.png', 30, 20, 1.946, 'REFERENCE frame t=50s')
    print()
    b = measure(f'{ROOT}/shots/settings-clone.png', 0, 0, 1.946, 'CLONE render')
