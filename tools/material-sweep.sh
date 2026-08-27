#!/bin/bash
# Which NSVisualEffectView material best matches `backdrop-filter: blur(24px)`?
# Runs the on-screen stage once per configuration and diffs both panels.
R=/Users/hlin/klick; D=/Users/hlin/.claude/skills/cloning-apps/scripts/diff-ui.py
APP="$R/app/build/Klack.app/Contents/MacOS/Klack"
cd "$R"
crop() {  # capture -> crop both panels
  python3 - "$1" <<'PY'
import math,sys
from PIL import Image
im=Image.open('shots/onscreen-raw.png'); r=lambda v: math.floor(v+0.5)
for n,(x,y,w,h) in {'pop':(900,200,288,370.5),'sw':(32,196.5,328,551)}.items():
    im.crop((r(x)*2,r(y)*2,(r(x)+r(w))*2,(r(y)+r(h))*2)).save(f'shots/ms-{n}-{sys.argv[1]}.png')
PY
}
printf '%-24s %-6s %10s %10s\n' material appear popover switches
for m in "$@"; do
  for ap in light dark; do
    "$APP" --stage-onscreen 6 --material "$m" --appearance "$ap" >/dev/null 2>&1 &
    python3 -c "import time; time.sleep(3.0)"
    screencapture -x -o "$R/shots/onscreen-raw.png"
    crop "$m-$ap"
    wait
    p=$(python3 "$D" shots/ref-pop.png "shots/ms-pop-$m-$ap.png" --threshold 6 | grep differing | sed 's/.*: //;s/ .*//')
    w=$(python3 "$D" shots/ref-sw.png  "shots/ms-sw-$m-$ap.png"  --threshold 6 | grep differing | sed 's/.*: //;s/ .*//')
    printf '%-24s %-6s %10s %10s\n' "$m" "$ap" "$p" "$w"
  done
done
