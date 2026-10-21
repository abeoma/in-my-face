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

check_destination() {
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
}
check_destination

/usr/bin/xcodebuild -project "$repo_dir/InMyFace.xcodeproj" -scheme InMyFace \
    -configuration Release -derivedDataPath "$repo_dir/.build/InMyFace" build
built_app="$repo_dir/.build/InMyFace/Build/Products/Release/InMyFace.app"
/usr/bin/codesign --verify --strict "$built_app"

mkdir -p "$app_dir"
staging_dir=$(mktemp -d "$app_dir/.InMyFace-install.XXXXXX")
installation_succeeded=false
cleanup() {
    if [ -d "$staging_dir/previous.app" ] && [ "$installation_succeeded" != true ]; then
        # 復元先が占有されていたら、そこには触れず旧アプリを残す。
        if [ -e "$installed_app" ] || [ -L "$installed_app" ]; then
            echo "配置先が存在するため、旧アプリを保持しました: $staging_dir/previous.app" >&2
            return
        fi
        if ! mv "$staging_dir/previous.app" "$installed_app"; then
            echo "復元できないため、旧アプリを保持しました: $staging_dir/previous.app" >&2
            return
        fi
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
# ビルド中にFinder等で配置先が変わっていないか、移動の直前にも確認する。
check_destination
if [ -e "$installed_app" ]; then mv "$installed_app" "$staging_dir/previous.app"; fi
if [ -e "$installed_app" ] || [ -L "$installed_app" ]; then
    echo '配置先が新しく作成されたため、置換を中止します。' >&2
    exit 1
fi
mv "$staging_dir/InMyFace.app" "$installed_app"
/usr/bin/codesign --verify --strict "$installed_app"
installation_succeeded=true
echo "配置しました: $installed_app"
echo "起動: open \"$installed_app\""
