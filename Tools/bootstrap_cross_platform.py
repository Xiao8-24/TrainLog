"""Configure Flutter-generated platform runners; fail if template contracts change."""
from pathlib import Path
import shutil
import re

root = Path(__file__).resolve().parents[1]
app = root / 'CrossPlatform'
default_test = app / 'test/widget_test.dart'
if default_test.exists():
    sample = default_test.read_text(encoding='utf-8')
    if 'MyApp' in sample and 'counter' in sample.lower():
        default_test.unlink()  # Only Flutter's newly generated counter example.
gradle = app / 'android/app/build.gradle.kts'
text = gradle.read_text(encoding='utf-8')
assert 'minSdk = flutter.minSdkVersion' in text
text = text.replace('minSdk = flutter.minSdkVersion', 'minSdk = 24')
# These are explicitly preview APKs signed with Android's development key.
# Production keystores must be supplied via CI secrets in a future store release.
assert 'signingConfigs.getByName("debug")' in text
gradle.write_text(text, encoding='utf-8')
activity = app / 'android/app/src/main/kotlin/app/trainlog/trainlog/MainActivity.kt'
assert activity.exists()
shutil.copyfile(app / 'platform/android/MainActivity.kt', activity)
manifest = app / 'android/app/src/main/AndroidManifest.xml'
text = manifest.read_text(encoding='utf-8').replace('android:label="trainlog"', 'android:label="TrainLog"')
# Do not allow Android cloud backup of health and workout records by default.
text = text.replace('<application', '<application android:allowBackup="false"', 1)
manifest.write_text(text, encoding='utf-8')
rc = app / 'windows/runner/Runner.rc'
text = rc.read_text(encoding='utf-8').replace('"trainlog"', '"TrainLog"').replace('"trainlog\\0"', '"TrainLog\\0"')
rc.write_text(text, encoding='utf-8')
main = app / 'windows/runner/main.cpp'
text = main.read_text(encoding='utf-8').replace('L"trainlog"', 'L"TrainLog"')
main.write_text(text, encoding='utf-8')
# System-drawn title bar and window frame retain native minimize/maximize/snap.
print('Configured Android API 24+, document export and native Windows runner')
