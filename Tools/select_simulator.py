"""Select an available iPhone runtime no newer than the selected Xcode SDK."""
import json
import re
import sys

sdk = tuple(map(int, sys.argv[1].split(".")))
candidates = []
for runtime, devices in json.load(sys.stdin)["devices"].items():
    match = re.search(r"iOS-([0-9-]+)$", runtime)
    if not match:
        continue
    version = tuple(map(int, match[1].split("-")))
    if not (18,) <= version <= sdk:
        continue
    for device in devices:
        if device.get("isAvailable") and "iPhone" in device["name"]:
            candidates.append((version, device["name"], device["udid"]))
print(max(candidates)[2] if candidates else "")
