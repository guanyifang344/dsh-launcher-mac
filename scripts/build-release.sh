#!/bin/bash
# 打包发布产物：DshWeb.app（ad-hoc 签名）+ ZIP（便携版）+ DMG + SHA256SUMS.txt。
# 用法：./scripts/build-release.sh [版本号]
# 版本默认取最近 git tag（去掉 v 前缀），其次取环境变量 VERSION，最后回退 0.0.0。

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="DshWeb"
BUNDLE_ID="com.dsh-launcher.DshWeb"
DISPLAY_NAME="DeepSeek Harness"

# 版本号解析
if [[ -n "${1:-}" ]]; then
  VERSION="$1"
elif [[ -n "${VERSION:-}" ]]; then
  VERSION="${VERSION#v}"
else
  VERSION="$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')"
fi
VERSION="${VERSION:-0.0.0}"

DIST="$ROOT/dist"
rm -rf "$DIST"
mkdir -p "$DIST"

echo "==> 编译 release"
# 检测是否支持 universal 构建（多架构需要完整 Xcode；仅 Command Line Tools 时回退本机架构）
if xcodebuild -version >/dev/null 2>&1; then
  ARCH_FLAGS="--arch arm64 --arch x86_64"
  echo "==> 架构：universal (arm64 + x86_64)"
else
  ARCH_FLAGS=""
  echo "==> 架构：本机（未检测到完整 Xcode，跳过 universal）"
fi
# shellcheck disable=SC2086  # 有意让空 ARCH_FLAGS 展开为零参数、非空时正确分词
swift build -c release $ARCH_FLAGS
BIN_DIR="$(swift build -c release $ARCH_FLAGS --show-bin-path)"
EXE="$BIN_DIR/$APP_NAME"

if [[ ! -f "$EXE" ]]; then
  echo "错误：未找到编译产物 $EXE" >&2
  exit 1
fi

echo "==> 组装 $APP_NAME.app ($VERSION)"
APP="$DIST/$APP_NAME.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$EXE" "$APP/Contents/MacOS/$APP_NAME"
chmod +x "$APP/Contents/MacOS/$APP_NAME"

# 内嵌服务拉起脚本（App 运行时从 Resources 定位）
cp "$ROOT/scripts/start-dsh.sh" "$APP/Contents/Resources/start-dsh.sh"
chmod +x "$APP/Contents/Resources/start-dsh.sh"

printf 'APPL????' > "$APP/Contents/PkgInfo"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$DISPLAY_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$VERSION</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.developer-tools</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>NSHumanReadableCopyright</key>
  <string>Copyright © dsh-launcher contributors. MIT License.</string>
  <key>NSAppTransportSecurity</key>
  <dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
  </dict>
</dict>
</plist>
EOF

# 可选：若存在图标则复制（icns）
if [[ -f "$ROOT/assets/DshWeb.icns" ]]; then
  cp "$ROOT/assets/DshWeb.icns" "$APP/Contents/Resources/DshWeb.icns"
  /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string DshWeb" "$APP/Contents/Info.plist" 2>/dev/null || \
  /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile DshWeb" "$APP/Contents/Info.plist" 2>/dev/null || true
fi

echo "==> ad-hoc 签名"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"

echo "==> 打包 ZIP（便携版：App + 全部部署脚本）"
ZIPDIR="$DIST/dsh-launcher-mac"
mkdir -p "$ZIPDIR"
cp -R "$APP" "$ZIPDIR/"
cp "$ROOT/scripts/start-dsh.sh" \
   "$ROOT/scripts/dsh-web.sh" \
   "$ROOT/scripts/install-autostart.sh" \
   "$ROOT/scripts/uninstall-autostart.sh" "$ZIPDIR/"
chmod +x "$ZIPDIR"/*.sh
(cd "$DIST" && zip -r -q "dsh-launcher-mac-$VERSION.zip" "dsh-launcher-mac")

echo "==> 打包 DMG（安装包：App + 脚本 + /Applications 快捷方式）"
STAGE="$DIST/stage"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
cp "$ROOT/scripts/start-dsh.sh" \
   "$ROOT/scripts/dsh-web.sh" \
   "$ROOT/scripts/install-autostart.sh" \
   "$ROOT/scripts/uninstall-autostart.sh" "$STAGE/"
chmod +x "$STAGE"/*.sh
ln -s /Applications "$STAGE/Applications"

hdiutil create \
  -volname "dsh-launcher-mac" \
  -srcfolder "$STAGE" \
  -ov -format UDZO \
  "$DIST/dsh-launcher-mac-$VERSION.dmg" >/dev/null

echo "==> 生成 SHA256 校验和"
(cd "$DIST" && shasum -a 256 "dsh-launcher-mac-$VERSION.zip" "dsh-launcher-mac-$VERSION.dmg" > SHA256SUMS.txt)

# 清理中间目录
rm -rf "$ZIPDIR" "$STAGE"

echo ""
echo "发布产物："
ls -la "$DIST"
cat "$DIST/SHA256SUMS.txt"
