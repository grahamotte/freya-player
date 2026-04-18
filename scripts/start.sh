#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TV_APP_PATH="$ROOT_DIR/freya-player-tvos.app"
IPAD_APP_PATH="$ROOT_DIR/freya-player-ipad.app"

device_udid() {
  local state="$1"
  local pattern="$2"

  xcrun simctl list devices "$state" 2>/dev/null | awk -v pattern="$pattern" '$0 ~ pattern { if (match($0, /[0-9A-F-]{36}/)) { print substr($0, RSTART, RLENGTH); exit } }'
}

find_simulator_id() {
  local pattern="$1"
  local label="$2"
  local simulator_id

  simulator_id="$(device_udid booted "$pattern")"
  if [[ -z "$simulator_id" ]]; then
    simulator_id="$(device_udid available "$pattern")"
  fi

  if [[ -z "$simulator_id" ]]; then
    echo "Could not find an available $label simulator."
    exit 1
  fi

  printf '%s\n' "$simulator_id"
}

open_simulator() {
  local simulator_id="$1"
  local open_flag="${2:-}"

  if [[ -n "$open_flag" ]]; then
    open "$open_flag" -a Simulator --args -CurrentDeviceUDID "$simulator_id"
  else
    open -a Simulator --args -CurrentDeviceUDID "$simulator_id"
  fi
}

launch_on_simulator() {
  local label="$1"
  local simulator_id="$2"
  local app_path="$3"
  local open_flag="${4:-}"
  local bundle_id

  bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_path/Info.plist")"

  echo "Opening $label simulator..."
  open_simulator "$simulator_id" "$open_flag"

  echo "Booting $label simulator..."
  xcrun simctl boot "$simulator_id" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$simulator_id" -b

  echo "Stopping running $label app instance (if any)..."
  xcrun simctl terminate "$simulator_id" "$bundle_id" >/dev/null 2>&1 || true

  echo "Installing $label app..."
  xcrun simctl install "$simulator_id" "$app_path"

  echo "Launching $label app..."
  xcrun simctl launch "$simulator_id" "$bundle_id"
}

echo "Building fresh app..."
"$ROOT_DIR/scripts/build-tvos.sh"
"$ROOT_DIR/scripts/build-ipad.sh"

if [[ ! -d "$TV_APP_PATH" ]]; then
  echo "Missing built app at: $TV_APP_PATH"
  exit 1
fi

if [[ ! -d "$IPAD_APP_PATH" ]]; then
  echo "Missing built app at: $IPAD_APP_PATH"
  exit 1
fi

APPLE_TV_ID="$(find_simulator_id "Apple TV" "Apple TV")"
IPAD_ID="$(find_simulator_id "iPad" "iPad")"

launch_on_simulator "Apple TV" "$APPLE_TV_ID" "$TV_APP_PATH"
launch_on_simulator "iPad" "$IPAD_ID" "$IPAD_APP_PATH" "-n"
