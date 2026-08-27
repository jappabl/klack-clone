#!/bin/bash
# Build and install the Klack clone into /Applications.
#
# From a clone:   ./install.sh
# Without one:    curl -fsSL <raw-url>/install.sh | bash
set -euo pipefail

REPO_URL="https://github.com/jappabl/klack-clone.git"
say()  { printf '\033[1m%s\033[0m\n' "$*"; }
warn() { printf '\033[33m%s\033[0m\n' "$*"; }
die()  { printf '\033[31m%s\033[0m\n' "$*" >&2; exit 1; }

# --- preflight -------------------------------------------------------------
[ "$(uname -s)" = "Darwin" ] || die "This is a macOS app."
OSV=$(sw_vers -productVersion); OSMAJ=${OSV%%.*}
[ "$OSMAJ" -ge 15 ] || die "Needs macOS 15 or later (found $OSV)."

# --- locate sources --------------------------------------------------------
SRC="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if [ ! -f "$SRC/app/build.sh" ]; then
  # piped from curl: no working tree around us, so fetch one
  command -v git >/dev/null || die "git not found."
  SRC="$(mktemp -d)/klack-clone"
  say "Cloning into $SRC"
  git clone --depth 1 "$REPO_URL" "$SRC"
fi

# --- build -----------------------------------------------------------------
if ! xcrun --sdk macosx --show-sdk-path >/dev/null 2>&1; then
  die "Xcode Command Line Tools are missing. Install them, then re-run:

    xcode-select --install"
fi

say "Building (universal, ~1 min)…"
LOG="$(mktemp)"
if ! "$SRC/app/build.sh" >"$LOG" 2>&1; then
  cat "$LOG" >&2
  die "Build failed."
fi
rm -f "$LOG"

APP="$SRC/app/build/Klack.app"
[ -d "$APP" ] || die "Build produced no app bundle."

# --- install ---------------------------------------------------------------
DEST=/Applications
[ -w "$DEST" ] || { DEST="$HOME/Applications"; mkdir -p "$DEST"; }

# A running copy holds its bundle open; replacing it underneath is what makes
# an install appear to succeed and then launch the old build.
pkill -x Klack 2>/dev/null || true
sleep 1
rm -rf "$DEST/Klack.app"
cp -R "$APP" "$DEST/Klack.app"

# Unsigned and unnotarized, so Gatekeeper would otherwise refuse it. Nothing
# here came over the network unless you piped this script in, but strip the
# attribute either way so the first launch is not a dialog.
xattr -dr com.apple.quarantine "$DEST/Klack.app" 2>/dev/null || true

say "Installed to $DEST/Klack.app"

# --- permissions -----------------------------------------------------------
echo
if "$DEST/Klack.app/Contents/MacOS/Klack" --settings-dump >/dev/null 2>&1; then :; fi
warn "System-wide sound needs Input Monitoring."
cat <<'TXT'
  Without it the app still makes sound, but only while one of its own windows
  is focused. It never prompts on its own — grant it here:

    System Settings > Privacy & Security > Input Monitoring > + > Klack

  Input Monitoring, not Accessibility: a listen-only keyboard tap is gated by
  kTCCServiceListenEvent. Accessibility also permits one, so either works, but
  Input Monitoring is the one to reach for.

  If you have installed over a previous copy, REMOVE the old Klack entry with
  the minus button before adding it again. macOS pins the grant to the app's
  code hash, so an entry left over from an earlier build will not match this
  one, and toggling it on does nothing.

TXT
if [ -t 0 ]; then
  read -r -p "Open that pane now? [y/N] " a
  case "$a" in
    [yY]*) open "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent" ;;
  esac
fi
echo "Check it worked at any time with:  open -a Klack --args --tap-test"

echo
say "Run it:"
echo "  open -a Klack                 # menu bar"
echo "  open -a Klack --args --settings   # settings window"
