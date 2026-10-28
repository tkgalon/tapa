#!/bin/sh
# Builds Tapa.app into .build, signs it with the local certificate so the daemon accepts it, and
# opens it. Run scripts/install.sh once first: it creates the certificate and installs the daemon.
set -eu
cd "$(dirname "$0")/.."

cert_name="Tapa Local Signing"
if ! security find-certificate -c "$cert_name" >/dev/null 2>&1; then
    echo "The signing certificate \"$cert_name\" is missing. Run scripts/install.sh first." >&2
    exit 1
fi

swift build --product TapaApp
swift build --product TapaTracker
bin=$(swift build --show-bin-path)

app=.build/Tapa.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp App/Info.plist "$app/Contents/Info.plist"
cp "$bin/TapaApp" "$app/Contents/MacOS/Tapa"
cp "$bin/TapaTracker" "$app/Contents/MacOS/TapaTracker"
cp App/Resources/*.jpg "$app/Contents/Resources/"
# The tracker is signed on its own first, so the daemon can tell it apart from the app.
codesign --force -s "$cert_name" -i id.tapa.tracker "$app/Contents/MacOS/TapaTracker"
codesign --force -s "$cert_name" -i id.tapa.app "$app"

# The app restarts the tracker from the new bundle when it opens.
pkill -x Tapa 2>/dev/null || true
sleep 1

open "$app"
