#!/bin/bash
# 编译 PrivacyScreen 并安装为开机自启的后台服务
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
BIN="$DIR/PrivacyScreen"
LABEL="com.privacyscreen"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

echo "==> 编译…"
swiftc -O -o "$BIN" "$DIR/main.swift"

echo "==> 写入 LaunchAgent: $PLIST"
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$BIN</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$HOME/Library/Logs/PrivacyScreen.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/Library/Logs/PrivacyScreen.log</string>
</dict>
</plist>
EOF

echo "==> (重新)启动服务…"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"

echo "==> 完成。按 ⌃⌥B 变黑，再按一次恢复（备用键 ⌃⌥⌘B）"
