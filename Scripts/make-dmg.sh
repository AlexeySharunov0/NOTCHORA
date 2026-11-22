#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP="$ROOT/build/NOTCHORA.app"
DMG="$ROOT/build/NOTCHORA-1.0.0.dmg"

if [[ ! -d "$APP" ]]; then
  "$ROOT/Scripts/build-app.sh"
fi

rm -f "$DMG"
hdiutil create \
  -volname "NOTCHORA 1.0.0" \
  -srcfolder "$APP" \
  -ov \
  -format UDZO \
  "$DMG" >/dev/null
echo "Created $DMG"
