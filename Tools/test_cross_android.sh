#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd "$(dirname "$0")/.." && pwd)
cd "$repo_root/CrossPlatform"
flutter pub get
flutter test integration_test/native_smoke_test.dart -d emulator-5554 --reporter expanded --timeout 3m
cd "$repo_root"
# Only the disposable CI emulator's synthetic test installation is removed.
adb uninstall app.trainlog.trainlog
adb install artifacts/apks/TrainLog-v0.10.0-Android-x86_64-preview.apk
adb shell am start -W -n app.trainlog.trainlog/.MainActivity
python Tools/check_cross_android_start.py
