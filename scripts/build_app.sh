#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${1:-debug}"
PRODUCT_DIR="$ROOT_DIR/build"
APP_NAME="App Monitor"
APP_DIR="$PRODUCT_DIR/$APP_NAME.app"
BINARY_NAME="AppMonitor"

cd "$ROOT_DIR"
swift build -c "$CONFIGURATION"

BUILD_BIN_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"
BUILT_BINARY="$BUILD_BIN_DIR/$BINARY_NAME"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BUILT_BINARY" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "$ROOT_DIR/Sources/AppMonitor/Resources/AppMonitorIcon.icns" "$APP_DIR/Contents/Resources/AppMonitorIcon.icns"
cp "$ROOT_DIR/Sources/AppMonitor/Resources/AppMonitorAppIcon.png" "$APP_DIR/Contents/Resources/AppMonitorAppIcon.png"
cp "$ROOT_DIR/Sources/AppMonitor/Resources/AppMonitorLogo.png" "$APP_DIR/Contents/Resources/AppMonitorLogo.png"

while IFS= read -r resource_bundle; do
  cp -R "$resource_bundle" "$APP_DIR/Contents/Resources/"
done < <(find "$BUILD_BIN_DIR" -maxdepth 1 -type d -name "*.bundle" -print)

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>App Monitor</string>
  <key>CFBundleIconFile</key>
  <string>AppMonitorIcon</string>
  <key>CFBundleIdentifier</key>
  <string>com.jacob.appmonitor</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>App Monitor</string>
  <key>CFBundleDisplayName</key>
  <string>App Monitor</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.utilities</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHumanReadableCopyright</key>
  <string>Copyright © 2026 Jacob Crandall</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP_DIR" >/dev/null
echo "$APP_DIR"
