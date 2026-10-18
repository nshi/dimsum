#!/bin/bash
# Creates a self-signed code signing certificate so builds keep the same
# identity across rebuilds, which keeps the Accessibility grant valid.
#
# Usage: scripts/create-signing-cert.sh [keychain]
#   keychain defaults to the login keychain.
#
# Points local builds at the certificate through Config/Signing.local.xcconfig,
# and writes build/signing/dimsum-signing.p12 and its password, for the
# MACOS_SIGNING_P12_BASE64 and MACOS_SIGNING_P12_PASSWORD repo secrets.
set -euo pipefail

NAME="Dimsum Code Signing"
KEYCHAIN="${1:-$HOME/Library/Keychains/login.keychain-db}"
[[ "$KEYCHAIN" = /* ]] || KEYCHAIN="$PWD/$KEYCHAIN"
OUT="build/signing"
OPENSSL=/usr/bin/openssl

cd "$(dirname "$0")/.."
echo "CODE_SIGN_IDENTITY = $NAME" > Config/Signing.local.xcconfig

if security find-certificate -c "$NAME" "$KEYCHAIN" >/dev/null 2>&1; then
    echo "\"$NAME\" already exists in $KEYCHAIN"
    if [ ! -f "$OUT/dimsum-signing.p12" ]; then
        echo "No $OUT/dimsum-signing.p12. Export the identity from Keychain Access if CI needs it;"
        echo "a new certificate would not match earlier releases."
    fi
    exit 0
fi

mkdir -p "$OUT"
chmod 700 "$OUT"
cd "$OUT"

cat > cert.conf <<CONF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
CONF

PASSWORD="$($OPENSSL rand -hex 16)"
# The system LibreSSL writes a .p12 that the keychain can import.
$OPENSSL req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -config cert.conf -keyout key.pem -out cert.pem 2>/dev/null
$OPENSSL pkcs12 -export -inkey key.pem -in cert.pem \
    -name "$NAME" -passout "pass:$PASSWORD" -out dimsum-signing.p12
echo "$PASSWORD" > dimsum-signing.p12.password
rm key.pem cert.conf

security import dimsum-signing.p12 -k "$KEYCHAIN" -P "$PASSWORD" \
    -T /usr/bin/codesign
echo "Imported \"$NAME\" into $KEYCHAIN"
echo "CI secret files: $OUT/dimsum-signing.p12 and $OUT/dimsum-signing.p12.password"
