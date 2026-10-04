#!/usr/bin/env python3
"""Normalize approved generated stage art and align terrain to collision geometry."""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image


WORLD_LEFT = -816.0
WORLD_TOP = -528.0
WORLD_WIDTH = 2912.0
WORLD_HEIGHT = 1638.0
WORLD_CENTER_X = 640.0
GROUND = (100.0, 586.0, 1080.0)
PLATFORM = (370.0, 418.0, 540.0)
QUALITIES = {"high": (1920, 1080), "medium": (1280, 720), "low": (960, 540)}


def cover(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    target_ratio = size[0] / size[1]
    source_ratio = image.width / image.height
    if source_ratio > target_ratio:
        width = round(image.height * target_ratio)
        left = (image.width - width) // 2
        image = image.crop((left, 0, left + width, image.height))
    elif source_ratio < target_ratio:
        height = round(image.width / target_ratio)
        top = (image.height - height) // 2
        image = image.crop((0, top, image.width, top + height))
    return image.resize(size, Image.Resampling.LANCZOS)


def component_bands(alpha: np.ndarray) -> list[tuple[int, int]]:
    # Generated alpha can contain isolated low-area speckles. Gameplay pieces have
    # more than 100 visible pixels on each occupied row.
    occupied = np.flatnonzero((alpha >= 16).sum(axis=1) > 100)
    bands: list[tuple[int, int]] = []
    start = previous = int(occupied[0])
    for value in occupied[1:]:
        value = int(value)
        if value > previous + 1:
            bands.append((start, previous + 1))
            start = value
        previous = value
    bands.append((start, previous + 1))
    if len(bands) != 2:
        raise ValueError(f"expected two terrain pieces, found bands={bands}")
    return bands


def crop_piece(image: Image.Image, band: tuple[int, int]) -> Image.Image:
    rgba = np.asarray(image.convert("RGBA")).copy()
    alpha = rgba[:, :, 3]
    mask = np.zeros_like(alpha, dtype=bool)
    mask[band[0] : band[1]] = alpha[band[0] : band[1]] >= 16
    ys, xs = np.where(mask)
    box = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
    piece = image.convert("RGBA").crop(box)
    data = np.asarray(piece).copy()
    data[data[:, :, 3] < 16] = 0
    return Image.fromarray(data, "RGBA")


def world_x(value: float, width: int) -> int:
    return round((value - WORLD_LEFT) / WORLD_WIDTH * width)


def world_y(value: float, height: int) -> int:
    return round((value - WORLD_TOP) / WORLD_HEIGHT * height)


def terrain_canvas(source: Image.Image, size: tuple[int, int]) -> Image.Image:
    alpha = np.asarray(source.convert("RGBA"))[:, :, 3]
    bands = component_bands(alpha)
    upper = crop_piece(source, bands[0])
    lower = crop_piece(source, bands[1])
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    for piece, geometry in ((lower, GROUND), (upper, PLATFORM)):
        _, top, world_width = geometry
        target_width = round(world_width / WORLD_WIDTH * size[0])
        target_height = round(piece.height * target_width / piece.width)
        piece = piece.resize((target_width, target_height), Image.Resampling.LANCZOS)
        left = world_x(WORLD_CENTER_X, size[0]) - target_width // 2
        canvas.alpha_composite(piece, (left, world_y(top, size[1])))
    return canvas


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--background", type=Path, required=True)
    parser.add_argument("--terrain", type=Path, required=True)
    parser.add_argument("--root", type=Path, required=True)
    args = parser.parse_args()
    background = Image.open(args.background).convert("RGB")
    terrain = Image.open(args.terrain).convert("RGBA")
    for quality, size in QUALITIES.items():
        background_path = args.root / "forest_arena/assets/quality" / quality / "background/bg_combat_forest_arena.png"
        terrain_path = args.root / "forest_arena/assets/quality" / quality / "terrain/terrain_forest_ledge.png"
        background_path.parent.mkdir(parents=True, exist_ok=True)
        terrain_path.parent.mkdir(parents=True, exist_ok=True)
        cover(background, size).save(background_path, optimize=True)
        terrain_canvas(terrain, size).save(terrain_path, optimize=True)
        print(f"wrote {quality}: {background_path} {terrain_path}")


if __name__ == "__main__":
    main()
