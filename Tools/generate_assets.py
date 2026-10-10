"""Generate a simple native-style icon from geometric shapes; requires Pillow."""
from pathlib import Path
import json
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[1] / "TrainLog" / "Resources" / "Assets.xcassets"
root.mkdir(parents=True, exist_ok=True)
info = {"info": {"author": "xcode", "version": 1}}
(root / "Contents.json").write_text(json.dumps(info, indent=2))
accent = root / "AccentColor.colorset"; accent.mkdir(exist_ok=True)
(accent / "Contents.json").write_text(json.dumps({**info, "colors": [{"idiom": "universal", "color": {"color-space": "srgb", "components": {"red": "0.000", "green": "0.478", "blue": "1.000", "alpha": "1.000"}}}]}, indent=2))
icon = root / "AppIcon.appiconset"; icon.mkdir(exist_ok=True)
size = 2048
image = Image.new("RGB", (size, size))
d = ImageDraw.Draw(image)
for y in range(size):
    f = y / size
    d.line((0, y, size, y), fill=(int(20 - 12 * f), int(139 - 50 * f), int(255 - 28 * f)))
for box, radius in [((440, 594, 660, 1278), 96), ((1388, 594, 1608, 1278), 96), ((304, 764, 416, 1108), 56), ((1632, 764, 1744, 1108), 56), ((658, 864, 1390, 1008), 68)]:
    d.rounded_rectangle(box, radius=radius, fill="white")
d.line([(676, 1512), (896, 1432), (1070, 1482), (1352, 1328)], fill=(194, 224, 255), width=34, joint="curve")
for x, y in [(676, 1512), (896, 1432), (1070, 1482), (1352, 1328)]:
    d.ellipse((x - 25, y - 25, x + 25, y + 25), fill="white")
image.resize((1024, 1024), Image.Resampling.LANCZOS).save(icon / "AppIcon.png")
(icon / "Contents.json").write_text(json.dumps({**info, "images": [{"filename": "AppIcon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}]}, indent=2))
print("Generated opaque 1024px app icon and accent asset.")

