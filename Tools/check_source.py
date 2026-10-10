"""Static packaging and optional Swift grammar checks, not an SDK build or test run."""
from pathlib import Path
from datetime import datetime, timezone, timedelta
import json
import plistlib
import re
import sys
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / ".tools" / "python"))
failures = []
swift = sorted(p for folder in ["TrainLog", "TrainLogTests", "TrainLogUITests", "Packages"] for p in (root / folder).rglob("*.swift"))
for path in (root / "TrainLog" / "Resources").glob("*.plist"):
    with path.open("rb") as file: plistlib.load(file)
for path in (root / "TrainLog" / "Resources").glob("*.xcprivacy"):
    with path.open("rb") as file: plistlib.load(file)
for path in (root / "TrainLog.xcodeproj").rglob("*.xcscheme"): ET.parse(path)
for path in (root / "TrainLog.xcodeproj").rglob("*.xcworkspacedata"): ET.parse(path)
for path in (root / "TrainLog" / "Resources").rglob("Contents.json"): json.loads(path.read_text())
project = (root / "TrainLog.xcodeproj" / "project.pbxproj").read_text(encoding="utf-8")
definitions = re.findall(r"^\s*([A-F0-9]{24}) = \{", project, re.M)
if len(definitions) != len(set(definitions)): failures.append("Duplicate project object ID")
for identifier in set(re.findall(r"\b[A-F0-9]{24}\b", project)):
    if identifier not in definitions: failures.append("Unresolved project object " + identifier)
for path in swift:
    if "Packages" not in path.parts and path.relative_to(root).as_posix() not in project: failures.append("Source missing from target: " + str(path))
syntax_checked = False
try:
    from tree_sitter import Language, Parser
    import tree_sitter_swift
    parser = Parser(Language(tree_sitter_swift.language()))
    syntax_checked = True
    for path in swift:
        data = path.read_bytes()
        tree = parser.parse(data)
        def errors(node):
            if node.type == "ERROR" or node.is_missing:
                yield f"{path.relative_to(root)}:{node.start_point.row + 1}:{node.start_point.column + 1}: {node.type}: {data[node.start_byte:node.end_byte][:140].decode(errors='replace')}"
            for child in node.children:
                yield from errors(child)
        failures.extend(errors(tree.root_node))
except ImportError:
    print("Swift grammar parser unavailable; install tree-sitter and tree-sitter-swift to enable syntax checks.")
report = {"swift_files": len(swift), "project_objects": len(definitions), "swift_grammar_checked": syntax_checked, "failures": failures, "apple_sdk_build": "NOT RUN", "swift_tests": "NOT RUN", "ui_tests": "NOT RUN"}
report["test_methods_written"] = sum(len(re.findall(r"func test\w+\(", p.read_text(encoding="utf-8"))) for p in swift)
report["checked_date"] = datetime.now(timezone(timedelta(hours=8))).date().isoformat()
if "--write-report" in sys.argv:
    (root / "Documentation" / "static-check-results.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps(report, ensure_ascii=False, indent=2))
if failures: sys.exit(1)

