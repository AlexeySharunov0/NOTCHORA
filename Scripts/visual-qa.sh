#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CACHE="$ROOT/.build"
export TMPDIR="$CACHE/tmp"
export CLANG_MODULE_CACHE_PATH="$CACHE/clangcache"
mkdir -p "$TMPDIR" "$CACHE/clangcache" "$ROOT/build/screenshots/qa"

if [[ ! -f "$ROOT/build/AppIcon.icns" ]]; then
  "$ROOT/Scripts/make-icon.sh"
fi

swift build --disable-sandbox --scratch-path "$CACHE" --cache-path "$CACHE/swiftpm-cache" --config-path "$CACHE/config" --product NOTCHORA

QA_APP="$ROOT/build/NOTCHORA-QA.app"
rm -rf "$QA_APP"
mkdir -p "$QA_APP/Contents/MacOS" "$QA_APP/Contents/Resources"
cp "$CACHE/debug/NOTCHORA" "$QA_APP/Contents/MacOS/NOTCHORA"
cp "$ROOT/Resources/Info.plist" "$QA_APP/Contents/Info.plist"
cp "$ROOT/build/AppIcon.icns" "$QA_APP/Contents/Resources/AppIcon.icns"
codesign --force --deep --sign - "$QA_APP" >/dev/null 2>&1 || true

rm -rf "$ROOT/build/screenshots/qa"
mkdir -p "$ROOT/build/screenshots/qa"
NOTCHORA_QA=1 \
NOTCHORA_STATE_PATH="$ROOT/build/qa-state.json" \
NOTCHORA_QA_DIR="$ROOT/build/screenshots/qa" \
"$QA_APP/Contents/MacOS/NOTCHORA" > "$ROOT/build/qa.log" 2>&1 &
PID=$!

for _ in $(seq 1 60); do
  if ! kill -0 "$PID" 2>/dev/null; then break; fi
  sleep 1
done

if kill -0 "$PID" 2>/dev/null; then
  kill "$PID" 2>/dev/null || true
  echo "Visual QA timed out. See build/qa.log" >&2
  exit 1
fi

EXPECTED=(
  01-compact.png 01b-hover-preview.png 01c-working-hud.png 02-onboarding.png 03-chat-dark.png 04-chat-light.png
  05-workspace-dark.png 06-workspace-light.png 07-history.png 08-tasks.png
  09-workflows.png 10-multi-ai.png 11-compact-active.png
  12-settings-general.png 13-settings-providers.png 14-settings-privacy.png
  15-settings-light.png 16-expand-70ms.png 17-expand-170ms.png
  18-expand-350ms.png 19-expand-final.png 20-collapse-80ms.png
  21-collapse-200ms.png 22-collapse-400ms.png 23-collapse-final.png
  24-model-picker.png 25-handoff.png 26-system-prompt.png
  27-screen-capture.png 28-voice.png 29-workflow-editor.png
)

for file in "${EXPECTED[@]}"; do
  path="$ROOT/build/screenshots/qa/$file"
  if [[ ! -s "$path" ]]; then
    echo "Missing visual QA artifact: $path" >&2
    exit 1
  fi
done

STATUS="$ROOT/build/screenshots/qa/runtime-status.txt"
if [[ ! -s "$STATUS" ]]; then
  echo "Missing runtime status report: $STATUS" >&2
  exit 1
fi

if ! grep -q "shortcutErrors: none" "$STATUS"; then
  echo "Global shortcut registration failed:" >&2
  cat "$STATUS" >&2
  exit 1
fi

if ! grep -q "firstResponder: NSTextView" "$STATUS"; then
  echo "Composer did not receive keyboard focus:" >&2
  cat "$STATUS" >&2
  exit 1
fi

for name in 01-compact 01b-hover-preview 01c-working-hud 02-onboarding 03-chat-dark 05-workspace-dark 12-settings-general 16-expand-70ms 20-collapse-80ms 21-collapse-200ms 23-collapse-final; do
  swift "$ROOT/Scripts/validate-notch-shape.swift" "$ROOT/build/screenshots/qa/$name.png" >/dev/null
done

echo "Visual QA passed: ${#EXPECTED[@]} screenshots, centered opaque welded notch growth/collapse, shortcuts registered, composer focused"
