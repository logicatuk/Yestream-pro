#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

TARGET="${1:-simulator}" # "simulator" or "device"
BUILD_DIR="../../dist/apple-tv"
APP_BUNDLE="${BUILD_DIR}/Yestream TV.app"

echo "==> Building Yestream for Apple TV (tvOS) [Target: ${TARGET}]..."
rm -rf "${BUILD_DIR}"
mkdir -p "${APP_BUNDLE}"

if [ "${TARGET}" = "device" ]; then
    SDK="appletvos"
    TRIPLE="arm64-apple-tvos16.0"
else
    SDK="appletvsimulator"
    TRIPLE="arm64-apple-tvos16.0-simulator"
fi

SDK_PATH="$(xcrun --sdk ${SDK} --show-sdk-path)"

echo "==> Compiling Swift sources with ${SDK}..."
xcrun --sdk ${SDK} swiftc \
    -target "${TRIPLE}" \
    -sdk "${SDK_PATH}" \
    -O \
    -parse-as-library \
    -o "${APP_BUNDLE}/Yestream TV" \
    Sources/Models/*.swift \
    Sources/Services/*.swift \
    Sources/Views/*.swift \
    Sources/App/*.swift

echo "==> Packaging Info.plist and resources..."
cp Resources/Info.plist "${APP_BUNDLE}/Info.plist"

echo "==> Signing app bundle..."
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "==> Creating distribution archive..."
(cd "${BUILD_DIR}" && zip -r -q "yestream-tvos-${TARGET}.zip" "Yestream TV.app")

echo "✓ Successfully built: ${BUILD_DIR}/Yestream TV.app"
echo "✓ Distribution archive: ${BUILD_DIR}/yestream-tvos-${TARGET}.zip"
