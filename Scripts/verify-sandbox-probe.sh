#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
probe_root="$(mktemp -d /tmp/pulsebar-probe.XXXXXX)"
probe_app="$probe_root/SystemMetricsProbe.app"

# 退出时移除本次临时探针应用，保留 SwiftPM 的可复用构建缓存。
cleanup() {
    rm -rf "$probe_root"
}
trap cleanup EXIT

cd "$project_root"
swift build -c release --product SystemMetricsProbe

mkdir -p "$probe_app/Contents/MacOS"
cp .build/release/SystemMetricsProbe "$probe_app/Contents/MacOS/SystemMetricsProbe"
plutil -create xml1 "$probe_app/Contents/Info.plist"
plutil -insert CFBundleIdentifier -string com.pulsebar.SystemMetricsProbe "$probe_app/Contents/Info.plist"
plutil -insert CFBundleName -string SystemMetricsProbe "$probe_app/Contents/Info.plist"
plutil -insert CFBundleExecutable -string SystemMetricsProbe "$probe_app/Contents/Info.plist"
plutil -insert CFBundlePackageType -string APPL "$probe_app/Contents/Info.plist"
plutil -insert CFBundleVersion -string 1 "$probe_app/Contents/Info.plist"

codesign \
    --force \
    --sign - \
    --entitlements Config/PulseBar.entitlements \
    "$probe_app"
codesign --verify --deep --strict --verbose=2 "$probe_app"
"$probe_app/Contents/MacOS/SystemMetricsProbe"
