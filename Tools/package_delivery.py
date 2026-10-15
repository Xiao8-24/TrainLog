"""Package only deliverable source/resources, then verify every archived byte."""
from pathlib import Path
import hashlib
import zipfile

root = Path(__file__).resolve().parents[1]
delivery = root / "Delivery"
delivery.mkdir(exist_ok=True)
folders = ["TrainLog", "TrainLogWidgets", "Shared", "TrainLog.xcodeproj", "Packages", "TrainLogTests", "TrainLogUITests", "Tools", "Documentation", ".github"]
files = [root / "README.md", root / ".gitignore", root / ".gitattributes"]
excluded = {".build", ".swiftpm", "xcuserdata", "__pycache__", ".DS_Store"}
for folder in folders:
    files += [p for p in (root / folder).rglob("*") if p.is_file() and not set(p.parts).intersection(excluded)]
archive = delivery / "TrainLog-iOS-source.zip"
with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    for file in sorted(files):
        z.write(file, "TrainLog/" + file.relative_to(root).as_posix())
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    for file in files:
        archived = z.read("TrainLog/" + file.relative_to(root).as_posix())
        assert hashlib.sha256(archived).digest() == hashlib.sha256(file.read_bytes()).digest(), file
digest = hashlib.sha256(archive.read_bytes()).hexdigest()
(delivery / "SHA256SUMS.txt").write_text(f"{digest}  {archive.name}\n", encoding="utf-8")
print(f"Verified {len(files)} archived files; {archive.stat().st_size:,} bytes; SHA256 {digest}")

