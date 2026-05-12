#!/usr/bin/env bash
set -euo pipefail

APP_NAME="PhysicsDiagramStudio"
DISPLAY_NAME="Physics Diagram Studio"
BUNDLE_ID="${BUNDLE_ID:-com.jay.PhysicsDiagramStudio}"
MIN_SYSTEM_VERSION="14.0"
VERSION="${1:-$(git -C "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" describe --tags --abbrev=0 2>/dev/null || echo "local")}"
VERSION_NUMBER="${VERSION#v}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
APP_ICON="$ROOT_DIR/Assets/AppIcon.icns"
STAGING_DIR="$DIST_DIR/dmg-staging"
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"

swift build --package-path "$ROOT_DIR" -c release
BUILD_BINARY="$(swift build --package-path "$ROOT_DIR" -c release --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE" "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"
if [[ -f "$APP_ICON" ]]; then
  cp "$APP_ICON" "$APP_RESOURCES/AppIcon.icns"
fi

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$DISPLAY_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$DISPLAY_NAME</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION_NUMBER</string>
  <key>CFBundleVersion</key>
  <string>$VERSION_NUMBER</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

history_files="$(find "$APP_BUNDLE" \( -name index.json -o -path "*/Diagrams/*" -o -path "*/Logs/*" \) -print)"
if [[ -n "$history_files" ]]; then
  echo "Refusing to package app bundle with local history or logs:" >&2
  echo "$history_files" >&2
  exit 1
fi

codesign --force --deep --sign - "$APP_BUNDLE"

mkdir -p "$STAGING_DIR"
cp -R "$APP_BUNDLE" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"
hdiutil create \
  -volname "$DISPLAY_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "$DMG_PATH"
