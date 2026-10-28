"""Generate the shared brand layer for native SwiftUI and Flutter clients."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOKENS = json.loads((ROOT / "DesignSystem/tokens.json").read_text(encoding="utf-8"))


def rgb(value: str) -> tuple[int, int, int]:
    if len(value) != 7 or not value.startswith("#"):
        raise ValueError(f"Invalid color: {value}")
    return tuple(int(value[i : i + 2], 16) for i in (1, 3, 5))


def swift_color(value: str) -> str:
    r, g, b = rgb(value)
    return f"Color(red: {r}.0 / 255.0, green: {g}.0 / 255.0, blue: {b}.0 / 255.0)"


swift_lines = ["// Generated from DesignSystem/tokens.json. Do not edit by hand.", "import SwiftUI", "", "enum TrainLogTokens {"]
dart_lines = ["// Generated from DesignSystem/tokens.json. Do not edit by hand.", "import 'package:flutter/material.dart';", "", "abstract final class TrainLogTokens {"]
for key, value in TOKENS.items():
    if key.endswith(("Radius", "Spacing")):
        swift_lines.append(f"    static let {key}: CGFloat = {value}")
        dart_lines.append(f"  static const double {key} = {value};")
    else:
        swift_lines.append(f"    static let {key} = {swift_color(value)}")
        dart_lines.append(f"  static const Color {key} = Color(0xff{value[1:].lower()});")
swift_lines.append("}")
dart_lines.append("}")

OUTPUTS = {
    ROOT / "TrainLog/Core/DesignSystem/GeneratedTokens.swift": "\n".join(swift_lines) + "\n",
    ROOT / "CrossPlatform/lib/generated_tokens.dart": "\n".join(dart_lines) + "\n",
}
if __name__ == "__main__":
    import sys

    check = "--check" in sys.argv
    mismatches = []
    for path, expected in OUTPUTS.items():
        if check:
            if not path.exists() or path.read_text(encoding="utf-8") != expected:
                mismatches.append(str(path.relative_to(ROOT)))
        else:
            path.write_text(expected, encoding="utf-8")
    if mismatches:
        raise SystemExit("Design tokens out of date: " + ", ".join(mismatches))
