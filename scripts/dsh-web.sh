#!/bin/bash
# 一键入口：检测端口 → 拉起服务 → 打开壳窗口。

set -u

DIR="$(cd "$(dirname "$0")" && pwd)"
PORT="${DSH_WEB_PORT:-3080}"
URL="${DSH_WEB_URL:-http://127.0.0.1:${PORT}}"

"$DIR/start-dsh.sh"

# 等待就绪（最长 90 秒）
for _ in $(seq 1 90); do
  if curl -s --max-time 1 "$URL" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

if [ -d "$DIR/DshWeb.app" ]; then
  open "$DIR/DshWeb.app"
else
  echo "未找到 DshWeb.app，请确认目录：$DIR" >&2
  exit 1
fi
