#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
derived_data="$(mktemp -d /tmp/pulsebar-release.XXXXXX)"
release_app="$derived_data/Build/Products/Release-AppStore/PulseBar.app"
release_binary="$release_app/Contents/MacOS/PulseBar"

# 退出时清理本次验证专用的构建目录，不删除项目中的发行包。
cleanup() {
    rm -rf "$derived_data"
}
trap cleanup EXIT

cd "$project_root"

echo "[1/9] Unit tests"
swift test

echo "[2/9] Localization and privacy manifests"
xcrun xcstringstool print PulseBar/Resources/Localizable.xcstrings >/dev/null
plutil -lint PulseBar/Resources/PrivacyInfo.xcprivacy

echo "[3/9] Collector performance budgets"
Scripts/benchmark-metrics.sh 120

echo "[4/9] Debug build"
xcodebuild -quiet \
    -project PulseBar.xcodeproj \
    -scheme PulseBar \
    -configuration Debug \
    -derivedDataPath "$derived_data" \
    build

echo "[5/9] Sandboxed App Store release build"
xcodebuild -quiet \
    -project PulseBar.xcodeproj \
    -scheme PulseBar \
    -configuration Release-AppStore \
    -derivedDataPath "$derived_data" \
    build

echo "[6/9] Signature, sandbox, and bundle resources"
codesign --verify --deep --strict --verbose=2 "$release_app"
entitlements="$(codesign -d --entitlements - "$release_app" 2>&1)"
if ! grep -q 'com.apple.security.app-sandbox' <<<"$entitlements"; then
    echo "FAIL: App Sandbox entitlement is missing" >&2
    exit 1
fi
if grep -q 'com.apple.security.network.client' <<<"$entitlements"; then
    echo "FAIL: unexpected outbound network entitlement" >&2
    exit 1
fi
test -f "$release_app/Contents/Resources/PrivacyInfo.xcprivacy"
test -f "$release_app/Contents/Resources/Assets.car"
test -f "$release_app/Contents/Resources/en.lproj/Localizable.strings"
test -f "$release_app/Contents/Resources/zh-Hans.lproj/Localizable.strings"
test "$(plutil -extract LSUIElement raw "$release_app/Contents/Info.plist")" = "true"

echo "[7/9] Dependency and offline-boundary audit"
unexpected_dependencies="$(
    otool -L "$release_binary" \
        | tail -n +2 \
        | awk '{print $1}' \
        | grep -Ev '^(/System/Library/|/usr/lib/)' || true
)"
if [[ -n "$unexpected_dependencies" ]]; then
    echo "FAIL: unexpected runtime dependencies:" >&2
    echo "$unexpected_dependencies" >&2
    exit 1
fi
if rg -n \
    'URLSession|NSURLConnection|CFHTTP|PrivateFrameworks|dlopen\(' \
    PulseBar --glob '*.swift'; then
    echo "FAIL: source contains an unexpected external-network or private-framework API" >&2
    exit 1
fi
if rg -n 'volumeAvailableCapacity(Key|ForImportantUsage)' PulseBar --glob '*.swift'; then
    echo "FAIL: URL capacity lookup can enter costly CacheDelete work; use statfs" >&2
    exit 1
fi

echo "[8/9] Sandboxed raw API probe"
Scripts/verify-sandbox-probe.sh

echo "[9/9] Repository hygiene"
git diff --check
test -z "$(git ls-files '*.DS_Store')"

echo "PASS: automated release verification completed"
