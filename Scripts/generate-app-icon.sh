#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_svg="$project_root/Design/PulseBarIcon.svg"
output_dir="$project_root/PulseBar/Resources/Assets.xcassets/AppIcon.appiconset"
render_root="$(mktemp -d /tmp/pulsebar-icon.XXXXXX)"
master_png="$render_root/AppIcon-1024.png"

# 退出时只删除本次渲染的临时目录，保留已输出到资源目录的图标。
cleanup() {
    rm -rf "$render_root"
}
trap cleanup EXIT

sips -s format png "$source_svg" --out "$master_png" >/dev/null
for size in 16 32 64 128 256 512 1024; do
    sips -z "$size" "$size" "$master_png" --out "$output_dir/AppIcon-$size.png" >/dev/null
done

echo "Generated AppIcon PNGs from Design/PulseBarIcon.svg"
