#!/bin/sh
# Removes Tapa, its hosts file block and its signing certificate. Refuses while Summit Mode runs.
# Run as yourself. You'll be asked for your password once.
set -eu

if [ "$(id -u)" -eq 0 ]; then
    echo "Run as yourself, without sudo. The signing certificate lives in your login keychain." >&2
    exit 1
fi

label=id.tapa.daemon
cert_name="Tapa Local Signing"
cli=/usr/local/bin/tapactl

if [ -x "$cli" ] && "$cli" status 2>/dev/null | grep -q '^Mode: summit$'; then
    echo "Summit Mode is running. Tapa can be uninstalled once it ends." >&2
    exit 1
fi

echo "Uninstalling (needs your password)..."
sudo /bin/sh -s -- "$label" <<'ROOT'
set -eu
label=$1
daemon_path=/Library/PrivilegedHelperTools/$label

launchctl bootout "system/$label" 2>/dev/null || true
# The daemon is stopped now, so nothing rewrites the block after it's removed.
if [ -x "$daemon_path" ]; then
    "$daemon_path" --clear-hosts
fi
rm -f "/Library/LaunchDaemons/$label.plist" "$daemon_path" /usr/local/bin/tapactl
rm -rf "/Library/Application Support/Tapa" /Library/Logs/Tapa
ROOT

security delete-identity -c "$cert_name" >/dev/null 2>&1 || true
echo "Uninstalled."
