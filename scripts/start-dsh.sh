#!/bin/bash
# 静默启动 dsh 服务（无窗口），输出写入日志；dsh 不在 PATH 时自动回退 npx。
# 幂等：端口已监听时直接退出。

set -u

PORT="${DSH_WEB_PORT:-3080}"
LOG="$HOME/.dsh-web.log"

# 端口已监听则退出（curl 仅探测连通性，HTTP 状态码不影响退出码）
if curl -s --max-time 1 "http://127.0.0.1:${PORT}" >/dev/null 2>&1; then
  exit 0
fi

{
  echo "=== $(date '+%Y-%m-%d %H:%M:%S') start-dsh ==="
} >> "$LOG"

if command -v dsh >/dev/null 2>&1; then
  echo "using: dsh web --host 127.0.0.1 --port ${PORT}" >> "$LOG"
  nohup dsh web --host 127.0.0.1 --port "${PORT}" >> "$LOG" 2>&1 &
else
  echo "using: npx -y @deepseek-ai/dsh web --host 127.0.0.1 --port ${PORT}" >> "$LOG"
  nohup npx -y @deepseek-ai/dsh web --host 127.0.0.1 --port "${PORT}" >> "$LOG" 2>&1 &
fi

disown 2>/dev/null || true
exit 0
