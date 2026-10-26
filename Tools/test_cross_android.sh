#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd "$(dirname "$0")/.." && pwd)
cd "$repo_root/CrossPlatform"
flutter pub get
flutter test integration_test/native_smoke_test.dart -d emulator-5554 --reporter expanded --timeout 3m
