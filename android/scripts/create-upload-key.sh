#!/usr/bin/env bash
set -euo pipefail
umask 077
cd "$(dirname "$0")/.."
if [[ -e signing/coordit-upload.p12 || -e signing/release.properties ]]; then
    echo 'An upload key or signing configuration already exists. Reusing it requires no key generation.' >&2
    exit 1
fi
mkdir -p signing
export COORDIT_UPLOAD_PASSWORD
COORDIT_UPLOAD_PASSWORD=$(openssl rand -hex 24)
"${JAVA_HOME:?Set JAVA_HOME to JDK 17 or newer}/bin/keytool" -genkeypair \
    -keystore signing/coordit-upload.p12 -storetype PKCS12 \
    -storepass:env COORDIT_UPLOAD_PASSWORD -keypass:env COORDIT_UPLOAD_PASSWORD \
    -alias coordit-upload -keyalg RSA -keysize 3072 -validity 10000 \
    -dname 'CN=Coordit Upload, OU=Android, O=Coordit, C=KR'
printf 'storeFile=signing/coordit-upload.p12\nstorePassword=%s\nkeyAlias=coordit-upload\nkeyPassword=%s\n' \
    "$COORDIT_UPLOAD_PASSWORD" "$COORDIT_UPLOAD_PASSWORD" > signing/release.properties
"$JAVA_HOME/bin/keytool" -exportcert -rfc -keystore signing/coordit-upload.p12 \
    -storepass:env COORDIT_UPLOAD_PASSWORD -alias coordit-upload -file signing/upload-certificate.pem
unset COORDIT_UPLOAD_PASSWORD
echo 'Created signing/coordit-upload.p12, signing/release.properties, and signing/upload-certificate.pem. Back up the signing directory privately.'
