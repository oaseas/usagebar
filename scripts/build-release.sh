#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

APP_VERSION="${USAGEBAR_VERSION:-0.2.0}"
BUILD_NUMBER="${USAGEBAR_BUILD:-2}"
BUNDLE_ID="${USAGEBAR_BUNDLE_ID:-io.github.oaseas.usagebar}"
SIGN_IDENTITY="${USAGEBAR_SIGN_IDENTITY:--}"
APP="dist/UsageBar.app"
ARM_BIN=".build/release-universal/arm64/UsageBar"
INTEL_BIN=".build/release-universal/x86_64/UsageBar"
UNIVERSAL_BIN=".build/release-universal/UsageBar"
ZIP="dist/UsageBar-${APP_VERSION}-macos-universal.zip"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Release builds require macOS with Xcode Command Line Tools." >&2
  exit 1
fi

mkdir -p "$(dirname "$ARM_BIN")" "$(dirname "$INTEL_BIN")" dist
rm -rf "$APP" "$ZIP"

COMMON_SOURCES=(Sources/UsageBar/*.swift)
SDK="$(xcrun --sdk macosx --show-sdk-path)"

xcrun swiftc -O -whole-module-optimization   -sdk "$SDK" -target arm64-apple-macos13.0   "${COMMON_SOURCES[@]}" -o "$ARM_BIN"

xcrun swiftc -O -whole-module-optimization   -sdk "$SDK" -target x86_64-apple-macos13.0   "${COMMON_SOURCES[@]}" -o "$INTEL_BIN"

lipo -create "$ARM_BIN" "$INTEL_BIN" -output "$UNIVERSAL_BIN"

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$UNIVERSAL_BIN" "$APP/Contents/MacOS/UsageBar"
./scripts/make-icon.sh "$APP/Contents/Resources/AppIcon.icns"

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
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST

if [[ "$SIGN_IDENTITY" == "-" ]]; then
  codesign --force --sign - "$APP"
  echo "Created an ad-hoc signed Universal build for testing."
else
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
  echo "Signed with Developer ID identity: $SIGN_IDENTITY"
fi

codesign --verify --deep --strict --verbose=2 "$APP"
lipo -archs "$APP/Contents/MacOS/UsageBar"

ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
printf 'Built %s\n' "$ZIP"
