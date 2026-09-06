#!/bin/sh
set -eu
PROJECT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$PROJECT_DIR"
if [ -z "${DEVELOPER_DIR:-}" ] && [ -d /Applications/Xcode-beta.app ]; then
  export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
fi
export CLANG_MODULE_CACHE_PATH="$PROJECT_DIR/.build/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PROJECT_DIR/.build/swift-cache"
PRODUCT=FocusFlow
APP_NAME='Focus & Flow'
PLIST=Info.plist
if [ "${1:-}" = '--simple' ]; then
  PRODUCT=Focus
  APP_NAME=Focus
  PLIST=SimpleFocus.plist
fi
xcrun swift build -c release --product "$PRODUCT"
BIN_DIR="$(xcrun swift build -c release --show-bin-path)"
APP_DIR="$PROJECT_DIR/dist/$APP_NAME.app"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_DIR/$PRODUCT" "$APP_DIR/Contents/MacOS/$PRODUCT"
cp "$PROJECT_DIR/packaging/$PLIST" "$APP_DIR/Contents/Info.plist"
codesign --force --sign - "$APP_DIR"
printf 'Built app: %s\n' "$APP_DIR"
