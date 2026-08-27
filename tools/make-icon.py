#!/usr/bin/env python3
"""Draw the app mark and build Klack.icns.

Klack's own icon is a photorealistic black keycap carrying a cream "K" on a
black plate. This mark deliberately shares none of it: an isometric frustum
with flat-shaded faces instead of a rendered front-on cap, a warm plate instead
of black, no letterform at all, and the project's measured teal as the single
accent. The palette is the clone's own — orange50 / stone800 / stone900 /
teal500, straight out of Tokens.swift.

Two decorations were tried and cut, because the mark is for a sound app and
the pull to depict sound is strong:
  - three broadcast arcs off the cap's shoulder — reads as a wifi/volume
    glyph, and at that point the keycap is just a dark square beside it;
  - a soft teal emission behind the cap — turns to a grey-teal smudge against
    the cream plate and fights it.
A keycap on its own carries the idea. Neither survived a look at the render.

Renders at 4x and downsamples; Pillow's polygon edges are not good enough to
trust at final size.

    python3 tools/make-icon.py
"""
import os
import subprocess
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

S = 4                       # supersample factor
N = 1024 * S
def s(v): return int(round(v * S))

ORANGE50 = (255, 247, 237)
PLATE_LO = (241, 224, 205)
STONE800 = (41, 37, 36)
STONE900 = (28, 25, 23)
TEAL500  = (0, 187, 167)
TEAL_LO  = (0, 156, 141)

OUT = "assets/logo"

def vgrad(box, top, bottom, r):
    y = np.linspace(0, 1, N)[:, None]
    px = np.zeros((N, N, 3), np.float32)
    for c in range(3):
        px[..., c] = top[c] * (1 - y) + bottom[c] * y
    g = Image.fromarray(px.astype(np.uint8), "RGB").convert("RGBA")
    m = Image.new("L", (N, N), 0)
    ImageDraw.Draw(m).rounded_rectangle(box, radius=r, fill=255)
    g.putalpha(m)
    return g

def poly_grad(points, top, bottom):
    """Flat shading reads as cardboard; a gradient down each face gives the
    frustum somewhere for the light to come from."""
    ys = [p[1] for p in points]
    y0, y1 = min(ys), max(ys)
    col = np.zeros((N, N, 3), np.float32)
    t = np.clip((np.arange(N) - y0) / max(y1 - y0, 1), 0, 1)[:, None]
    for c in range(3):
        col[..., c] = top[c] * (1 - t) + bottom[c] * t
    g = Image.fromarray(col.astype(np.uint8), "RGB").convert("RGBA")
    m = Image.new("L", (N, N), 0)
    ImageDraw.Draw(m).polygon(points, fill=255)
    g.putalpha(m)
    return g

def build():
    canvas = Image.new("RGBA", (N, N), (0, 0, 0, 0))

    # plate — the macOS grid is an 824/1024 rounded square, radius 185
    inset, prad = s(100), s(185)
    box = (inset, inset, N - inset, N - inset)
    canvas.alpha_composite(vgrad(box, ORANGE50, PLATE_LO, prad))
    rim = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    ImageDraw.Draw(rim).rounded_rectangle(box, radius=prad,
                                          outline=STONE800 + (26,), width=s(3))
    canvas.alpha_composite(rim)

    # keycap as a frustum: a small top rhombus over a wider base, so the sides
    # taper the way a real cap does
    cx, cy = s(512), s(438)
    w, h = s(272), s(136)          # top face half-extents (2:1 isometric)
    W, H = s(334), s(167)          # base half-extents
    d = s(118)                     # cap height

    T = (cx, cy - h); R = (cx + w, cy); B = (cx, cy + h); L = (cx - w, cy)
    Rb = (cx + W, cy + d); Bb = (cx, cy + H + d); Lb = (cx - W, cy + d)

    sh = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    ImageDraw.Draw(sh).polygon(
        [(cx, cy - H + d + s(26)), (cx + W, cy + d + s(26)),
         (cx, cy + H + d + s(26)), (cx - W, cy + d + s(26))],
        fill=STONE900 + (64,))
    canvas.alpha_composite(sh.filter(ImageFilter.GaussianBlur(s(22))))

    canvas.alpha_composite(poly_grad([L, B, Bb, Lb], STONE800, STONE900))
    canvas.alpha_composite(poly_grad([B, R, Rb, Bb], (34, 31, 30), (18, 16, 15)))
    canvas.alpha_composite(poly_grad([T, R, B, L], TEAL500, TEAL_LO))

    # dish: real caps are concave, so inset a brighter rhombus and leave a rim
    k = 0.80
    canvas.alpha_composite(poly_grad(
        [(cx, cy - h * k), (cx + w * k, cy), (cx, cy + h * k), (cx - w * k, cy)],
        (0, 205, 183), (0, 172, 155)))

    e = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    ImageDraw.Draw(e).line([L, B, R], fill=(0, 132, 119, 255), width=s(5))
    canvas.alpha_composite(e)

    return canvas.resize((1024, 1024), Image.LANCZOS)

os.makedirs(OUT, exist_ok=True)
master = build()
master.save(f"{OUT}/icon-1024.png")

# iconutil wants exactly these names
iconset = f"{OUT}/Klack.iconset"
os.makedirs(iconset, exist_ok=True)
for px in (16, 32, 128, 256, 512):
    master.resize((px, px), Image.LANCZOS).save(f"{iconset}/icon_{px}x{px}.png")
    master.resize((px * 2, px * 2), Image.LANCZOS).save(f"{iconset}/icon_{px}x{px}@2x.png")
subprocess.run(["iconutil", "-c", "icns", iconset, "-o", f"{OUT}/Klack.icns"], check=True)
print(f"wrote {OUT}/icon-1024.png and {OUT}/Klack.icns")
