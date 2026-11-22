#!/bin/bash
# Live development loop for work in Cursor, DeepSeek Harness, or any editor.
# Saves in Sources/Tests/Resources rebuild and relaunch the exact same app, so
# changes are visible in the notch without manually running make app.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
STAMP="$ROOT/build/.dev-watch-stamp"
mkdir -p "$ROOT/build"
touch "$STAMP"

build_and_launch() {
  touch "$STAMP"
  echo "Building NOTCHORA…"
  if "$ROOT/Scripts/build-app.sh"; then
    pkill -f "$ROOT/build/NOTCHORA.app/Contents/MacOS/NOTCHORA" 2>/dev/null || true
    sleep 0.4
    open -n "$ROOT/build/NOTCHORA.app"
    echo "Launched. The window stays at the notch; open it with ⌥Space."
  else
    echo "Build failed; the previous running app was left untouched." >&2
  fi
}

build_and_launch

echo "Watching Sources, Tests, Resources, and Package.swift. Press Ctrl+C to stop."
while true; do
  sleep 1
  CHANGED="$(find "$ROOT/Sources" "$ROOT/Tests" "$ROOT/Resources" "$ROOT/Package.swift" -type f -newer "$STAMP" 2>/dev/null | head -1 || true)"
  if [[ -n "$CHANGED" ]]; then
    echo "Changed: ${CHANGED#$ROOT/}"
    build_and_launch
  fi
done
