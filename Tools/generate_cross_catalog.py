"""Generate stable iOS-compatible catalog data without editing the Swift sources."""
import json
import re
import ast
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / 'Packages/TrainLogCore/Sources/TrainLogCore/ExerciseCatalog.swift').read_text(encoding='utf-8')
domain = (ROOT / 'Packages/TrainLogCore/Sources/TrainLogCore/Domain.swift').read_text(encoding='utf-8')
cardio = (ROOT / 'Packages/TrainLogCore/Sources/TrainLogCore/Cardio.swift').read_text(encoding='utf-8')
exercises = []
for line in source.splitlines():
    match = re.search(r'make\((\d+), "([^"]+)", "([^"]+)", \[([^\]]*)\](?:, \[([^\]]*)\])?(.*?)\),?$', line.strip())
    if not match:
        continue
    index, name, english, primary, secondary, tail = match.groups()
    values = [v.strip().removeprefix('.') for v in tail.strip(', ').split(',')] if tail.strip(', ') else []
    values += ['barbell', 'nil', 'false', 'weightReps', 'total'][len(values):]
    exercise = dict(id=f'544c0100-0000-0000-0000-{int(index):012x}', name=name, englishName=english,
                    primary=re.findall(r'\.(\w+)', primary), secondary=re.findall(r'\.(\w+)', secondary or ''),
                    equipment=values[0], tracking=values[3], loading=values[4], allowsEstimate=values[2] == 'true',
                    isCustom=False, isFavorite=False, isArchived=False)
    if values[1] != 'nil':
        exercise['pattern'] = values[1]
    exercises.append(exercise)
muscles = dict(re.findall(r'case \.(\w+): return "([^"]+)"', domain.split('public enum WorkoutMode')[0]))
activities = dict(re.findall(r'case \.(\w+): return "([^"]+)"', cardio.split('public var supportsDistance')[0]))
assert len(exercises) == 128 and len(activities) == 38 and len(muscles) == 18
vector = (ROOT / 'TrainLog/Features/MuscleMap/MuscleVectorData.swift').read_text(encoding='utf-8')
outline = ast.literal_eval('[' + re.search(r'static let outline = points\(\[(.*?)\]\)', vector, re.S).group(1) + ']')
regions = []
for muscle, view, coordinates in re.findall(r'pair\(\.(\w+), \.(front|back), \[(.*?)\]\)', vector):
    points = ast.literal_eval('[' + coordinates + ']')
    for side in ['left', 'right']:
        regions.append(dict(muscle=muscle, view=view, points=points if side == 'left' else [(200-x, y) for x, y in points]))
assert len(regions) == 40
out = ROOT / 'CrossPlatform/assets/catalog.json'
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(dict(exercises=exercises, muscles=muscles, activities=activities, outline=outline, regions=regions), ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(f'Generated {len(exercises)} strength exercises and {len(activities)} activities')
