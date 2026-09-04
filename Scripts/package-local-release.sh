#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat <<'EOF'
Usage: Scripts/package-local-release.sh [options]

Build and validate a local ad-hoc signed Universal macOS release package.

Options:
  --verify              Run Scripts/verify-release.sh before packaging.
  --launch              Stop and relaunch PulseBar from the packaged app.
  --output-dir <path>   Write PulseBar.app and the ZIP here (default: dist).
  -h, --help            Show this help.
EOF
}

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
run_full_verification=0
launch_after_packaging=0
output_dir="$project_root/dist"

while [[ $# -gt 0 ]]; do
    case "$1" in
    --verify)
        run_full_verification=1
        shift
        ;;
    --launch)
        launch_after_packaging=1
        shift
        ;;
    --output-dir)
        if [[ $# -lt 2 ]]; then
            echo "Missing value for --output-dir" >&2
            usage >&2
            exit 64
        fi
        output_dir="$2"
        shift 2
        ;;
    -h | --help)
        usage
        exit 0
        ;;
    *)
        echo "Unknown option: $1" >&2
        usage >&2
        exit 64
        ;;
    esac
done

if [[ "$output_dir" != /* ]]; then
    output_dir="$project_root/$output_dir"
fi

required_commands=(
    codesign
    ditto
    git
    lipo
    otool
    plutil
    shasum
    unzip
    xcodebuild
)
for required_command in "${required_commands[@]}"; do
    if ! command -v "$required_command" >/dev/null 2>&1; then
        echo "Missing required command: $required_command" >&2
        exit 69
    fi
done

# 只返回命令路径匹配目标二进制的 PulseBar 进程，避免重启其他位置的应用副本。
pids_for_binary() {
    local target_binary="$1"
    local process_command

    for pid in $(pgrep -x PulseBar 2>/dev/null || true); do
        process_command="$(ps -o command= -p "$pid" | sed 's/^[[:space:]]*//')"
        if [[ "$process_command" == "$target_binary" || "$process_command" == "$target_binary "* ]]; then
            echo "$pid"
        fi
    done
}

cd "$project_root"

if (( run_full_verification == 1 )); then
    echo "[1/6] Full release verification"
    Scripts/verify-release.sh
else
    echo "[1/6] Full release verification skipped (use --verify to enable)"
fi

revision="$(git rev-parse --short HEAD)"
if [[ -n "$(git status --porcelain --untracked-files=normal)" ]]; then
    revision="${revision}-dirty"
    echo "WARNING: packaging uncommitted changes as revision $revision" >&2
fi
git diff --check

work_root="$(mktemp -d /tmp/pulsebar-local-package.XXXXXX)"
derived_data="$work_root/DerivedData"
release_app="$derived_data/Build/Products/Release-AppStore/PulseBar.app"
release_binary="$release_app/Contents/MacOS/PulseBar"
stage_root="$work_root/stage"
verify_root="$work_root/verify"
candidate_app=""
candidate_zip=""
previous_app=""
previous_zip=""
final_app=""
final_zip=""

# 交付中断且目标缺失时恢复旧产物，再删除本次候选文件和临时工作目录。
# 若新目标已经存在则不会回滚，故这不是对所有校验失败的完整事务回滚。
cleanup() {
    if [[ -n "$previous_app" && -e "$previous_app" && -n "$final_app" && ! -e "$final_app" ]]; then
        mv "$previous_app" "$final_app"
    fi
    if [[ -n "$previous_zip" && -e "$previous_zip" && -n "$final_zip" && ! -e "$final_zip" ]]; then
        mv "$previous_zip" "$final_zip"
    fi
    if [[ -n "$candidate_app" && -e "$candidate_app" ]]; then
        rm -rf "$candidate_app"
    fi
    if [[ -n "$candidate_zip" && -e "$candidate_zip" ]]; then
        rm -f "$candidate_zip"
    fi
    rm -rf "$work_root"
}
trap cleanup EXIT

echo "[2/6] Universal Release-AppStore build"
xcodebuild -quiet \
    -project PulseBar.xcodeproj \
    -scheme PulseBar \
    -configuration Release-AppStore \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$derived_data" \
    ARCHS='arm64 x86_64' \
    ONLY_ACTIVE_ARCH=NO \
    build

test -d "$release_app"
test -x "$release_binary"

archs="$(lipo -archs "$release_binary")"
for expected_arch in arm64 x86_64; do
    if [[ " $archs " != *" $expected_arch "* ]]; then
        echo "FAIL: missing $expected_arch architecture (found: $archs)" >&2
        exit 1
    fi
done

echo "[3/6] Bundle, signature, sandbox, and dependency validation"
codesign --verify --deep --strict --verbose=2 "$release_app"
signing_info="$(codesign -dv --verbose=4 "$release_app" 2>&1)"
if ! grep -qE 'flags=.*runtime' <<<"$signing_info"; then
    echo "FAIL: hardened runtime is missing" >&2
    exit 1
fi
if grep -q '^Signature=adhoc$' <<<"$signing_info"; then
    signing_summary="ad-hoc with hardened runtime; Developer ID notarization not included"
else
    team_identifier="$(awk -F= '/^TeamIdentifier=/{print $2; exit}' <<<"$signing_info")"
    signing_summary="distribution signature with hardened runtime; team=${team_identifier:-unknown}"
fi
entitlements="$(codesign -d --entitlements - "$release_app" 2>&1)"
if ! grep -q 'com.apple.security.app-sandbox' <<<"$entitlements"; then
    echo "FAIL: App Sandbox entitlement is missing" >&2
    exit 1
fi
if grep -q 'com.apple.security.network.client' <<<"$entitlements"; then
    echo "FAIL: unexpected outbound network entitlement" >&2
    exit 1
fi

plutil -lint \
    "$release_app/Contents/Info.plist" \
    "$release_app/Contents/Resources/PrivacyInfo.xcprivacy" >/dev/null
test -f "$release_app/Contents/Resources/Assets.car"
test -f "$release_app/Contents/Resources/en.lproj/Localizable.strings"
test -f "$release_app/Contents/Resources/zh-Hans.lproj/Localizable.strings"
test "$(plutil -extract LSUIElement raw "$release_app/Contents/Info.plist")" = "true"

for arch in arm64 x86_64; do
    unexpected_dependencies="$(
        otool -arch "$arch" -L "$release_binary" \
            | tail -n +2 \
            | awk '{print $1}' \
            | grep -Ev '^(/System/Library/|/usr/lib/)' || true
    )"
    if [[ -n "$unexpected_dependencies" ]]; then
        echo "FAIL: unexpected $arch runtime dependencies:" >&2
        echo "$unexpected_dependencies" >&2
        exit 1
    fi
