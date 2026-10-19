#!/bin/bash
# Native UI evidence only; never fabricates sensor measurements.
set -euo pipefail
mkdir -p artifacts/watch
select_watch() {
  xcrun simctl list -j > "artifacts/watch/simulators-$1.json"
  python3 Tools/select_watch_simulator.py < "artifacts/watch/simulators-$1.json"
}
boot_watch() {
  [[ -n "$watch_id" ]] || return 1
  xcrun simctl boot "$watch_id" || true
  xcrun simctl bootstatus "$watch_id" -b
}
watch_id=$(select_watch before)
if ! boot_watch > artifacts/watch/boot-before.log 2>&1; then
  runtime_dir="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/trainlog-watch-runtime"
  mkdir -p "$runtime_dir"
  # Xcode may export a usable bundle yet report code 70 for a stale install.
  xcodebuild -downloadPlatform watchOS -buildVersion 27.0 -exportPath "$runtime_dir" 2>&1 | tee artifacts/watch/runtime-download.log || download_status=$?
  echo "Apple download exit status: ${download_status:-0}"
  runtime_image=$(find "$runtime_dir" \( -name '*.dmg' -o -name '*.exportedBundle' \) -print -quit)
  [[ -n "$runtime_image" ]] || { echo 'No exported Apple runtime.' >&2; exit 1; }
  xcodebuild -importPlatform "$runtime_image" 2>&1 | tee artifacts/watch/runtime-import.log
  watch_id=$(select_watch after)
  boot_watch > artifacts/watch/boot-after.log 2>&1 || { cat artifacts/watch/boot-after.log; exit 1; }
fi
printf '%s\n' "$watch_id" > artifacts/watch/simulator-id.txt
app_path='DerivedData/Build/Products/Debug-watchsimulator/TrainLogWatch.app'
test -d "$app_path"
xcrun simctl install "$watch_id" "$app_path"
xcrun simctl launch "$watch_id" com.trainlog.personal.TrainLogWatch
sleep 25
xcrun simctl io "$watch_id" screenshot artifacts/watch/TrainLog-Watch-start.png
xcrun simctl terminate "$watch_id" com.trainlog.personal.TrainLogWatch
sleep 3
launch_output=$(xcrun simctl launch "$watch_id" com.trainlog.personal.TrainLogWatch --snapshot-activities)
echo "$launch_output"
sleep 25
xcrun simctl io "$watch_id" screenshot artifacts/watch/TrainLog-Watch-activities.png
app_pid="${launch_output##*: }"
if [[ "$app_pid" =~ ^[0-9]+$ ]]; then sample "$app_pid" 2 -file artifacts/watch/selection-sample.txt || true; fi
xcrun simctl spawn "$watch_id" log show --last 3m --style compact --predicate 'process == "TrainLogWatch"' > artifacts/watch/selection-system.log 2>&1 || true
echo 'Captured native app and value-based navigation; no alternate preview host.'
