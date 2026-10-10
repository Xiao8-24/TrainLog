#!/bin/bash
# Run from the repository root on a Mac with Xcode and an iOS simulator installed.
set -euo pipefail
mkdir -p artifacts
swift test --package-path Packages/TrainLogCore 2>&1 | tee artifacts/core-tests.log
destination="${TRAINLOG_SIMULATOR_ID:-}"
if [ -z "$destination" ]; then
  destination=$(xcrun simctl list devices available -j | python3 -c 'import json,sys,re; d=json.load(sys.stdin)["devices"]; candidates=[(tuple(map(int,re.search(r"iOS-([0-9-]+)",runtime).group(1).split("-"))),x["udid"]) for runtime,items in d.items() if re.search(r"iOS-([0-9-]+)",runtime) for x in items if x.get("isAvailable") and "iPhone" in x["name"]]; candidates=sorted([x for x in candidates if x[0]>=(18,)],reverse=True); print(candidates[0][1] if candidates else "")')
fi
if [ -z "$destination" ]; then
  echo "No available iPhone simulator. Install an iOS 18 or newer simulator in Xcode." >&2
  exit 1
fi
printf '%s\n' "$destination" > artifacts/simulator-id.txt
# Use a new result bundle for every invocation; never delete previous test evidence.
result_path="artifacts/TrainLog-$(date +%Y%m%d-%H%M%S)-$$.xcresult"
xcodebuild -project TrainLog.xcodeproj -scheme TrainLog \
  -destination "platform=iOS Simulator,id=$destination" \
  -derivedDataPath DerivedData -resultBundlePath "$result_path" \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test 2>&1 | tee artifacts/ios-tests.log

