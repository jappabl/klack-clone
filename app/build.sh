#!/bin/bash
set -e
cd "$(dirname "$0")"
SDK=$(xcrun --sdk macosx --show-sdk-path)
APP=build/Klack.app
rm -rf build && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
# Universal, so one download runs on both Apple Silicon and Intel. swiftc
# emits a single slice per invocation, so build twice and lipo them together.
ARCHS="${ARCHS:-arm64 x86_64}"
SLICES=""
for A in $ARCHS; do
  swiftc -O -sdk "$SDK" -target "$A-apple-macos15.0" \
    Sources/*.swift -o "build/Klack-$A"
  SLICES="$SLICES build/Klack-$A"
done
if [ "$(echo $ARCHS | wc -w)" -gt 1 ]; then
  lipo -create $SLICES -output "$APP/Contents/MacOS/Klack"
  rm -f $SLICES
else
  mv $SLICES "$APP/Contents/MacOS/Klack"
fi
cp ../assets/wallpaper.jpg "$APP/Contents/Resources/" 2>/dev/null || true
cp -R ../assets/switches "$APP/Contents/Resources/" 2>/dev/null || true
cp ../assets/logo/Klack.icns "$APP/Contents/Resources/" 2>/dev/null || true
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Klack</string>
  <key>CFBundleIdentifier</key><string>com.clone.klack</string>
  <key>CFBundleExecutable</key><string>Klack</string>
  <key>CFBundleIconFile</key><string>Klack</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>2.2</string>
  <key>LSMinimumSystemVersion</key><string>15.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
# Sign with a real identity when one exists, ad-hoc otherwise.
#
# This is not cosmetic. macOS pins a TCC grant (Input Monitoring, in this
# app's case) to a code signing requirement. Ad-hoc and unsigned bundles get a
# requirement pinned to the code hash, so every rebuild silently invalidates
# the grant and the app goes deaf until the entry is removed and re-added.
# Signing with a certificate pins it to the identifier plus the certificate
# instead, and the grant survives rebuilds. See tools/setup-signing.sh.
ID="Klack Local Signing"
if security find-identity -v -p codesigning 2>/dev/null | grep -q "$ID"; then
  codesign --force --sign "$ID" --identifier com.clone.klack "$APP"
  echo "signed with: $ID"
else
  codesign --force --sign - --identifier com.clone.klack "$APP" 2>/dev/null || true
  echo "signed ad-hoc — Input Monitoring will need re-granting after each rebuild"
  echo "  (run tools/setup-signing.sh once to stop that)"
fi

echo "built $APP"
