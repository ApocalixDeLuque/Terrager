#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Terrager"
BUILD_DIR="$ROOT_DIR/.build"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"

rm -rf "$BUILD_DIR" "$DIST_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$ICONSET_DIR"

swiftc -parse-as-library \
  "$ROOT_DIR/Sources/Terrager/Terrager.swift" \
  -o "$MACOS_DIR/$APP_NAME" \
  -framework SwiftUI \
  -framework AppKit \
  -framework UniformTypeIdentifiers

cp "$ROOT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/Resources/terrager.png" "$RESOURCES_DIR/terrager.png"

for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$ROOT_DIR/Resources/terrager.png" --out "$ICONSET_DIR/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" "$ROOT_DIR/Resources/terrager.png" --out "$ICONSET_DIR/icon_${size}x${size}@2x.png" >/dev/null
done

iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"
codesign --force --deep --sign - "$APP_DIR"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$APP_DIR" \
  -ov \
  -format UDZO \
  "$DIST_DIR/$APP_NAME.dmg" >/dev/null

echo "$APP_DIR"
echo "$DIST_DIR/$APP_NAME.dmg"
