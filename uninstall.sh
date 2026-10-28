#!/bin/bash
# 卸载 PrivacyScreen 后台服务（可选删除源码目录）
set -euo pipefail

LABEL="com.privacyscreen"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$PLIST"
echo "==> 已卸载服务。如需彻底清理，删除整个 PrivacyScreen 目录即可："
echo "    rm -rf \"\$HOME/PrivacyScreen\""
