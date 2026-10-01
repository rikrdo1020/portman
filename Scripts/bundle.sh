#!/usr/bin/env bash
# Builds ServicesPanel.app for macOS (arm64 or universal)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build"
APP_NAME="ServicesPanel"
APP="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP/Contents"
ARCH="${1:-arm64}"  # pass "universal" to build fat binary

echo "▸ Building $APP_NAME ($ARCH) …"
cd "$PROJECT_ROOT"

if [[ "$ARCH" == "universal" ]]; then
    swift build -c release --arch arm64 --arch x86_64
    BINARY=".build/apple/Products/Release/$APP_NAME"
else
    swift build -c release --arch arm64
    BINARY=".build/release/$APP_NAME"
fi

echo "▸ Assembling .app bundle …"
rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS"
mkdir -p "$CONTENTS/Resources"

cp "$BINARY" "$CONTENTS/MacOS/$APP_NAME"
cp "$PROJECT_ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"
cp "$PROJECT_ROOT/Resources/AppIcon.icns" "$CONTENTS/Resources/AppIcon.icns"

# Copy icons (Phosphor SVGs + menu bar PNGs)
mkdir -p "$CONTENTS/Resources/Icons"
cp "$PROJECT_ROOT/Resources/Icons/"*.svg "$CONTENTS/Resources/Icons/"
cp "$PROJECT_ROOT/Resources/Icons/"menubar-*.png "$CONTENTS/Resources/Icons/"

echo "▸ Ad-hoc code signing …"
codesign --force --sign - --options runtime "$APP"

echo ""
echo "✓ Built: $APP"
echo "  Run with: open '$APP'"
echo "  Or install: ./Scripts/install.sh"
