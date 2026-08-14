#!/bin/bash
# 静默启动 dsh 服务（无窗口），输出写入日志；dsh 不在 PATH 时自动回退 npx。
# 幂等：端口已监听时直接退出。

set -u

# 扩展 PATH，兼容 LaunchAgent 场景：launchd 默认 PATH 只有 /usr/bin:/bin:/usr/sbin:/sbin，
# 不含 Node.js 安装目录，会导致 command -v dsh / npx 失败、开机自启静默失效。
# 覆盖 Homebrew（Apple Silicon / Intel）、官方安装器、用户本地等常见位置。
export PATH="$HOME/.local/nodejs/bin:$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

# 兼容 nvm：node 路径带版本号（~/.nvm/versions/node/vXX/bin），取最新版本加入 PATH
if [ -d "$HOME/.nvm/versions/node" ]; then
  NVM_BIN="$(ls -d "$HOME/.nvm/versions/node/"*/bin 2>/dev/null | sort -V | tail -1)"
  if [ -n "$NVM_BIN" ]; then
    export PATH="$NVM_BIN:$PATH"
  fi
fi

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
