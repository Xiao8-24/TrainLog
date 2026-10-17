"""Build a portable, offline HTML and a small Windows ZIP without dependencies."""
from pathlib import Path
import hashlib
import re
import zipfile

root = Path(__file__).resolve().parents[1]
source = root / "WindowsPreview"
delivery = root / "Delivery"
delivery.mkdir(exist_ok=True)
html = (source / "index.html").read_text(encoding="utf-8")
html = html.replace('<link rel="stylesheet" href="style.css">', '<style>\n' + (source / "style.css").read_text(encoding="utf-8") + '\n</style>')
scripts = []
for name in ["catalog.js", "core.js", "app.js"]:
    html = html.replace(f'<script defer src="{name}"></script>', '')
    scripts.append('<script>\n' + (source / name).read_text(encoding="utf-8") + '\n</script>')
html = html.replace('</body>', '\n'.join(scripts) + '\n</body>')
assert not re.search(r'<(?:script|link)\b[^>]*(?:src|href)=', html)
standalone = delivery / "TrainLog-Windows-Preview.html"
standalone.write_bytes(html.encode("utf-8"))
readme = """TrainLog Windows 交互预览

解压后双击「打开 TrainLog.cmd」，或直接用 Edge / Chrome / Firefox 打开 index.html。
也可单独打开发布的 TrainLog-Windows-Preview.html；无须安装，无须联网。

首次带有演示记录，可在「预览设置」中清空或重新载入。
本地预览支持训练、草稿、日历、肌群图、趋势和小组件／灵动岛状态演示。
数据仅保存在当前浏览器的本地存储，不与 iPhone 同步。
请解压到固定位置后使用；移动 HTML 或更换浏览器，可能使用新的存储位置。
导出的 JSON 仅为此 Windows 预览专用，不是原生 iOS 备份格式。

这是交互预览，不是 SwiftUI 的 Windows 移植；Apple 原生玻璃与系统组件需要 iPhone。
"""
archive = delivery / "TrainLog-Windows-Preview.zip"
with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    z.writestr("TrainLog-Windows-Preview/index.html", html.encode("utf-8"))
    z.writestr("TrainLog-Windows-Preview/打开 TrainLog.cmd", (source / "打开 TrainLog.cmd").read_bytes())
    z.writestr("TrainLog-Windows-Preview/使用说明.txt", readme.encode("utf-8-sig"))
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    assert z.read("TrainLog-Windows-Preview/index.html") == standalone.read_bytes()
lines = []
for file in [standalone, archive]:
    digest = hashlib.sha256(file.read_bytes()).hexdigest()
    lines.append(f"{digest}  {file.name}")
    print(f"{file.name}: {file.stat().st_size:,} bytes; SHA256 {digest}")
(delivery / "TrainLog-Windows-Preview-SHA256.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
