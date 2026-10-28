#!/bin/bash
# ZEV iOS — Script đóng gói IPA tự động trên macOS

set -e

echo "🚀 Bắt đầu đóng gói Zev.ipa..."

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

# 1. Clean & Build
echo "📦 Đang biên dịch Zev (Release)..."
xcodebuild clean build \
  -project Zev.xcodeproj \
  -scheme Zev \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath ./DerivedData \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO

# 2. Locate App
APP_PATH=$(find ./DerivedData -name "Zev.app" -type d | head -n 1)

if [ -z "$APP_PATH" ]; then
  echo "❌ Lỗi: Không tìm thấy Zev.app sau khi build!"
  exit 1
fi

echo "✅ Đã tìm thấy app: $APP_PATH"

# 3. Create Payload & Zip
rm -rf Payload Zev.ipa
mkdir -p Payload
cp -r "$APP_PATH" Payload/

echo "🗜️ Đang nén thành Zev.ipa..."
zip -r Zev.ipa Payload

rm -rf Payload

echo "🎉 Hoàn tất! File IPA đã được tạo tại: $PROJECT_DIR/Zev.ipa"
ls -lh Zev.ipa
