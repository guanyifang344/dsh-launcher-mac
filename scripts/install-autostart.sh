#!/bin/bash
# 安装开机自启（per-user LaunchAgent，无需管理员权限）。
# 引用 App bundle 内嵌的 start-dsh.sh，因此 App 移动位置后需重新运行本脚本。

set -u

DIR="$(cd "$(dirname "$0")" && pwd)"
LABEL="com.dsh-launcher.dsh"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"
SCRIPT="$DIR/DshWeb.app/Contents/Resources/start-dsh.sh"

if [ ! -f "$SCRIPT" ]; then
  echo "错误：未找到 $SCRIPT，请确认 DshWeb.app 与本脚本位于同一目录。" >&2
  exit 1
fi

mkdir -p "$HOME/Library/LaunchAgents"

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>${SCRIPT}</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>StandardOutPath</key>
  <string>${HOME}/.dsh-web.log</string>
  <key>StandardErrorPath</key>
  <string>${HOME}/.dsh-web.log</string>
</dict>
</plist>
EOF

# 先卸载旧实例（幂等），再加载
launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"

echo "开机自启已启用：$PLIST"
