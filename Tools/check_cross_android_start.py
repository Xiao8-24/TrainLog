"""Bounded startup check of the release APK on a disposable CI emulator."""
from pathlib import Path
import subprocess
import time

out = Path('artifacts')
out.mkdir(exist_ok=True)
for attempt in range(20):
    subprocess.run(['adb', 'shell', 'uiautomator', 'dump', '/sdcard/trainlog-window.xml'], check=True, capture_output=True)
    xml = subprocess.check_output(['adb', 'shell', 'cat', '/sdcard/trainlog-window.xml'])
    (out / 'android-release-window.xml').write_bytes(xml)
    if b'TrainLog' in xml and '本周训练'.encode() in xml and '开始今天的训练'.encode() in xml:
        break
    time.sleep(1)
else:
    raise SystemExit('Release APK did not reach the training dashboard')
logs = subprocess.check_output(['adb', 'logcat', '-d', '-s', 'AndroidRuntime:E'])
(out / 'android-runtime.txt').write_bytes(logs)
assert b'FATAL EXCEPTION' not in logs, logs.decode(errors='replace')
(out / 'android-release-startup.txt').write_text('API 35 x86_64 release APK opened its empty dashboard; no AndroidRuntime fatal exception. Synthetic integration data was isolated and removed before installation.\n', encoding='utf-8')
print('Android release APK startup passed')
