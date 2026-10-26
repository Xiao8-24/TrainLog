"""Package only the complete Windows runner, including its redistributable DLLs."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
import subprocess
import zipfile

p = argparse.ArgumentParser()
p.add_argument('--platform', choices=['windows', 'android'], required=True)
args = p.parse_args()
root = Path(__file__).resolve().parents[1]
out = root / 'artifacts/cross-delivery'
out.mkdir(parents=True, exist_ok=True)
if args.platform == 'windows':
    source = root / 'CrossPlatform/build/windows/x64/runner/Release'
    assert (source / 'trainlog.exe').is_file() and (source / 'flutter_windows.dll').is_file()
    assert (source / 'data/flutter_assets').is_dir()
    vswhere = Path('C:/Program Files (x86)/Microsoft Visual Studio/Installer/vswhere.exe')
    install = Path(subprocess.check_output([str(vswhere), '-latest', '-products', '*', '-property', 'installationPath'], text=True).strip())
    redists = sorted((install / 'VC/Redist/MSVC').glob('*/x64/Microsoft.VC*.CRT'))
    assert redists, 'VC++ redistributable libraries not found'
    for dll in redists[-1].glob('*.dll'):
        shutil.copyfile(dll, source / dll.name)
    assert (source / 'vcruntime140.dll').is_file() and (source / 'msvcp140.dll').is_file()
    (source / '使用说明.txt').write_text('TrainLog Windows 预览版 0.10.0\n\n完整解压后运行 trainlog.exe。请保留 DLL 和 data 文件夹。\n支持 Windows 10/11 x64。未作商业代码签名，Windows 可能显示来源提示。\n资料保存在本机应用数据目录，与程序文件夹分开。卸载前在设置中导出备份。\n本版不连接 Apple Watch，不同步 Apple 健身。\n', encoding='utf-8')
    name = 'TrainLog-v0.10.0-Windows-x64.zip'
    with zipfile.ZipFile(out / name, 'w', zipfile.ZIP_DEFLATED) as z:
        for file in sorted(source.rglob('*')):
            if file.is_file(): z.write(file, 'TrainLog/' + file.relative_to(source).as_posix())
else:
    source = root / 'CrossPlatform/build/app/outputs/flutter-apk'
    for abi in ['arm64-v8a', 'armeabi-v7a', 'x86_64']:
        file = source / f'app-{abi}-release.apk'
        assert file.is_file()
        shutil.copyfile(file, out / f'TrainLog-v0.10.0-Android-{abi}-preview.apk')
report = []
for file in sorted(out.iterdir()):
    if file.suffix in ['.apk', '.zip']:
        report.append({'name': file.name, 'bytes': file.stat().st_size, 'sha256': hashlib.file_digest(file.open('rb'), 'sha256').hexdigest()})
(out / f'{args.platform}-checksums.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps(report, indent=2))
