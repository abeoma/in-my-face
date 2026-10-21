#!/bin/bash
# 個人利用向けに署名済みReleaseビルドを配置する。
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
app_dir="$HOME/Applications"
installed_app="$app_dir/InMyFace.app"

# 起動中のアプリを置き換えない。pgrepの実行失敗も停止する。
if /usr/bin/pgrep -x InMyFace >/dev/null; then
    echo 'メニューバーからIn My Faceを終了して、再実行してください。' >&2
    exit 1
else
    result=$?
    if [ "$result" -ne 1 ]; then
        echo 'アプリの起動状態を確認できませんでした。' >&2
        exit "$result"
    fi
fi

if [ -L "$installed_app" ]; then
    echo "配置先がシンボリックリンクのため停止します: $installed_app" >&2
    exit 1
fi
if [ -e "$installed_app" ]; then
    bundle_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$installed_app/Contents/Info.plist")
    if [ "$bundle_id" != 'com.abeoma.inmyface' ]; then
        echo "別のアプリがあるため停止します: $installed_app" >&2
        exit 1
    fi
fi

/usr/bin/xcodebuild -project "$repo_dir/InMyFace.xcodeproj" -scheme InMyFace \
    -configuration Release -derivedDataPath "$repo_dir/.build/InMyFace" build
built_app="$repo_dir/.build/InMyFace/Build/Products/Release/InMyFace.app"
/usr/bin/codesign --verify --strict "$built_app"

mkdir -p "$app_dir"
staging_dir=$(mktemp -d "$app_dir/.InMyFace-install.XXXXXX")
cleanup() {
    # 置換に失敗した場合は旧アプリを戻す。
    if [ -d "$staging_dir/previous.app" ] && [ ! -e "$installed_app" ]; then
        mv "$staging_dir/previous.app" "$installed_app" || return
    fi
    rm -rf "$staging_dir"
}
trap cleanup EXIT
/usr/bin/ditto "$built_app" "$staging_dir/InMyFace.app"
/usr/bin/codesign --verify --strict "$staging_dir/InMyFace.app"

# ビルド中に起動された場合も更新を中止する。
if /usr/bin/pgrep -x InMyFace >/dev/null; then
    echo 'ビルド中にアプリが起動しました。終了して再実行してください。' >&2
    exit 1
else
    result=$?
    if [ "$result" -ne 1 ]; then exit "$result"; fi
fi
if [ -e "$installed_app" ]; then mv "$installed_app" "$staging_dir/previous.app"; fi
mv "$staging_dir/InMyFace.app" "$installed_app"
echo "配置しました: $installed_app"
echo "起動: open \"$installed_app\""
