#!/usr/bin/env python3
"""Verify stage art sizes, alpha, and collision-aligned terrain placement."""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SIZES = {"high": (1920, 1080), "medium": (1280, 720), "low": (960, 540)}
WORLD_LEFT, WORLD_TOP, WORLD_WIDTH, WORLD_HEIGHT = -816.0, -528.0, 2912.0, 1638.0
PIECES = ((370.0, 418.0, 540.0), (100.0, 586.0, 1080.0))


def expected(value: float, origin: float, span: float, pixels: int) -> int:
    return round((value - origin) / span * pixels)


def bands(alpha: np.ndarray) -> list[tuple[int, int]]:
    occupied = np.flatnonzero((alpha >= 16).sum(axis=1) > 30)
    result: list[tuple[int, int]] = []
    start = previous = int(occupied[0])
    for value in occupied[1:]:
        value = int(value)
        if value > previous + 1:
            result.append((start, previous + 1))
            start = value
        previous = value
    result.append((start, previous + 1))
    return result


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
        found = bands(alpha)
        if len(found) != 2:
            failures.append(f"{quality} expected two terrain bands, found {found}")
            continue
        for band, (left, top, world_width) in zip(found, PIECES):
            y0, y1 = band
            _, xs = np.where(alpha[y0:y1] >= 16)
            x0, x1 = int(xs.min()), int(xs.max()) + 1
            target_left = expected(left, WORLD_LEFT, WORLD_WIDTH, size[0])
            target_top = expected(top, WORLD_TOP, WORLD_HEIGHT, size[1])
            target_width = round(world_width / WORLD_WIDTH * size[0])
            if abs(x0 - target_left) > 2 or abs((x1 - x0) - target_width) > 3:
                failures.append(f"{quality} terrain x {x0}..{x1} != {target_left} width {target_width}")
            if abs(y0 - target_top) > 2:
                failures.append(f"{quality} terrain top {y0} != {target_top}")
    if failures:
        print("FOREST_LEDGE_ART: FAIL")
        for failure in failures:
            print(" -", failure)
        raise SystemExit(1)
    print("FOREST_LEDGE_ART: PASS (3 quality variants, collision-aligned)")


if __name__ == "__main__":
    main()
