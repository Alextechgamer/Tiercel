#!/bin/bash
# Standalone Tiercel Lab iOS 26 Simulator smoke test. This is not an actual
# background-daemon acceptance test; physical iOS always keeps background URLSession.
set -euo pipefail
cd "$(dirname "$0")"
ROOT="$(pwd)"
EVIDENCE="$ROOT/LabEvidence"
mkdir -p "$EVIDENCE"
FREE="$(df -Pk "$ROOT" | awk 'NR==2 {print $4}')"
if [ "$FREE" -lt 4194304 ]; then
  echo "Insufficient Mac disk space for a disposable iOS Simulator" >&2; exit 2
fi
UDID="$(xcrun simctl create "Tiercel-Lab-Isolated-20261016" \
  com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max \
  com.apple.CoreSimulator.SimRuntime.iOS-26-0)"
echo "Disposable Simulator: $UDID"
cleanup() {
  xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true
  xcrun simctl delete "$UDID" >/dev/null 2>&1 || true
  echo "Deleted only disposable Tiercel Lab simulator: $UDID"
}
trap cleanup EXIT
xcodebuild -workspace Tiercel.xcworkspace -scheme Tiercel-iOS-Demo \
  -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$ROOT/../tiercel-lab-sim-derived" \
  CODE_SIGNING_ALLOWED=NO build > "$EVIDENCE/simulator-build.log" 2>&1
APP="$ROOT/../tiercel-lab-sim-derived/Build/Products/Debug-iphonesimulator/Tiercel-iOS-Demo.app"
test -f "$APP/Tiercel-iOS-Demo"
xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b > "$EVIDENCE/bootstatus.txt" 2>&1
xcrun simctl install "$UDID" "$APP"
CONTAINER="$(xcrun simctl get_app_container "$UDID" com.alexsoftware.tiercellab data)"
RECEIPT="$CONTAINER/Documents/TiercelLab-Simulator-Result.json"
SIMCTL_CHILD_TIERCEL_LAB_AUTORUN=1 \
  xcrun simctl launch "$UDID" com.alexsoftware.tiercellab \
  > "$EVIDENCE/launch.txt" 2>&1
for ((i=0; i<90; i++)); do
  if test -f "$RECEIPT"; then
    cp "$RECEIPT" "$EVIDENCE/latest-result.json"
    if python3 - "$EVIDENCE/latest-result.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1]))
raise SystemExit(0 if x.get("status","").lower() in ("succeeded","failed","canceled") else 1)
PY
    then break; fi
  fi
  sleep 1
done
test -f "$EVIDENCE/latest-result.json"
cat "$EVIDENCE/latest-result.json"
xcrun simctl io "$UDID" screenshot "$EVIDENCE/tiercel-lab-simulator.png" >/dev/null
python3 - "$EVIDENCE/latest-result.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1]))
assert x.get('status')=='Succeeded',x
assert x.get('savedFileBytes')==1048576,x
assert x.get('receivedBytes')==1048576,x
assert len(x.get('sha256',''))==64,x
assert x.get('errorCode')=='—',x
print("PASS: Tiercel Lab downloaded 1 MiB, saved a real file, calculated SHA-256 on iOS Simulator.")
PY
