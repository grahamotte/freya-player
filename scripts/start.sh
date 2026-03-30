#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT_APP_PATH="$ROOT_DIR/freya-player.app"

booted_apple_tv_udid() {
  xcrun simctl list devices booted 2>/dev/null | awk '/Apple TV/ { if (match($0, /[0-9A-F-]{36}/)) { print substr($0, RSTART, RLENGTH); exit } }'
}

available_apple_tv_udid() {
  xcrun simctl list devices available 2>/dev/null | awk '/Apple TV/ && $0 !~ /unavailable/ { if (match($0, /[0-9A-F-]{36}/)) { print substr($0, RSTART, RLENGTH); exit } }'
}

echo "Building fresh app..."
"$ROOT_DIR/scripts/build-tvos.sh"

if [[ ! -d "$ROOT_APP_PATH" ]]; then
  echo "Missing built app at: $ROOT_APP_PATH"
  exit 1
fi

BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$ROOT_APP_PATH/Info.plist")"
SIMULATOR_ID="$(booted_apple_tv_udid)"

if [[ -z "$SIMULATOR_ID" ]]; then
  SIMULATOR_ID="$(available_apple_tv_udid)"
fi

if [[ -z "$SIMULATOR_ID" ]]; then
  echo "Could not find an available Apple TV simulator."
  exit 1
fi

echo "Opening simulator..."
open -a Simulator --args -CurrentDeviceUDID "$SIMULATOR_ID"

echo "Booting simulator..."
xcrun simctl boot "$SIMULATOR_ID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$SIMULATOR_ID" -b

echo "Stopping running app instance (if any)..."
xcrun simctl terminate "$SIMULATOR_ID" "$BUNDLE_ID" >/dev/null 2>&1 || true

echo "Installing app..."
xcrun simctl install "$SIMULATOR_ID" "$ROOT_APP_PATH"

echo "Launching app..."
xcrun simctl launch "$SIMULATOR_ID" "$BUNDLE_ID"
