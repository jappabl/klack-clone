#!/bin/bash
R=/Users/hlin/klick; D=/Users/hlin/.claude/skills/cloning-apps/scripts/diff-ui.py
cd "$R"
d(){ python3 "$D" "$1" "$2" --threshold "${3:-6}" | grep -E "differing pixels" | sed 's/.*: //'; }
echo "########## FLOORS ##########"
printf 'reference reproducibility (Chrome twice)   pop %s\n' "$(d shots/ref-pop.png shots/ref-pop-rest2.png)"
printf 'reference reproducibility (Chrome twice)   sw  %s\n' "$(d shots/ref-sw.png shots/ref-sw-rest2.png)"
printf 'clone reproducibility (window twice)       pop %s\n' "$(d shots/clone/clone-pop.png shots/clone/clone-pop-floor.png)"
printf 'clone reproducibility (window twice)       sw  %s\n' "$(d shots/clone/clone-sw.png shots/clone/clone-sw-floor.png)"
printf 'glyph raster floor (same font/size/pos)        %s\n' "$(d shots/glyphfloor-chrome.png shots/glyphfloor-clone.png)"
printf 'vector raster floor (same shapes/geometry)     %s\n' "$(d shots/vectorfloor-chrome.png shots/vectorfloor-clone.png)"
echo
echo "########## SURFACES @2x (primary) ##########"
for n in pop sw pop-sh sw-sh; do printf '%-8s %s\n' "$n" "$(d shots/ref-$n.png shots/clone/clone-$n.png)"; done
echo
echo "########## SURFACES @1x ##########"
for n in pop sw; do printf '%-8s %s\n' "$n" "$(d shots/ref1x-$n.png shots/clone/clone-$n-s1.png)"; done
echo
echo "########## STATES @2x ##########"
printf '%-24s %s\n' 'hover Klack Settings…' "$(d shots/ref-pop-hover-settings.png shots/clone/clone-pop-hover-settings.png)"
printf '%-24s %s\n' 'hover Quit Klack'      "$(d shots/ref-pop-hover-quit.png shots/clone/clone-pop-hover-quit.png)"
printf '%-24s %s\n' 'hover switch row'      "$(d shots/ref-sw-hover-row.png shots/clone/clone-sw-hover-row.png)"
printf '%-24s %s\n' 'toggle off'            "$(d shots/ref-pop-toggle-off.png shots/clone/clone-pop-toggle-off.png)"
printf '%-24s %s\n' 'focus-visible ring'    "$(d shots/ref-pop-focus.png shots/clone/clone-pop-focus-toggle.png)"
printf '%-24s %s\n' 'slider thumb press'    "$(d shots/ref-pop-thumb-press.png shots/clone/clone-pop-thumb-press.png)"
printf '%-24s %s\n' 'slider at 40%%'         "$(d shots/ref-pop-vol40.png shots/clone/clone-pop-vol40.png)"
printf '%-24s %s\n' 'switch row playing'    "$(d shots/ref-sw-playing.png shots/clone/clone-sw-playing.png)"
echo
echo "########## RESIDUAL SPLIT ##########"
for n in pop sw; do python3 tools/residual.py shots/ref-$n.png shots/clone/clone-$n.png shots/clone/clone-$n-notext.png "[$n @2x]" 2>/dev/null | head -4; done
for n in pop sw; do python3 tools/residual.py shots/ref1x-$n.png shots/clone/clone-$n-s1.png shots/clone/clone-$n-s1-notext.png "[$n @1x]" 2>/dev/null | head -4; done
