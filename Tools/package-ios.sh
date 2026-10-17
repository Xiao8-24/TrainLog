#!/bin/bash
# macOS/Xcode only. Produces unsigned device binaries, not an installable signed app.
set -euo pipefail
mkdir -p artifacts Delivery
archive_path="$(pwd)/artifacts/TrainLog-$(date +%Y%m%d-%H%M%S)-$$.xcarchive"
xcodebuild -project TrainLog.xcodeproj -scheme TrainLog -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$archive_path" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO archive 2>&1 | tee artifacts/archive.log
app_path="$archive_path/Products/Applications/TrainLog.app"
test -d "$app_path"
test -d "$app_path/PlugIns/TrainLogWidgets.appex"
python3 - "$app_path" <<'PY'
import pathlib, plistlib, sys
app = pathlib.Path(sys.argv[1])
info = plistlib.loads((app / 'Info.plist').read_bytes())
widget = plistlib.loads((app / 'PlugIns/TrainLogWidgets.appex/Info.plist').read_bytes())
assert info['NSSupportsLiveActivities'] is True
assert info['NSHealthUpdateUsageDescription'] and info['NSHealthShareUsageDescription']
assert widget['NSExtension']['NSExtensionPointIdentifier'] == 'com.apple.widgetkit-extension'
for key in ['CFBundleShortVersionString', 'CFBundleVersion']:
    assert info[key] == widget[key], key
print('Verified embedded widget extension, Live Activities declaration and matching versions.')
PY
python3 Tools/package_delivery.py
# Temporary staging is scoped to the workspace and removed only by the trap.
stage=$(mktemp -d "$(pwd)/Delivery/ipa-stage.XXXXXX")
trap 'rm -rf -- "$stage"' EXIT
mkdir -p "$stage/Payload"
ditto "$app_path" "$stage/Payload/TrainLog.app"
(cd "$stage" && /usr/bin/zip -qry "$(dirname "$stage")/TrainLog-unsigned.ipa" Payload)
cp artifacts/environment.txt Delivery/BUILD-ENVIRONMENT.txt
cat > Delivery/INSTALLATION.txt <<'EOF'
TrainLog preview delivery

TrainLog-iOS-source.zip: complete native Xcode source project.
TrainLog-unsigned.ipa: Release device build with NO signing certificate or profile.
The IPA cannot be installed directly on an iPhone. It needs a valid Apple signing
certificate and provisioning profile for the intended distribution method.
This is not an App Store or TestFlight release and has not passed real-device QA.
Sign BOTH the app and PlugIns/TrainLogWidgets.appex. Enable the App Group
group.com.trainlog.personal for both bundle identifiers in your Apple team,
or replace that identifier in both entitlements and WidgetSnapshotStorage.swift.
Live Activities require NSSupportsLiveActivities and system permission. Widget
refresh timing and Live Activity presentation are controlled by iOS.
Enable HealthKit for the MAIN app bundle identifier and regenerate its profile.
The widget extension does not need HealthKit. Health writes require explicit
on-device authorization. No health data is written by this unsigned package.

The GitHub workflow publishes only after the core, persistence and UI tests pass
and the unsigned device archive succeeds. See the workflow diagnostics artifact
for test logs and xcresult bundles; BUILD-ENVIRONMENT.txt identifies the commit.
EOF
(cd Delivery && shasum -a 256 TrainLog-iOS-source.zip TrainLog-unsigned.ipa BUILD-ENVIRONMENT.txt INSTALLATION.txt > SHA256SUMS.txt)
