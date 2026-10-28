#!/bin/sh
# Builds Tapa.app with its tracker, photos and icon, signed with the local certificate.
# Usage: scripts/build-app.sh <debug|release> <output Tapa.app>
set -eu
cd "$(dirname "$0")/.."

configuration=$1
app=$2
cert_name="Tapa Local Signing"

swift build -c "$configuration" --product TapaApp
swift build -c "$configuration" --product TapaTracker
bin=$(swift build -c "$configuration" --show-bin-path)

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp App/Info.plist "$app/Contents/Info.plist"
cp "$bin/TapaApp" "$app/Contents/MacOS/Tapa"
# The tracker is a helper app of its own, so macOS treats it as background only and never puts it
# in the Dock, rather than as a second copy of Tapa.
helper="$app/Contents/Library/LoginItems/TapaTracker.app"
mkdir -p "$helper/Contents/MacOS" "$helper/Contents/Resources"
cp Sources/TapaTracker/Info.plist "$helper/Contents/Info.plist"
cp "$bin/TapaTracker" "$helper/Contents/MacOS/TapaTracker"
cp App/Resources/*.jpg "$app/Contents/Resources/"
# Mist is served by the tracker, so its photos live in the helper's bundle too.
cp App/Resources/mist-*.jpg "$helper/Contents/Resources/"

# Every size macOS asks for, cut from the one 1024 px icon.
work=$(mktemp -d)
iconset="$work/AppIcon.iconset"
mkdir -p "$iconset"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" App/AppIcon.png --out "$iconset/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" App/AppIcon.png --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o "$app/Contents/Resources/AppIcon.icns"
rm -rf "$work"

# The tracker is signed on its own first, so the daemon can tell it apart from the app.
codesign --force -s "$cert_name" -i id.tapa.tracker "$helper"
codesign --force -s "$cert_name" -i id.tapa.app "$app"
