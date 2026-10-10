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

The GitHub workflow publishes only after the core, persistence and UI tests pass
and the unsigned device archive succeeds. See the workflow diagnostics artifact
for test logs and xcresult bundles; BUILD-ENVIRONMENT.txt identifies the commit.
EOF
(cd Delivery && shasum -a 256 TrainLog-iOS-source.zip TrainLog-unsigned.ipa BUILD-ENVIRONMENT.txt INSTALLATION.txt > SHA256SUMS.txt)
