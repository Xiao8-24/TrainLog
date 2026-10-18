#!/bin/bash
# Visual evidence only. A simulator cannot validate real physiological sensors.
set -euo pipefail
mkdir -p artifacts/watch
watch_id=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
candidates = [d for runtime, group in devices.items() if "watchOS-27" in runtime for d in group if d.get("isAvailable")]
candidates.sort(key=lambda d: ("Ultra" not in d["name"], d["name"]))
if candidates: print(candidates[0]["udid"])
')
if [[ -z "$watch_id" ]]; then
  echo 'watchOS 27 simulator unavailable; no Watch screenshot captured.' >&2
  exit 1
fi
printf '%s\n' "$watch_id" > artifacts/watch/simulator-id.txt
app_path="DerivedData/Build/Products/Debug-watchsimulator/TrainLogWatch.app"
test -d "$app_path"
xcrun simctl boot "$watch_id" || true
xcrun simctl bootstatus "$watch_id" -b
xcrun simctl install "$watch_id" "$app_path"
xcrun simctl launch "$watch_id" com.trainlog.personal.TrainLogWatch
sleep 3
xcrun simctl io "$watch_id" screenshot artifacts/watch/TrainLog-Watch-start.png
xcrun simctl terminate "$watch_id" com.trainlog.personal.TrainLogWatch
xcrun simctl launch "$watch_id" com.trainlog.personal.TrainLogWatch --snapshot-activities
sleep 3
xcrun simctl io "$watch_id" screenshot artifacts/watch/TrainLog-Watch-activities.png
echo 'Native watchOS start screen captured. No sensor values were simulated.'
