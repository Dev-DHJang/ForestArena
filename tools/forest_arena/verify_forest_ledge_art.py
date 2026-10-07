#!/usr/bin/env python3
"""Verify stage art sizes, alpha, and collision-aligned terrain placement."""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SIZES = {"high": (1920, 1080), "medium": (1280, 720), "low": (960, 540)}
WORLD_LEFT, WORLD_TOP, WORLD_WIDTH, WORLD_HEIGHT = -816.0, -528.0, 2912.0, 1638.0
PIECES = (
    (-440.0, 586.0, 2160.0),
    (-300.0, 470.0, 380.0),
    (120.0, 380.0, 420.0),
    (760.0, 430.0, 520.0),
    (1330.0, 350.0, 280.0),
)


def expected(value: float, origin: float, span: float, pixels: int) -> int:
    return round((value - origin) / span * pixels)


def main() -> None:
    failures: list[str] = []
    for quality, size in SIZES.items():
        background_path = ROOT / "forest_arena/assets/quality" / quality / "background/bg_combat_forest_arena.png"
        terrain_path = ROOT / "forest_arena/assets/quality" / quality / "terrain/terrain_forest_ledge.png"
        background = Image.open(background_path)
        terrain = Image.open(terrain_path).convert("RGBA")
        if background.size != size:
            failures.append(f"{quality} background size {background.size} != {size}")
        if terrain.size != size:
            failures.append(f"{quality} terrain size {terrain.size} != {size}")
        alpha = np.asarray(terrain)[:, :, 3]
        for left, top, world_width in PIECES:
            target_left = expected(left, WORLD_LEFT, WORLD_WIDTH, size[0])
            target_top = expected(top, WORLD_TOP, WORLD_HEIGHT, size[1])
            target_width = round(world_width / WORLD_WIDTH * size[0])
            x0, x1 = target_left, target_left + target_width
            y0, y1 = max(0, target_top - 2), min(size[1], target_top + 3)
            surface = alpha[y0:y1, x0:x1] >= 16
            column_coverage = (surface.sum(axis=0) > 0).mean() if surface.size else 0.0
            if column_coverage < 0.78:
                failures.append(f"{quality} terrain surface coverage {column_coverage:.2f} at {left},{top} is below 0.78")
    if failures:
        print("FOREST_LEDGE_ART: FAIL")
        for failure in failures:
            print(" -", failure)
        raise SystemExit(1)
    print("FOREST_LEDGE_ART: PASS (3 quality variants, 5 collision-aligned surfaces)")


if __name__ == "__main__":
    main()
