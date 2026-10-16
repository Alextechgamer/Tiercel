#!/bin/bash
# Reproducible unsigned SideStore test IPA for Tiercel Lab.
# This DOES NOT sign, install, provision or access a physical iPhone.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p LabBuild/logs LabBuild/release
xcodebuild -workspace Tiercel.xcworkspace -scheme Tiercel-iOS-Demo \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath ../tiercel-lab-device \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY='' DEVELOPMENT_TEAM='' ARCHS=arm64 ONLY_ACTIVE_ARCH=NO \
  build > LabBuild/logs/iphone-build.log 2>&1
APP="../tiercel-lab-device/Build/Products/Release-iphoneos/Tiercel-iOS-Demo.app"
test -f "$APP/Tiercel-iOS-Demo"
test -f "$APP/Frameworks/Tiercel.framework/Tiercel"
python3 - "$APP" <<'PY'
import sys,pathlib,plistlib,subprocess,re
app=pathlib.Path(sys.argv[1])
info=plistlib.loads((app/'Info.plist').read_bytes())
assert info['CFBundleIdentifier']=='com.alexsoftware.tiercellab', info
assert info['CFBundleDisplayName']=='Tiercel Lab', info
assert info['CFBundleSupportedPlatforms']==['iPhoneOS'],info
assert info['MinimumOSVersion'] >= '17.0',info
raw=subprocess.check_output(['xcrun','vtool','-show-build',str(app/'Tiercel-iOS-Demo')],text=True)
assert re.search(r'platform\s+IOS\b',raw),raw
print('PASS: physical iOS ARM64 app, unique lab bundle ID, embedded Tiercel.framework')
PY
STAGING="$(mktemp -d /tmp/tiercel-lab.XXXXXX)"
trap 'rm -rf "$STAGING"' EXIT
mkdir -p "$STAGING/Payload"
ditto "$APP" "$STAGING/Payload/Tiercel-iOS-Demo.app"
IPA="$PWD/LabBuild/release/Tiercel-Lab-v0.1.0-unsigned.ipa"
ditto -c -k --keepParent "$STAGING/Payload" "$IPA"
python3 - "$IPA" <<'PY'
import zipfile,sys,plistlib
with zipfile.ZipFile(sys.argv[1]) as z:
    assert z.testzip() is None
    names=set(z.namelist())
    assert 'Payload/Tiercel-iOS-Demo.app/Tiercel-iOS-Demo' in names
    assert 'Payload/Tiercel-iOS-Demo.app/Frameworks/Tiercel.framework/Tiercel' in names
    info=plistlib.loads(z.read('Payload/Tiercel-iOS-Demo.app/Info.plist'))
    assert info['CFBundleIdentifier']=='com.alexsoftware.tiercellab'
    print('PASS: complete IPA archive with Tiercel.framework embedded')
PY
(cd LabBuild/release && shasum -a 256 Tiercel-Lab-v0.1.0-unsigned.ipa > SHA256SUMS.txt)
echo 'Tiercel Lab IPA is UNSIGNED. Install via a compatible sideloader which signs embedded frameworks.'
echo 'iOS Simulator cannot verify actual background daemon or locked-screen transfer.'
echo "Created $IPA"
