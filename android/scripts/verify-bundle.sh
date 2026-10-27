#!/usr/bin/env bash
set -euo pipefail
umask 077
cd "$(dirname "$0")/.."
: "${JAVA_HOME:?Set JAVA_HOME to JDK 17 or newer}"
: "${ANDROID_HOME:?Set ANDROID_HOME to your Android SDK}"
: "${BUNDLETOOL_JAR:?Set BUNDLETOOL_JAR to bundletool-all.jar}"
bundle=app/build/outputs/bundle/release/app-release.aab
output=${1:-../deliverables/android}
mkdir -p "$output"
signing_properties=${COORDIT_SIGNING_PROPERTIES:-signing/release.properties}
while IFS='=' read -r key value; do
    case "$key" in
        storeFile) upload_store=$value ;;
        storePassword) upload_password=$value ;;
        keyAlias) upload_alias=$value ;;
        keyPassword) upload_key_password=$value ;;
    esac
done < "$signing_properties"
password_file=$(mktemp)
key_password_file=$(mktemp)
trap 'rm -f "$password_file" "$key_password_file"' EXIT
printf '%s\n' "$upload_password" > "$password_file"
printf '%s\n' "$upload_key_password" > "$key_password_file"
"$JAVA_HOME/bin/java" -jar "$BUNDLETOOL_JAR" validate --bundle="$bundle" > "$output/bundle-validation.log" 2>&1
"$JAVA_HOME/bin/jarsigner" -verify "$bundle" > "$output/bundle-signature.log" 2>&1
"$JAVA_HOME/bin/java" -jar "$BUNDLETOOL_JAR" dump config --bundle="$bundle" > "$output/bundle-config.json"
"$JAVA_HOME/bin/java" -jar "$BUNDLETOOL_JAR" dump manifest --bundle="$bundle" > "$output/AndroidManifest.xml"
"$JAVA_HOME/bin/java" -jar "$BUNDLETOOL_JAR" build-apks --bundle="$bundle" \
    --output="$output/coordit-release.apks" --overwrite --mode=universal \
    --ks="$upload_store" --ks-key-alias="$upload_alias" \
    --ks-pass="file:$password_file" --key-pass="file:$key_password_file" > "$output/apk-generation.log" 2>&1
unzip -p "$output/coordit-release.apks" universal.apk > "$output/coordit-1.0.1-release.apk"
"$ANDROID_HOME/build-tools/35.0.0/zipalign" -c -P 16 -v 4 "$output/coordit-1.0.1-release.apk" > "$output/apk-alignment.log"
"$ANDROID_HOME/build-tools/35.0.0/apksigner" verify --verbose --print-certs "$output/coordit-1.0.1-release.apk" > "$output/apk-signature.log"
cp "$bundle" "$output/coordit-1.0.1-release.aab"
shasum -a 256 "$output/coordit-1.0.1-release.aab" "$output/coordit-1.0.1-release.apk" > "$output/SHA256SUMS.txt"
echo "Verified signed App Bundle and generated an installable APK in $output"
