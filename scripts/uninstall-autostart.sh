#!/bin/bash
# 移除开机自启 LaunchAgent。

set -u

LABEL="com.dsh-launcher.dsh"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"

launchctl unload "$PLIST" 2>/dev/null || true
rm -f "$PLIST"

echo "开机自启已移除"
