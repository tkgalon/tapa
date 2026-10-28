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

scripts/build-app.sh debug .build/Tapa.app

# The app restarts the tracker from the new bundle when it opens.
pkill -x Tapa 2>/dev/null || true
sleep 1

# -n: after a forced quit, Launch Services can still think the old copy is running.
open -n .build/Tapa.app
