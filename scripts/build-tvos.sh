#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${1:-Debug}"
DERIVED_DATA_PATH="$ROOT_DIR/.build/xcode"
PROJECT_PATH="$ROOT_DIR/freya-player.xcodeproj"
SCHEME="freya-player"
APP_NAME="freya-player.app"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION-appletvsimulator/$APP_NAME"
ROOT_APP_PATH="$ROOT_DIR/$APP_NAME"

if [[ "$CONFIGURATION" != "Debug" && "$CONFIGURATION" != "Release" ]]; then
  echo "Usage: $0 [Debug|Release]"
  exit 1
fi

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "xcodebuild is unavailable. Install Xcode and select it."
  exit 1
fi

echo "Building $SCHEME ($CONFIGURATION) for tvOS Simulator..."
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "generic/platform=tvOS Simulator" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build

if [[ ! -d "$APP_PATH" ]]; then
  echo "Build succeeded but app not found at: $APP_PATH"
  exit 1
fi

rm -rf "$ROOT_APP_PATH"
rsync -a "$APP_PATH/" "$ROOT_APP_PATH/"

echo "Built app: $APP_PATH"
echo "Published app: $ROOT_APP_PATH"
