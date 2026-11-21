#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BUILD_DIR="$ROOT/build"
APP="$BUILD_DIR/NOTCHORA.app"
CACHE="$ROOT/.build"
TMPDIR="$CACHE/tmp"
export TMPDIR
export CLANG_MODULE_CACHE_PATH="$CACHE/clangcache"
mkdir -p "$TMPDIR" "$CACHE/clangcache" "$BUILD_DIR"

SWIFT_FLAGS=(--disable-sandbox --scratch-path "$CACHE" --cache-path "$CACHE/swiftpm-cache" --config-path "$CACHE/config")
swift build -c release "${SWIFT_FLAGS[@]}" --product NOTCHORA

BIN="$CACHE/release/NOTCHORA"
if [[ ! -x "$BIN" ]]; then
  echo "Release binary not found at $BIN" >&2
  exit 1
fi

if [[ ! -f "$BUILD_DIR/AppIcon.icns" ]]; then
  echo "Generating app icon…"
  "$ROOT/Scripts/make-icon.sh"
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/NOTCHORA"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$BUILD_DIR/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# Ad-hoc signing is enough for local development and TCC attribution.
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

echo "Built: $APP"
echo "Launch: open \"$APP\""
