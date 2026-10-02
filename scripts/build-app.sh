#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

APP_VERSION="${USAGEBAR_VERSION:-0.2.0}"
BUILD_NUMBER="${USAGEBAR_BUILD:-2}"
BUNDLE_ID="${USAGEBAR_BUNDLE_ID:-io.github.oaseas.usagebar}"

export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"
SWIFT_ARGS=(--disable-sandbox --cache-path "$PWD/.build/cache" -Xswiftc -module-cache-path -Xswiftc "$PWD/.build/module-cache")

swift build -c release "${SWIFT_ARGS[@]}"
BIN_DIR="$(swift build -c release "${SWIFT_ARGS[@]}" --show-bin-path)"
APP="dist/UsageBar.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN_DIR/UsageBar" "$APP/Contents/MacOS/UsageBar"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>UsageBar</string>
<key>CFBundleDisplayName</key><string>UsageBar</string>
<key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
<key>CFBundleExecutable</key><string>UsageBar</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>${APP_VERSION}</string>
<key>CFBundleVersion</key><string>${BUILD_NUMBER}</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST

codesign --force --sign - "$APP"
printf 'Built %s/%s\n' "$PWD" "$APP"
