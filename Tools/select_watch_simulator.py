"""Choose a genuinely installed watchOS 27 runtime, not stale device metadata."""
from pathlib import Path
import json
import subprocess
import sys

state = json.load(sys.stdin)
runtimes = [runtime for runtime in state.get('runtimes', [])
            if runtime.get('isAvailable') and 'watchOS' in runtime.get('identifier', '')
            and runtime.get('version', '').split('.')[0] == '27'
            and runtime.get('bundlePath') and Path(runtime['bundlePath']).is_dir()]
if not runtimes:
    sys.exit(0)
for runtime in runtimes:
    devices = [device for device in state.get('devices', {}).get(runtime['identifier'], []) if device.get('isAvailable')]
    devices.sort(key=lambda device: ('Ultra' not in device['name'], device['name']))
    if devices:
        print(devices[0]['udid'])
        sys.exit(0)
types = [value for value in state.get('devicetypes', []) if 'Apple Watch' in value.get('name', '')]
types.sort(key=lambda value: ('Ultra' not in value['name'], value['name']))
if types:
    print(subprocess.check_output(['xcrun', 'simctl', 'create', 'TrainLog Watch QA', types[0]['identifier'], runtimes[0]['identifier']], text=True).strip())
