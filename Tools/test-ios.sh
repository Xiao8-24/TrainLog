#!/bin/bash
# Run from the repository root on a Mac with Xcode and an iOS simulator installed.
set -euo pipefail
mkdir -p artifacts
swift test --package-path Packages/TrainLogCore 2>&1 | tee artifacts/core-tests.log
destination="${TRAINLOG_SIMULATOR_ID:-}"
if [ -z "$destination" ]; then
  sdk_version=$(xcrun --sdk iphonesimulator --show-sdk-version)
  destination=$(xcrun simctl list devices available -j | python3 Tools/select_simulator.py "$sdk_version" "${TRAINLOG_MINIMUM_IOS:-18}")
fi
if [ -z "$destination" ]; then
  echo "No matching iPhone simulator. Install an iOS ${TRAINLOG_MINIMUM_IOS:-18}+ runtime supported by the selected Xcode SDK." >&2
  exit 1
fi
printf '%s\n' "$destination" > artifacts/simulator-id.txt
# Use a new result bundle for every invocation; never delete previous test evidence.
result_path="artifacts/TrainLog-$(date +%Y%m%d-%H%M%S)-$$.xcresult"
xcodebuild -project TrainLog.xcodeproj -scheme TrainLog \
  -destination "platform=iOS Simulator,id=$destination" \
  -derivedDataPath DerivedData -resultBundlePath "$result_path" \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test 2>&1 | tee artifacts/ios-tests.log

# Keep actual simulator screenshots available for visual review on Windows.
if ! xcrun xcresulttool export attachments --path "$result_path" --output-path artifacts/screenshots; then
  echo "Screenshot export unavailable; attachments remain in the xcresult bundle." >&2
fi

