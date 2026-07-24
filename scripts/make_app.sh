#!/bin/bash
# Builds FitBar.app from the SwiftPM package (no Xcode required).
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
APP="${FITBAR_APP_PATH:-/Applications/FitBar.app}"

echo "==> swift build -c release"
swift build -c release
BUILD="$(swift build -c release --show-bin-path)"

echo "==> rendering app icon"
ICONDIR="$(mktemp -d)"
"$BUILD/FitBar" --icon "$ICONDIR/icon-1024.png" >/dev/null
ICONSET="$ICONDIR/AppIcon.iconset"
mkdir -p "$ICONSET"
for size in 16 32 64 128 256 512; do
  sips -z $size $size "$ICONDIR/icon-1024.png" \
    --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z $double $double "$ICONDIR/icon-1024.png" \
    --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$ICONDIR/AppIcon.icns"

echo "==> assembling $APP"
osascript -e 'tell application "FitBar" to quit' 2>/dev/null || true
rm -rf "$APP"
mkdir -p "$(dirname "$APP")"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BUILD/FitBar" "$APP/Contents/MacOS/FitBar"
cp -R "$BUILD/FitBar_FitBarKit.bundle" "$APP/Contents/Resources/"
cp "$ICONDIR/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
chmod +x "$APP/Contents/MacOS/FitBar"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>              <string>FitBar</string>
    <key>CFBundleDisplayName</key>       <string>FitBar</string>
    <key>CFBundleIdentifier</key>        <string>dev.local.fitbar</string>
    <key>CFBundleVersion</key>           <string>1.0.2</string>
    <key>CFBundleShortVersionString</key><string>1.0.2</string>
    <key>CFBundleExecutable</key>        <string>FitBar</string>
    <key>CFBundleIconFile</key>          <string>AppIcon</string>
    <key>CFBundlePackageType</key>       <string>APPL</string>
    <key>LSMinimumSystemVersion</key>    <string>14.0</string>
    <key>NSHighResolutionCapable</key>   <true/>
    <key>LSApplicationCategoryType</key> <string>public.app-category.healthcare-fitness</string>
    <key>NSHumanReadableCopyright</key>  <string>Данные: ExerciseDB v1 / exercises-dataset</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP" 2>/dev/null || true
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP" 2>/dev/null || true
rm -rf "$ICONDIR"

echo "==> done: $APP"
