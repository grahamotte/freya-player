#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/FreyaPlayer.xcodeproj"
IPAD_DERIVED_DATA_PATH="$ROOT_DIR/.build/tests-ipad"
TV_DERIVED_DATA_PATH="$ROOT_DIR/.build/tests-tv"

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

IPAD_ID="$(find_simulator_id "iPad" "iPad")"
TV_ID="$(find_simulator_id "Apple TV" "Apple TV")"

echo "Running iPad tests..."
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "freya-player-ipad" \
  -destination "id=$IPAD_ID" \
  -derivedDataPath "$IPAD_DERIVED_DATA_PATH" \
  -only-testing:"freya-player-ipadTests" \
  test

echo "Running tvOS tests..."
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "freya-player" \
  -destination "id=$TV_ID" \
  -derivedDataPath "$TV_DERIVED_DATA_PATH" \
  -only-testing:"freya-player-tvTests" \
  test
