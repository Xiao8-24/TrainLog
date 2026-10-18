#!/bin/bash
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
  cat artifacts/watch/boot-before.log
  echo 'Installed runtime metadata is unusable; download and import an Apple runtime.'
  runtime_dir="$RUNNER_TEMP/trainlog-watch-runtime"
  mkdir -p "$runtime_dir"
  xcodebuild -downloadPlatform watchOS -buildVersion 27.0 -exportPath "$runtime_dir" 2>&1 | tee artifacts/watch/runtime-download.log
  runtime_image=$(find "$runtime_dir" -type f -name '*.dmg' -print -quit)
  [[ -n "$runtime_image" ]] || { echo 'No exported runtime disk image.' >&2; exit 1; }
  xcodebuild -importPlatform "$runtime_image" 2>&1 | tee artifacts/watch/runtime-import.log
  watch_id=$(select_watch after)
  boot_watch > artifacts/watch/boot-after.log 2>&1 || { cat artifacts/watch/boot-after.log; exit 1; }
fi
printf '%s\n' "$watch_id" > artifacts/watch/simulator-id.txt
app_path='DerivedData/Build/Products/Debug-watchsimulator/TrainLogWatch.app'
test -d "$app_path"
xcrun simctl install "$watch_id" "$app_path"
xcrun simctl launch "$watch_id" com.trainlog.personal.TrainLogWatch
sleep 4
xcrun simctl io "$watch_id" screenshot artifacts/watch/TrainLog-Watch-start.png
xcrun simctl terminate "$watch_id" com.trainlog.personal.TrainLogWatch
xcrun simctl launch "$watch_id" com.trainlog.personal.TrainLogWatch --snapshot-activities
sleep 4
xcrun simctl io "$watch_id" screenshot artifacts/watch/TrainLog-Watch-activities.png
echo 'Captured actual watchOS screens; no sensor data simulated.'
