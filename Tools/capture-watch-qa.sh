#!/bin/bash
set -euo pipefail
mkdir -p artifacts/watch
xcrun simctl list -j > artifacts/watch/simulators-before.json
watch_id=$(python3 Tools/select_watch_simulator.py < artifacts/watch/simulators-before.json)
if [[ -z "$watch_id" ]]; then
  echo 'No installed watchOS 27 runtime path; installing the Apple runtime.'
  xcodebuild -downloadPlatform watchOS -buildVersion 27.0 2>&1 | tee artifacts/watch/runtime-download.log
  xcrun simctl list -j > artifacts/watch/simulators-after.json
  watch_id=$(python3 Tools/select_watch_simulator.py < artifacts/watch/simulators-after.json)
fi
[[ -n "$watch_id" ]] || { echo 'No valid watchOS 27 runtime after installation.' >&2; exit 1; }
printf '%s\n' "$watch_id" > artifacts/watch/simulator-id.txt
app_path='DerivedData/Build/Products/Debug-watchsimulator/TrainLogWatch.app'
test -d "$app_path"
xcrun simctl boot "$watch_id" || true
xcrun simctl bootstatus "$watch_id" -b
xcrun simctl install "$watch_id" "$app_path"
xcrun simctl launch "$watch_id" com.trainlog.personal.TrainLogWatch
sleep 4
xcrun simctl io "$watch_id" screenshot artifacts/watch/TrainLog-Watch-start.png
xcrun simctl terminate "$watch_id" com.trainlog.personal.TrainLogWatch
xcrun simctl launch "$watch_id" com.trainlog.personal.TrainLogWatch --snapshot-activities
sleep 4
xcrun simctl io "$watch_id" screenshot artifacts/watch/TrainLog-Watch-activities.png
echo 'Captured actual watchOS start and selection screens; no sensor data simulated.'
