#!/usr/bin/env python3
"""Split the residual into text-rasterisation vs everything else.

The text mask comes from the clone rendered with and without glyphs, so it is
exact rather than a guessed bounding box. Dilated by `--pad` device px to cover
antialiasing spill.
"""
import sys, numpy as np
from PIL import Image, ImageFilter

def load(p): return np.asarray(Image.open(p).convert('RGB'), dtype=np.int16)

def main(ref_p, clone_p, notext_p, thr=6, pad=2, label=''):
    ref, clo, nt = load(ref_p), load(clone_p), load(notext_p)
    h = min(ref.shape[0], clo.shape[0], nt.shape[0])
    w = min(ref.shape[1], clo.shape[1], nt.shape[1])
    ref, clo, nt = ref[:h,:w], clo[:h,:w], nt[:h,:w]
    diff = np.abs(ref - clo).max(axis=2) > thr
    textmask = np.abs(clo - nt).max(axis=2) > 0
    if pad:
        m = Image.fromarray((textmask*255).astype(np.uint8))
        m = m.filter(ImageFilter.MaxFilter(2*pad+1))
        textmask = np.asarray(m) > 0
    total = diff.sum()
    inside = (diff & textmask).sum()
    outside = total - inside
    n = h*w
    print(f'{label}')
    print(f'  differing         : {100*total/n:.2f}%  ({total} of {n}, threshold {thr})')
    if total:
        print(f'  inside text mask  : {100*inside/n:.2f}% of image   ({100*inside/total:.1f}% of the residual)')
        print(f'  outside text mask : {100*outside/n:.2f}% of image   ({100*outside/total:.1f}% of the residual)')
    # worst non-text blocks -> the actual work list
    if outside:
        nb = diff & ~textmask
        bs = 16
        blocks = []
        for y in range(0, h-bs+1, bs):
            for x in range(0, w-bs+1, bs):
                c = nb[y:y+bs, x:x+bs].sum()
                if c: blocks.append((c, x, y))
        blocks.sort(reverse=True)
        print('  worst NON-TEXT 16px blocks (device px; /2 = logical):')
        for c, x, y in blocks[:10]:
            print(f'    ({x:4d},{y:4d})  {c:3d}   logical ({x//2:4d},{y//2:4d})')

if __name__ == '__main__':
    a = sys.argv[1:]
    thr = 6
    if '--threshold' in a:
        i = a.index('--threshold'); thr = int(a[i+1]); a = a[:i]+a[i+2:]
    main(a[0], a[1], a[2], thr=thr, label=a[3] if len(a) > 3 else '')
