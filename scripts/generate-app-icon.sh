#!/bin/bash
# 生成元PNGから、macOS用の全サイズを含むICNSを作成する。
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
source_image="$repo_dir/InMyFace/Resources/AppIcon.png"
mkdir -p "$repo_dir/.build"
work_dir=$(mktemp -d "$repo_dir/.build/app-icon.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT
iconset="$work_dir/AppIcon.iconset"
mkdir "$iconset"
for size in 16 32 128 256 512; do
    /usr/bin/sips -z "$size" "$size" "$source_image" \
        --out "$iconset/icon_${size}x${size}.png" >/dev/null
    double_size=$((size * 2))
    /usr/bin/sips -z "$double_size" "$double_size" "$source_image" \
        --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
/usr/bin/iconutil -c icns "$iconset" -o "$repo_dir/InMyFace/Resources/AppIcon.icns"
echo 'AppIcon.icnsを生成しました。'
