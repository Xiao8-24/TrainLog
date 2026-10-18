#!/bin/bash
# Run from the repository root on a Mac with Xcode and an iOS simulator installed.
set -euo pipefail
mkdir -p artifacts
swift test --package-path Packages/TrainLogCore 2>&1 | tee artifacts/core-tests.log
destination="${TRAINLOG_SIMULATOR_ID:-}"
if [ -z "$destination" ]; then
  sdk_version=$(xcrun --sdk iphonesimulator --show-sdk-version)
  destination=$(xcrun simctl list devices available -j | python3 Tools/select_simulator.py "$sdk_version" "${TRAINLOG_MINIMUM_IOS:-27}")
fi
if [ -z "$destination" ]; then
  echo "No matching iPhone simulator. Install an iOS ${TRAINLOG_MINIMUM_IOS:-27}+ runtime supported by the selected Xcode SDK." >&2
  exit 1
fi
printf '%s\n' "$destination" > artifacts/simulator-id.txt
collect_url_diagnostics() {
  xcrun simctl spawn "$destination" log show --last 20m --style compact \
    --predicate 'eventMessage CONTAINS "TrainLog UI URL"' > artifacts/url-routing.log 2>&1 || true
}
trap collect_url_diagnostics EXIT
# Use a new result bundle for every invocation; never delete previous test evidence.
result_path="artifacts/TrainLog-$(date +%Y%m%d-%H%M%S)-$$.xcresult"
# Fail compiler errors before launching a test session or collecting simulator
# diagnostics. Reuse the exact products for the subsequent test execution.
xcodebuild -project TrainLog.xcodeproj -scheme TrainLog \
  -destination "platform=iOS Simulator,id=$destination" \
  -derivedDataPath DerivedData -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- build-for-testing 2>&1 | tee artifacts/build-for-testing.log
test_args=(test-without-building)
# Xcode's optional simulator diagnostics timed out for 600 seconds after a
# successful run. Keep xcresult outcomes and explicit screenshots; skip that
# extra collection only when this Xcode advertises the supported option.
xcodebuild -help > artifacts/xcodebuild-help.txt 2>&1 || true
if grep -q -- '-collect-test-diagnostics' artifacts/xcodebuild-help.txt; then
  test_args+=(-collect-test-diagnostics never)
fi
xcodebuild -project TrainLog.xcodeproj -scheme TrainLog \
  -destination "platform=iOS Simulator,id=$destination" \
  -derivedDataPath DerivedData -resultBundlePath "$result_path" \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- "${test_args[@]}" 2>&1 | tee artifacts/ios-tests.log

# Keep actual simulator screenshots available for visual review on Windows.
if ! xcrun xcresulttool export attachments --path "$result_path" --output-path artifacts/screenshots; then
  echo "Screenshot export unavailable; attachments remain in the xcresult bundle." >&2
fi

