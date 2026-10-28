#!/bin/bash
set -euo pipefail

# Separate Debug app: does not rewrite the real project's signing team, flags or app ID.
# Usage: scripts/run-ar-field-test-ios.sh TEAM_ID DEVICE_UDID
field_team="${1:?Pass the signing Team ID}"
field_device="${2:?Pass the device UDID or CoreDevice identifier}"
field_repo="$(cd "$(dirname "$0")/.." && pwd)"
field_root="$(mktemp -d /tmp/coordit-ar-field.XXXXXX)"
field_bundle="com.insihwan.coordit.arfieldtest"
field_project="$field_root/coordit.xcodeproj"
field_derived="${COORDIT_AR_FIELD_DERIVED_DATA:-$field_root/DerivedData}"

mkdir -p "$field_project"
cp "$field_repo/coordit/coordit.xcodeproj/project.pbxproj" "$field_project/project.pbxproj"
cp -R "$field_repo/coordit/coordit.xcodeproj/xcshareddata" "$field_project/"
cp -R "$field_repo/coordit/coordit.xcodeproj/project.xcworkspace" "$field_project/"
for field_directory in coordit CoorditShareExtension coorditTests coorditUITests; do
    ln -s "$field_repo/coordit/$field_directory" "$field_root/$field_directory"
done
cp "$field_repo/coordit/coordit/Info.plist" "$field_root/ARFieldTest-Info.plist"
cat > "$field_root/ARFieldTest.entitlements" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict/></plist>
PLIST
/usr/libexec/PlistBuddy -c 'Add :CoorditARFieldTestBuild bool true' "$field_root/ARFieldTest-Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleDisplayName string Coordit AR Test' "$field_root/ARFieldTest-Info.plist"
if [[ -n "${COORDIT_HOSTED_AR_CONNECTION_FILE:-}" ]]; then
    /usr/bin/python3 - "$COORDIT_HOSTED_AR_CONNECTION_FILE" "$field_root/ARFieldTest-Info.plist" <<'PY'
import json, plistlib, sys
from pathlib import Path
connection = json.loads(Path(sys.argv[1]).read_text())
if not connection["url"].startswith("https://") or len(connection["token"]) < 32:
    raise SystemExit("Invalid development gateway connection")
path = Path(sys.argv[2])
info = plistlib.loads(path.read_bytes())
info["CoorditHostedARBaseURL"] = connection["url"]
info["CoorditHostedARGatewayToken"] = connection["token"]
path.write_bytes(plistlib.dumps(info))
PY
fi
perl -pi -e 's/com\.inseong\.coordit\.CoorditShareExtension/com.insihwan.coordit.arfieldtest.CoorditShareExtension/g; s/PRODUCT_BUNDLE_IDENTIFIER = com\.inseong\.coordit;/PRODUCT_BUNDLE_IDENTIFIER = com.insihwan.coordit.arfieldtest;/g; s/INFOPLIST_FILE = coordit\/Info.plist;/INFOPLIST_FILE = ARFieldTest-Info.plist;/g; s/CODE_SIGN_ENTITLEMENTS = [^;]+;/CODE_SIGN_ENTITLEMENTS = ARFieldTest.entitlements;/g' "$field_project/project.pbxproj"

echo "Temporary project: $field_root"
echo "Building separate Debug app: $field_bundle (team $field_team)"
field_destination="${COORDIT_AR_FIELD_DESTINATION:-platform=iOS,id=$field_device}"
if ! xcodebuild build -project "$field_project" -scheme coordit -configuration Debug \
    -destination "$field_destination" -destination-timeout 25 -derivedDataPath "$field_derived" \
    -allowProvisioningUpdates -allowProvisioningDeviceRegistration CODE_SIGN_STYLE=Automatic \
    DEVELOPMENT_TEAM="$field_team" CODE_SIGN_ENTITLEMENTS="$field_root/ARFieldTest.entitlements" > "$field_root/build.log" 2>&1; then
    tail -35 "$field_root/build.log"
    exit 1
fi
field_app="$field_derived/Build/Products/Debug-iphoneos/coordit.app"
echo "Device build passed: $field_app"
if [[ "${COORDIT_AR_FIELD_BUILD_ONLY:-0}" == "1" ]]; then
    exit 0
fi
xcrun devicectl device install app --device "$field_device" "$field_app" --timeout 60 \
    --json-output "$field_root/install.json"
xcrun devicectl device process launch --device "$field_device" "$field_bundle" --timeout 30 \
    --json-output "$field_root/launch.json" -- --coordit-ar-field-test
echo "Installed and launched. Build/install/launch evidence: $field_root"
