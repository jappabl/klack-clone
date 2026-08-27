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
echo "built $APP"