done

version="$(plutil -extract CFBundleShortVersionString raw "$release_app/Contents/Info.plist")"
build_number="$(plutil -extract CFBundleVersion raw "$release_app/Contents/Info.plist")"
package_name="PulseBar-${version}-${revision}-macos-universal.zip"
package_path="$stage_root/$package_name"

echo "[4/6] ZIP creation and extraction validation"
mkdir -p "$stage_root" "$verify_root"
ditto "$release_app" "$stage_root/PulseBar.app"
ditto -c -k --sequesterRsrc --keepParent "$stage_root/PulseBar.app" "$package_path"
zip_entries="$(unzip -Z1 "$package_path")"
if grep -qE '(^|/)\.DS_Store$' <<<"$zip_entries"; then
    echo "FAIL: package contains .DS_Store" >&2
    exit 1
fi
ditto -x -k "$package_path" "$verify_root"
verified_app="$verify_root/PulseBar.app"
verified_binary="$verified_app/Contents/MacOS/PulseBar"
codesign --verify --deep --strict --verbose=2 "$verified_app"
test "$(lipo -archs "$verified_binary")" = "$archs"
test "$(plutil -extract CFBundleShortVersionString raw "$verified_app/Contents/Info.plist")" = "$version"
test "$(plutil -extract CFBundleVersion raw "$verified_app/Contents/Info.plist")" = "$build_number"

echo "[5/6] Atomic delivery to $output_dir"
mkdir -p "$output_dir"
final_app="$output_dir/PulseBar.app"
final_zip="$output_dir/$package_name"
candidate_app="$output_dir/.PulseBar.app.$$.new"
candidate_zip="$output_dir/.${package_name}.$$.new"
test ! -e "$candidate_app"
test ! -e "$candidate_zip"
ditto "$release_app" "$candidate_app"
ditto "$package_path" "$candidate_zip"

if [[ -e "$final_app" ]]; then
    previous_app="$work_root/previous-PulseBar.app"
    mv "$final_app" "$previous_app"
fi
mv "$candidate_app" "$final_app"
candidate_app=""

if [[ -e "$final_zip" ]]; then
    previous_zip="$work_root/previous-$package_name"
    mv "$final_zip" "$previous_zip"
fi
mv "$candidate_zip" "$final_zip"
candidate_zip=""

codesign --verify --deep --strict --verbose=2 "$final_app"
test "$(lipo -archs "$final_app/Contents/MacOS/PulseBar")" = "$archs"
source_hash="$(shasum -a 256 "$package_path" | cut -d ' ' -f 1)"
final_hash="$(shasum -a 256 "$final_zip" | cut -d ' ' -f 1)"
test "$source_hash" = "$final_hash"

echo "[6/6] Final result"
final_binary="$final_app/Contents/MacOS/PulseBar"
running_pids="$(pids_for_binary "$final_binary")"

if (( launch_after_packaging == 1 )); then
    for pid in $running_pids; do
        kill "$pid"
    done
    if [[ -n "$running_pids" ]]; then
        sleep 2
    fi
    open -n "$final_app"
    sleep 3
    if [[ -z "$(pids_for_binary "$final_binary")" ]]; then
        echo "FAIL: packaged app did not launch" >&2
        exit 1
    fi
    echo "Packaged app launched: $final_app"
elif [[ -n "$running_pids" ]]; then
    echo "NOTE: PulseBar is running; restart it to load the newly packaged app."
fi

package_size="$(stat -f %z "$final_zip")"
echo "PASS: local release package created"
echo "Version: $version ($build_number)"
echo "Revision: $revision"
echo "Architectures: $archs"
echo "App: $final_app"
echo "ZIP: $final_zip"
echo "Size: $package_size bytes"
echo "SHA-256: $final_hash"
echo "Signing: $signing_summary"
