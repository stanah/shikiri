#!/bin/bash
# Shikiri リリースビルドスクリプト

set -e

# デフォルト値
VERSION="0.0.1"
DO_RELEASE=false
DO_SIGNED=false
OUTPUT_DIR="./release"
APP_NAME="Shikiri"

# ヘルプ表示
show_help() {
    echo "Usage: $0 [OPTIONS] [VERSION]"
    echo ""
    echo "Options:"
    echo "  --signed     署名付きでビルド (要: DEVELOPMENT_TEAM 環境変数)"
    echo "  --release    GitHub Releaseも作成する"
    echo "  -h, --help   このヘルプを表示"
    echo ""
    echo "Examples:"
    echo "  $0                         # v0.0.1 で署名なしビルド"
    echo "  $0 --signed 0.1.0          # v0.1.0 で署名付きビルド"
    echo "  $0 --signed --release 0.1.0  # 署名付きビルド + GitHub Release"
}

# 引数解析
while [[ $# -gt 0 ]]; do
    case $1 in
        --signed)
            DO_SIGNED=true
            shift
            ;;
        --release)
            DO_RELEASE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            VERSION="$1"
            shift
            ;;
    esac
done

# 署名付きビルドの場合、DEVELOPMENT_TEAMを確認
if [ "$DO_SIGNED" = true ]; then
    if [ -z "$DEVELOPMENT_TEAM" ]; then
        echo "❌ 環境変数 DEVELOPMENT_TEAM が設定されていません"
        echo "   export DEVELOPMENT_TEAM=\"YOUR_TEAM_ID\" を実行してください"
        exit 1
    fi
    echo "🔨 ${APP_NAME} v${VERSION} をビルド中... (署名付き)"
else
    echo "🔨 ${APP_NAME} v${VERSION} をビルド中... (署名なし)"
fi

# 出力ディレクトリを作成
mkdir -p "$OUTPUT_DIR"

# ビルド
if [ "$DO_SIGNED" = true ]; then
    # 署名付きビルド
    xcodebuild -scheme "$APP_NAME" -configuration Release -derivedDataPath DerivedData \
        CODE_SIGN_IDENTITY="Apple Development" \
        DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
        CODE_SIGN_STYLE="Automatic" \
        build 2>&1 | grep -E "(error:|warning:.*${APP_NAME}/|BUILD)" || true
else
    # 署名なしビルド
    xcodebuild -scheme "$APP_NAME" -configuration Release -derivedDataPath DerivedData \
        CODE_SIGN_IDENTITY="-" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO \
        build 2>&1 | grep -E "(error:|warning:.*${APP_NAME}/|BUILD)" || true
fi

# ビルド結果を確認
APP_PATH="DerivedData/Build/Products/Release/${APP_NAME}.app"
if [ ! -d "$APP_PATH" ]; then
    echo "❌ ビルド失敗: ${APP_PATH} が見つかりません"
    exit 1
fi

echo "✅ ビルド成功"

# DMG作成
DMG_NAME="${APP_NAME}-v${VERSION}.dmg"
echo "📦 ${DMG_NAME} を作成中..."

# 一時ディレクトリを作成
DMG_TEMP="$(mktemp -d)"
cp -R "$APP_PATH" "$DMG_TEMP/"
ln -s /Applications "$DMG_TEMP/Applications"

# DMGを作成
hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_TEMP" -ov -format UDZO "${OUTPUT_DIR}/${DMG_NAME}" -quiet

# 一時ディレクトリを削除
rm -rf "$DMG_TEMP"

# 結果を表示
echo ""
echo "✨ ビルド完了!"
echo "📁 ${OUTPUT_DIR}/${DMG_NAME}"
ls -lh "${OUTPUT_DIR}/${DMG_NAME}"

# GitHub Releaseを作成（オプション）
if [ "$DO_RELEASE" = true ]; then
    echo ""
    echo "🚀 GitHub Release v${VERSION} を作成中..."
    gh release create "v${VERSION}" "${OUTPUT_DIR}/${DMG_NAME}" \
        --title "v${VERSION}" \
        --generate-notes
    echo ""
    echo "✅ リリース完了!"
fi
