"""Export the native app's catalog and vector paths for the offline preview."""
from pathlib import Path
import ast
import json
import re

root = Path(__file__).resolve().parents[1]
vector = (root / "TrainLog/Features/MuscleMap/MuscleVectorData.swift").read_text(encoding="utf-8")
domain = (root / "Packages/TrainLogCore/Sources/TrainLogCore/Domain.swift").read_text(encoding="utf-8")
catalog = (root / "Packages/TrainLogCore/Sources/TrainLogCore/ExerciseCatalog.swift").read_text(encoding="utf-8")
outline = ast.literal_eval("[" + re.search(r"static let outline = points\(\[(.*?)\]\)", vector, re.S).group(1) + "]")
regions = []
for muscle, view, coordinates in re.findall(r"pair\(\.(\w+), \.(front|back), \[(.*?)\]\)", vector):
    points = ast.literal_eval("[" + coordinates + "]")
    for side in ("left", "right"):
        regions.append(dict(id=f"{view}.{muscle}.{side}", muscle=muscle, view=view,
                            points=points if side == "left" else [(200 - x, y) for x, y in points]))
muscles = dict(re.findall(r'case \.(\w+): return "([^"]+)"', domain.split("public enum WorkoutMode")[0]))
exercises = []
for line in catalog.splitlines():
    match = re.search(r'make\((\d+), "([^"]+)", "([^"]+)", \[([^\]]*)\](?:, \[([^\]]*)\])?(.*?)\),?$', line.strip())
    if not match:
        continue
    identifier, name, english, primary, secondary, tail = match.groups()
    values = [value.strip().removeprefix(".") for value in tail.strip(", ").split(",")] if tail.strip(", ") else []
    defaults = ["barbell", "nil", "false", "weightReps", "total"]
    values += defaults[len(values):]
    exercises.append(dict(id=int(identifier), name=name, english=english,
                          primary=re.findall(r'\.(\w+)', primary), secondary=re.findall(r'\.(\w+)', secondary or ""),
                          equipment=values[0], pattern=values[1], estimate=values[2] == "true", tracking=values[3], loading=values[4]))
assert len(regions) == 40 and len(muscles) == 18 and len(exercises) >= 37
assert len({exercise['id'] for exercise in exercises}) == len(exercises)
data = dict(outline=outline, regions=regions, muscles=muscles, exercises=exercises)
out = root / "WindowsPreview/catalog.js"
out.parent.mkdir(exist_ok=True)
out.write_text("// Generated from the TrainLog Swift sources.\nwindow.TRAINLOG_CATALOG = " + json.dumps(data, ensure_ascii=False, separators=(",", ":")) + ";\n", encoding="utf-8")
print(f"Exported {len(exercises)} exercises, {len(muscles)} muscles and {len(regions)} regions.")
