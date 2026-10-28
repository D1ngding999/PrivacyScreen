#!/bin/bash
# 维护者脚本：编译 Intel + Apple Silicon 通用二进制 → PrivacyScreen.bin
# 上传 GitHub 前跑一次这个即可。
set -euo pipefail
cd "$(dirname "$0")"

swiftc -O -target arm64-apple-macos12  main.swift -o /tmp/ps-arm64
swiftc -O -target x86_64-apple-macos12 main.swift -o /tmp/ps-x86_64
lipo -create -output PrivacyScreen.bin /tmp/ps-arm64 /tmp/ps-x86_64
rm -f /tmp/ps-arm64 /tmp/ps-x86_64
lipo -info PrivacyScreen.bin
