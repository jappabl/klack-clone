#!/bin/bash
# Re-render the clone and diff every surface + state against the reference.
R=/Users/hlin/klick
D=/Users/hlin/.claude/skills/cloning-apps/scripts/diff-ui.py
cd "$R"
"$R/app/build/Klack.app/Contents/MacOS/Klack" --verify "$R/shots/clone" --backdrop --states >/dev/null 2>&1
echo "=== floor: same window rendered twice ==="
for n in pop sw; do printf '%-8s ' "$n"; python3 "$D" "$R/shots/clone/clone-$n.png" "$R/shots/clone/clone-$n-floor.png" -t 6 2>/dev/null | grep differing || python3 "$D" "$R/shots/clone/clone-$n.png" "$R/shots/clone/clone-$n-floor.png" --threshold 6 | grep differing; done
echo
echo "=== clone vs reference — rest ==="
for n in pop sw pop-sh sw-sh; do printf '%-8s ' "$n"; python3 "$D" "$R/shots/ref-$n.png" "$R/shots/clone/clone-$n.png" --threshold 6 | grep -E "differing|verdict" | tr '\n' ' '; echo; done
echo
echo "=== clone vs reference — states ==="
for pair in "pop-hover-settings:pop:hover-settings" "pop-hover-quit:pop:hover-quit" "sw-hover-row:sw:hover-row"; do
  IFS=: read refn cn tag <<< "$pair"
  printf '%-20s ' "$refn"
  python3 "$D" "$R/shots/ref-$refn.png" "$R/shots/clone/clone-$cn-$tag.png" --threshold 6 | grep -E "differing|verdict" | tr '\n' ' '; echo
done

echo
echo "=== clone vs reference — sourced states ==="
for pair in "pop-toggle-off:pop:toggle-off" "pop-focus:pop:focus-toggle"; do
  IFS=: read refn cn tag <<< "$pair"
  printf '%-20s ' "$refn"
  python3 "$D" "$R/shots/ref-$refn.png" "$R/shots/clone/clone-$cn-$tag.png" --threshold 6 | grep -E "differing|verdict" | tr '\n' ' '; echo
done
