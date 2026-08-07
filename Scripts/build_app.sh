#!/bin/bash
# 将 SwiftPM 可执行产物打包成正式的 macOS .app bundle,便于双击启动、
# 并让「隐私与安全性 -> 辅助功能」权限授权可以稳定关联到同一个 Bundle Identifier。
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIGURATION="${1:-release}"
APP_NAME="TuTuMac"
BUNDLE_ID="com.tutumac.app"
VERSION="1.0.0"
BUILD_NUMBER="$(date +%Y%m%d%H%M)"

echo "==> swift build -c $CONFIGURATION"
swift build -c "$CONFIGURATION"

BIN_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"
BIN_PATH="$BIN_DIR/$APP_NAME"

APP_DIR="dist/$APP_NAME.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/$APP_NAME"

sed \
  -e "s/__BUNDLE_ID__/$BUNDLE_ID/g" \
  -e "s/__VERSION__/$VERSION/g" \
  -e "s/__BUILD__/$BUILD_NUMBER/g" \
  Resources/Info.plist.template > "$APP_DIR/Contents/Info.plist"

echo "==> codesign (ad-hoc,仅用于本机运行和辅助功能授权,不能用于对外分发)"
codesign --force --deep --sign - "$APP_DIR"

echo "==> 完成: $APP_DIR"
echo "首次运行前往「系统设置 -> 隐私与安全性 -> 辅助功能」为 $APP_NAME 授权,才能使用按键映射功能。"
echo "可直接打开: open \"$APP_DIR\""
