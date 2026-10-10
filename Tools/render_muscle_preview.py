"""Render source vector geometry for visual review; this is not an iOS screenshot."""
from pathlib import Path
import ast
import re
from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parents[1]
source = (root / "TrainLog/Features/MuscleMap/MuscleVectorData.swift").read_text(encoding="utf-8")
outline = ast.literal_eval("[" + re.search(r"static let outline = points\(\[(.*?)\]\)", source, re.S).group(1) + "]")
regions = []
for muscle, view, coords in re.findall(r"pair\(\.(\w+), \.(front|back), \[(.*?)\]\)", source):
    points = ast.literal_eval("[" + coords + "]")
    regions += [(muscle, view, points), (muscle, view, [(200-x, y) for x, y in points])]

def curve(points, rounding=0.2):
    output = []
    for i, p in enumerate(points):
        prev, nxt = points[i-1], points[(i+1) % len(points)]
        a = (p[0]+(prev[0]-p[0])*rounding, p[1]+(prev[1]-p[1])*rounding)
        b = (p[0]+(nxt[0]-p[0])*rounding, p[1]+(nxt[1]-p[1])*rounding)
        for step in range(21):
            t = step/20
            output.append(((1-t)**2*a[0]+2*(1-t)*t*p[0]+t*t*b[0], (1-t)**2*a[1]+2*(1-t)*t*p[1]+t*t*b[1]))
    return output

image = Image.new("RGB", (1440, 1120), "#F2F2F7")
d = ImageDraw.Draw(image)
font_path = Path("C:/Windows/Fonts/arial.ttf")
def font(size):
    return ImageFont.truetype(str(font_path), size) if font_path.exists() else ImageFont.load_default()
d.text((50, 30), "TRAINLOG / SOURCE VECTOR REVIEW", fill="#182435", font=font(28))
d.text((50, 74), "Geometry rendered from MuscleVectorData.swift. Not an iOS screenshot. No real training data.", fill="#6B7280", font=font(20))
for panel, dark in enumerate([False, True]):
    x0 = 40 + panel * 710
    card, text, neutral, outline_color = ("#1C1C1E", "#F2F2F7", "#363638", "#29292B") if dark else ("#FFFFFF", "#20242D", "#DFE2E6", "#F0F1F3")
    d.rounded_rectangle((x0, 120, x0+690, 1080), radius=28, fill=card)
    d.text((x0+26, 148), "CHEST SELECTION / TEST STATE" if not dark else "NO RECORDS / NEUTRAL STATE", fill=text, font=font(20))
    for col, view in enumerate(["front", "back"]):
        ox, oy, scale = x0+25+col*337, 212, 1.57
        def transform(points): return [(ox+x*scale, oy+y*scale) for x,y in points]
        d.polygon(transform(curve(outline, 0.5)), fill=outline_color)
        d.ellipse((ox+82*scale, oy+3*scale, ox+118*scale, oy+57*scale), fill=outline_color)
        for muscle, region_view, points in regions:
            if region_view != view: continue
            fill = "#007AFF" if not dark and muscle == "chest" else neutral
            coords = transform(curve(points))
            d.polygon(coords, fill=fill)
            d.line(coords+[coords[0]], fill=card, width=2)
        if view == "front":
            for y in [0.327, 0.36, 0.393]: d.line((ox+79.4*scale, oy+440*y*scale, ox+120.6*scale, oy+440*y*scale), fill=card, width=2)
        d.text((ox+110, 932), view.upper(), fill=text, font=font(18))
    d.text((x0+26, 1016), "18 muscle groups / independent mirrored regions", fill="#939AA4", font=font(17))
out = root / "Documentation"; out.mkdir(exist_ok=True)
image.save(out / "muscle-vector-review.png")
print(f"Rendered {len(regions)} independent regions from source to Documentation/muscle-vector-review.png")

