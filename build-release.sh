#!/bin/bash
# Shikiri リリースビルドスクリプト

set -e

# デフォルト値
VERSION="0.0.1"
DO_RELEASE=false
OUTPUT_DIR="./release"
APP_NAME="Shikiri"

# ヘルプ表示
show_help() {
    echo "Usage: $0 [OPTIONS] [VERSION]"
    echo ""
    echo "Options:"
    echo "  --release    GitHub Releaseも作成する"
    echo "  -h, --help   このヘルプを表示"
    echo ""
    echo "Examples:"
    echo "  $0                  # v0.0.1 でビルドのみ"
    echo "  $0 0.1.0            # v0.1.0 でビルドのみ"
    echo "  $0 --release 0.1.0  # v0.1.0 でビルド + GitHub Release"
}

# 引数解析
while [[ $# -gt 0 ]]; do
    case $1 in
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

echo "🔨 ${APP_NAME} v${VERSION} をビルド中..."

# 出力ディレクトリを作成
mkdir -p "$OUTPUT_DIR"

# Releaseビルド（署名なし）
xcodebuild -scheme "$APP_NAME" -configuration Release -derivedDataPath DerivedData \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    build 2>&1 | grep -E "(error:|warning:.*${APP_NAME}/|BUILD)" || true

# ビルド結果を確認
APP_PATH="DerivedData/Build/Products/Release/${APP_NAME}.app"
if [ ! -d "$APP_PATH" ]; then
    echo "❌ ビルド失敗: ${APP_PATH} が見つかりません"
    exit 1
fi

echo "✅ ビルド成功"

# ZIP化
ZIP_NAME="${APP_NAME}-v${VERSION}.zip"
echo "📦 ${ZIP_NAME} を作成中..."

cd DerivedData/Build/Products/Release
zip -r -q "${ZIP_NAME}" "${APP_NAME}.app"
mv "${ZIP_NAME}" "../../../../${OUTPUT_DIR}/"
cd - > /dev/null

# 結果を表示
echo ""
echo "✨ ビルド完了!"
echo "📁 ${OUTPUT_DIR}/${ZIP_NAME}"
ls -lh "${OUTPUT_DIR}/${ZIP_NAME}"

# GitHub Releaseを作成（オプション）
if [ "$DO_RELEASE" = true ]; then
    echo ""
    echo "🚀 GitHub Release v${VERSION} を作成中..."
    gh release create "v${VERSION}" "${OUTPUT_DIR}/${ZIP_NAME}" \
        --title "v${VERSION}" \
        --generate-notes
    echo ""
    echo "✅ リリース完了!"
fi
