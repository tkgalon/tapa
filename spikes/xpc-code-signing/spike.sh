#!/bin/sh
# Can a root LaunchDaemon and a user-level client authenticate each other over XPC when both are
# signed with a local self-signed certificate (no Apple Developer account)?
#
#   ./spike.sh cert          create the signing identity in the login keychain
#   ./spike.sh trust         trust it for code signing (only if `build` fails without it)
#   ./spike.sh build         build and sign the daemon, the client and an ad-hoc client
#   sudo ./spike.sh install  install and load the LaunchDaemon
#   ./spike.sh run           signed client should get a pong, ad-hoc client should be rejected
#   sudo ./spike.sh uninstall
#   ./spike.sh remove-cert
set -eu
cd "$(dirname "$0")"

label=id.tapa.spike.daemon
cert_name="Tapa Spike Signing"
work=.spike
daemon_path=/Library/PrivilegedHelperTools/$label
plist_path=/Library/LaunchDaemons/$label.plist
log_path=/Library/Logs/tapa-spike.log
# LibreSSL from macOS writes PKCS#12 files that `security import` accepts. Homebrew's OpenSSL 3 doesn't.
openssl=/usr/bin/openssl

leaf_hash() {
    "$openssl" x509 -in "$work/cert.pem" -noout -fingerprint -sha1 | cut -d= -f2 | tr -d :
}

requirement() {
    echo "identifier \"$1\" and certificate leaf = H\"$(leaf_hash)\""
}

require_root() {
    [ "$(id -u)" -eq 0 ] || { echo "Run with sudo." >&2; exit 1; }
}

case "${1:-}" in
cert)
    mkdir -p "$work"
    "$openssl" req -x509 -newkey rsa:2048 -sha256 -days 365 -nodes \
        -keyout "$work/key.pem" -out "$work/cert.pem" -subj "/CN=$cert_name" \
        -addext "basicConstraints=critical,CA:false" \
        -addext "keyUsage=critical,digitalSignature" \
        -addext "extendedKeyUsage=critical,codeSigning"
    # The PKCS#12 password only protects the file between export and import, so it's random and
    # never stored. Once imported, the private key lives only in the keychain.
    transfer_password=$("$openssl" rand -hex 16)
    "$openssl" pkcs12 -export -inkey "$work/key.pem" -in "$work/cert.pem" \
        -out "$work/identity.p12" -passout "pass:$transfer_password"
    security import "$work/identity.p12" -P "$transfer_password" -T /usr/bin/codesign
    rm -f "$work/key.pem" "$work/identity.p12"
    echo "Leaf SHA-1: $(leaf_hash)"
    ;;
trust)
    security add-trusted-cert -r trustRoot -p codeSign -k "$HOME/Library/Keychains/login.keychain-db" "$work/cert.pem"
    ;;
build)
    swift build -c release
    bin=$(swift build -c release --show-bin-path)
    mkdir -p "$work/bin"
    cp "$bin/spike-daemon" "$bin/spike-client" "$work/bin/"
    cp "$bin/spike-client" "$work/bin/spike-client-adhoc"
    codesign --force -s "$cert_name" -i id.tapa.spike.daemon "$work/bin/spike-daemon"
    codesign --force -s "$cert_name" -i id.tapa.spike.client "$work/bin/spike-client"
    codesign --force -s - -i id.tapa.spike.client "$work/bin/spike-client-adhoc"
    for binary in spike-daemon spike-client spike-client-adhoc; do
        echo "== $binary"
        codesign -dvv "$work/bin/$binary" 2>&1 | grep -E "^(Identifier|Authority|Signature)"
    done
    ;;
install)
    require_root
    install -o root -g wheel -m 755 "$work/bin/spike-daemon" "$daemon_path"
    client_requirement=$(requirement id.tapa.spike.client | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
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
    <key>StandardErrorPath</key>
    <string>$log_path</string>
</dict>
</plist>
EOF
    chown root:wheel "$plist_path"
    chmod 644 "$plist_path"
    launchctl bootstrap system "$plist_path"
    echo "Installed. Daemon log: $log_path"
    ;;
run)
    daemon_requirement=$(requirement id.tapa.spike.daemon)
    echo "== Signed client (expect: pong from euid 0)"
    "$work/bin/spike-client" "$daemon_requirement" || true
    echo "== Ad-hoc client (expect: rejected)"
    "$work/bin/spike-client-adhoc" "$daemon_requirement" || true
    echo "== Signed client checking for the wrong daemon identity (expect: rejected)"
    "$work/bin/spike-client" "identifier \"id.tapa.someone-else\"" || true
    ;;
uninstall)
    require_root
    launchctl bootout "system/$label" 2>/dev/null || true
    rm -f "$plist_path" "$daemon_path" "$log_path"
    echo "Uninstalled."
    ;;
remove-cert)
    security remove-trusted-cert "$work/cert.pem" 2>/dev/null || true
    security delete-identity -c "$cert_name" 2>/dev/null || true
    rm -rf "$work"
    echo "Removed the signing identity and $work."
    ;;
*)
    sed -n '2,13p' "$0"
    exit 1
    ;;
esac
