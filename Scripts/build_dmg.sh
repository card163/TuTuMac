#!/bin/bash
# 把 dist/TuTuMac.app 打包成可拖拽安装的 .dmg 安装镜像(标准 macOS 分发格式)。
# 依赖: 先运行 ./Scripts/build_app.sh 生成 dist/TuTuMac.app;需要 create-dmg
# (brew install create-dmg)。
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="TuTuMac"
VERSION="${1:-1.1.0}"
APP_PATH="dist/$APP_NAME.app"
DMG_PATH="dist/$APP_NAME-$VERSION-macOS.dmg"

if [ ! -d "$APP_PATH" ]; then
  echo "未找到 $APP_PATH,请先运行 ./Scripts/build_app.sh" >&2
  exit 1
fi

if ! command -v create-dmg >/dev/null 2>&1; then
  echo "未找到 create-dmg,请先执行: brew install create-dmg" >&2
  exit 1
fi

rm -f "$DMG_PATH"

create-dmg \
  --volname "$APP_NAME $VERSION" \
  --window-size 640 400 \
  --icon-size 128 \
  --icon "$APP_NAME.app" 160 190 \
  --app-drop-link 480 190 \
  --hide-extension "$APP_NAME.app" \
  "$DMG_PATH" \
  "$APP_PATH"

echo "==> 完成: $DMG_PATH"
echo "提示: 未做正式签名/公证,对方 Mac 首次打开仍会被 Gatekeeper 拦截,"
echo "需要右键「打开」确认,或执行: xattr -cr /Applications/$APP_NAME.app"
