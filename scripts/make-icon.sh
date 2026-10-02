#!/bin/bash
set -euo pipefail

OUTPUT="${1:?Usage: make-icon.sh /path/to/AppIcon.icns}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT/Assets/UsageBar-AppIcon.png"
ICONSET="$ROOT/.build/AppIcon.iconset"

rm -rf "$ICONSET"
mkdir -p "$ICONSET" "$(dirname "$OUTPUT")"

resize_icon() {
  local size="$1"
  local name="$2"
  sips -z "$size" "$size" "$SOURCE" --out "$ICONSET/$name" >/dev/null
}

resize_icon 16   icon_16x16.png
resize_icon 32   icon_16x16@2x.png
resize_icon 32   icon_32x32.png
resize_icon 64   icon_32x32@2x.png
resize_icon 128  icon_128x128.png
resize_icon 256  icon_128x128@2x.png
resize_icon 256  icon_256x256.png
resize_icon 512  icon_256x256@2x.png
resize_icon 512  icon_512x512.png
resize_icon 1024 icon_512x512@2x.png

iconutil -c icns "$ICONSET" -o "$OUTPUT"
rm -rf "$ICONSET"
