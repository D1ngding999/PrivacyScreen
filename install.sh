#!/bin/bash
# PrivacyScreen 安装器
#
# 推荐用法（无需 git / 无需编译工具链，直接下载预编译的通用二进制）：
#   curl -fsSL https://raw.githubusercontent.com/D1ngding999/PrivacyScreen/main/install.sh | bash
#
# 在源码目录里运行且存在 main.swift 时，会改为本机编译。
set -euo pipefail

REPO="D1ngding999/PrivacyScreen"
DIR="$HOME/PrivacyScreen"
BIN="$DIR/PrivacyScreen"
LABEL="com.privacyscreen"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
HERE="$(cd "$(dirname "$0")" 2>/dev/null && pwd || echo .)"

mkdir -p "$DIR"

if [ -f "$HERE/main.swift" ]; then
    echo "==> 本机编译（需要 Xcode Command Line Tools）…"
    swiftc -O -o "$BIN" "$HERE/main.swift"
else
    echo "==> 下载预编译二进制…"
    curl -fsSL "https://raw.githubusercontent.com/$REPO/main/PrivacyScreen.bin" -o "$BIN"
    chmod +x "$BIN"
fi

echo "==> 注册开机自启服务…"
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

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
sleep 1
launchctl bootstrap "gui/$(id -u)" "$PLIST"

echo "==> 完成。按 ⌃⌥B 变黑，再按一次恢复（备用键 ⌃⌥⌘B）"
