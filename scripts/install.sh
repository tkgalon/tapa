#!/bin/sh
# Builds Tapa, signs it with a local certificate, installs the daemon and tapactl, and puts
# Tapa.app in /Applications.
# Run as yourself. You'll be asked for your password once, for the steps that need root.
set -eu
cd "$(dirname "$0")/.."

if [ "$(id -u)" -eq 0 ]; then
    echo "Run as yourself, without sudo. The signing certificate lives in your login keychain." >&2
    exit 1
fi

label=id.tapa.daemon
cert_name="Tapa Local Signing"
openssl=/usr/bin/openssl

create_certificate() {
    work=$(mktemp -d)
    trap 'rm -rf "$work"' EXIT
    "$openssl" req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
        -keyout "$work/key.pem" -out "$work/cert.pem" -subj "/CN=$cert_name" \
        -addext "basicConstraints=critical,CA:false" \
        -addext "keyUsage=critical,digitalSignature" \
        -addext "extendedKeyUsage=critical,codeSigning" 2>/dev/null
    # The PKCS#12 password only protects the file between export and import, so it's random and
    # never stored. The private key ends up only in the keychain.
    transfer_password=$("$openssl" rand -hex 16)
    "$openssl" pkcs12 -export -inkey "$work/key.pem" -in "$work/cert.pem" \
        -out "$work/identity.p12" -passout "pass:$transfer_password"
    security import "$work/identity.p12" -P "$transfer_password" -T /usr/bin/codesign >/dev/null
    rm -rf "$work"
    trap - EXIT
}

if ! security find-certificate -c "$cert_name" >/dev/null 2>&1; then
    echo "Creating the signing certificate \"$cert_name\"..."
    create_certificate
fi
leaf_hash=$(security find-certificate -c "$cert_name" -Z | awk '/^SHA-1 hash:/ { print $3 }')

echo "Building..."
swift build -c release --product TapaDaemon
swift build -c release --product tapactl
bin=$(swift build -c release --show-bin-path)

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
cp "$bin/TapaDaemon" "$bin/tapactl" "$stage/"
codesign --force -s "$cert_name" -i "$label" "$stage/TapaDaemon"
codesign --force -s "$cert_name" -i id.tapa.cli "$stage/tapactl"

daemon_requirement="identifier \"$label\" and certificate leaf = H\"$leaf_hash\""
client_requirement="certificate leaf = H\"$leaf_hash\" and (identifier \"id.tapa.cli\" or identifier \"id.tapa.app\" or identifier \"id.tapa.tracker\")"

echo "Installing (needs your password)..."
sudo /bin/sh -s -- "$stage" "$label" "$daemon_requirement" "$client_requirement" <<'ROOT'
set -eu
stage=$1
label=$2
daemon_requirement=$3
client_requirement=$4

support_dir="/Library/Application Support/Tapa"
daemon_path=/Library/PrivilegedHelperTools/$label
plist_path=/Library/LaunchDaemons/$label.plist
log_dir=/Library/Logs/Tapa

if [ -f "$plist_path" ]; then
    launchctl bootout "system/$label" 2>/dev/null || true
fi

install -d -o root -g wheel -m 755 "$support_dir" "$log_dir" /usr/local/bin
install -o root -g wheel -m 755 "$stage/TapaDaemon" "$daemon_path"
install -o root -g wheel -m 755 "$stage/tapactl" /usr/local/bin/tapactl
printf '%s\n' "$daemon_requirement" > "$support_dir/daemon.requirement"
chmod 644 "$support_dir/daemon.requirement"

cat > "$plist_path" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$label</string>
    <key>ProgramArguments</key>
    <array>
        <string>$daemon_path</string>
        <string>$client_requirement</string>
    </array>
    <key>MachServices</key>
    <dict>
        <key>$label</key>
        <true/>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardErrorPath</key>
    <string>$log_dir/daemon.log</string>
</dict>
</plist>
EOF
chown root:wheel "$plist_path"
chmod 644 "$plist_path"
launchctl bootstrap system "$plist_path"
ROOT

# Owned by the user, like any app copied into /Applications. Opening it points the tracker here.
echo "Installing Tapa.app..."
pkill -x Tapa 2>/dev/null || true
scripts/build-app.sh release "$stage/Tapa.app"
rm -rf /Applications/Tapa.app
ditto "$stage/Tapa.app" /Applications/Tapa.app
open /Applications/Tapa.app

sleep 1
echo "Installed."
/usr/local/bin/tapactl status
