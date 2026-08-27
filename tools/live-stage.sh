#!/bin/bash
# Put the reference composition on screen, float the real panels over it, capture, diff.
R="$(cd "$(dirname "$0")/.." && pwd)"; D="${DIFF_UI:-$HOME/.claude/skills/cloning-apps/scripts/diff-ui.py}"
APP="$R/app/build/Klack.app/Contents/MacOS/Klack"
cd "$R"
EXTRA="$@"
( "$APP" --stage-onscreen 22 $EXTRA > /tmp/live-stage.log 2>&1 & )
python3 -c "import time; time.sleep(5)"
screencapture -x -o "$R/shots/onscreen-raw.png"
python3 - <<'PY'
import math, io
from PIL import Image, ImageCms
im = Image.open(os.environ['R']+'/shots/onscreen-raw.png')
# screencapture writes the *display* profile (Display P3 here). PIL ignores the
# profile and hands back raw values, which is exactly the sRGB-vs-P3 shift that
# made the teal read (87,185,168) instead of (0,187,167). Convert properly.
icc = im.info.get('icc_profile')
if icc:
    src = ImageCms.ImageCmsProfile(io.BytesIO(icc))
    dst = ImageCms.createProfile('sRGB')
    im = ImageCms.profileToProfile(im.convert('RGB'), src, dst, outputMode='RGB')
    print('converted capture from embedded profile -> sRGB')
else:
    im = im.convert('RGB'); print('capture had no embedded profile')
r = lambda v: math.floor(v + 0.5)
for n,(x,y,w,h) in {'pop':(900,200,288,370.5),'sw':(32,196.5,328,551)}.items():
    im.crop((r(x)*2,r(y)*2,(r(x)+r(w))*2,(r(y)+r(h))*2)).save(fos.environ['R']+'/shots/live-{n}.png')
PY
tail -3 /tmp/live-stage.log
for n in pop sw; do
  printf '%-6s ' "$n"
  python3 "$D" "$R/shots/ref-$n.png" "$R/shots/live-$n.png" --threshold 6 | grep -E "differing|mean delta" | tr '\n' ' '; echo
done
