#!/usr/bin/env python3
"""Fetch CC0 mechanical-keyboard recordings from Freesound and verify the licence.

These are recordings of *real* switches, in the public domain. They are not
Klack's sample library — that is the paid product and is not reproduced here.
The mapping onto Klack's switch names is nominal: each CC0 recording was chosen
because its character (clicky / linear / thocky) is the closest available match.
"""
import re, subprocess, sys, os, json

SOURCES = [
    # klack switch          freesound user            id       what was recorded
    ("Japanese Black",  "handygaber",      "499773", "Corsair K95, Cherry MX Red (linear)"),
    ("Crystal Purple",  "jameslovescode",  "400699", "Pok3r, Cherry MX Blue (clicky)"),
    ("Oreo",            "quasifandango",   "581070", "Glorious Panda (tactile, thocky)"),
    ("Cardboard",       "majod",           "400167", "Cherry MX Brown (tactile)"),
    ("Milky Yellow",    "bangcorrupt",     "833612", "Keychron K7 Pro, Gateron Brown"),
    # first pick (grcekh 546167, WhiteFox/Hako Violet) was swapped out: its
    # slices carried a -14.7 dB noise floor once the set was loudness-matched.
    ("Super Red",       "eclectic-kitty",  "757638", "Ducky X Varmilo, brown switches"),
    ("Cream",           "seth-m",          "269713", "Thermaltake Poseidon Z, Cherry MX Blue"),
]
OUT = "/Users/hlin/klick/ref/audio"
os.makedirs(OUT, exist_ok=True)

def get(url):
    return subprocess.run(["curl","-sL","-A","Mozilla/5.0",url],
                          capture_output=True, text=True, errors="ignore").stdout

manifest = []
for name, user, sid, what in SOURCES:
    page = get(f"https://freesound.org/people/{user}/sounds/{sid}/")
    if not page:
        print(f"  {name}: page fetch FAILED"); continue
    cc0 = "Creative Commons 0" in page
    prev = re.findall(r'https://cdn\.freesound\.org/previews/[^"\' ]+-hq\.mp3', page)
    title = re.search(r'<title>\s*(.*?)\s*</title>', page, re.S)
    title = re.sub(r'\s+', ' ', title.group(1)) if title else "?"
    print(f"{name:16s} id={sid:7s} CC0={cc0}  preview={'yes' if prev else 'NO'}  {title[:60]}")
    if not (cc0 and prev):
        print("   -> skipped: licence not verified as CC0, or no public preview")
        continue
    dst = f"{OUT}/{sid}.mp3"
    subprocess.run(["curl","-sL","-o",dst,prev[0]], check=False)
    manifest.append({"switch": name, "id": sid, "user": user, "recorded": what,
                     "licence": "CC0 1.0 (public domain)",
                     "url": f"https://freesound.org/people/{user}/sounds/{sid}/",
                     "file": os.path.basename(dst),
                     "bytes": os.path.getsize(dst) if os.path.exists(dst) else 0})
json.dump(manifest, open(f"{OUT}/CREDITS.json","w"), indent=1)
print(f"\n{len(manifest)}/{len(SOURCES)} verified CC0 and downloaded")
