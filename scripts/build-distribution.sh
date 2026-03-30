#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_PATH="$ROOT_DIR/.build/xcode-dist"
PROJECT_PATH="$ROOT_DIR/FreyaPlayer.xcodeproj"
DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/Release-appletvos/FreyaPlayer.app"
DIST_APP_PATH="$DIST_DIR/FreyaPlayer.app"

echo "Building FreyaPlayer (Release) for tvOS devices..."
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme FreyaPlayer \
  -configuration Release \
  -destination "generic/platform=tvOS" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  build

if [[ ! -d "$APP_PATH" ]]; then
  echo "Build succeeded but app not found at: $APP_PATH"
  exit 1
fi

mkdir -p "$DIST_DIR"
rm -rf "$DIST_APP_PATH"
rsync -a "$APP_PATH/" "$DIST_APP_PATH/"

echo "Published device app: $DIST_APP_PATH"
echo "Note: this is an unsigned build artifact."
