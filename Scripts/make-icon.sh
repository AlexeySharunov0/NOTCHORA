#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
BUILD_DIR="$ROOT/build"
ICONSET="$BUILD_DIR/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"

export TMPDIR="$ROOT/.build/tmp"
mkdir -p "$TMPDIR"
swift "$ROOT/Scripts/make-icon.swift" "$BUILD_DIR/icon-1024.png"

for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$BUILD_DIR/icon-1024.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" "$BUILD_DIR/icon-1024.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done

iconutil -c icns "$ICONSET" -o "$BUILD_DIR/AppIcon.icns"
echo "Generated $BUILD_DIR/AppIcon.icns"
