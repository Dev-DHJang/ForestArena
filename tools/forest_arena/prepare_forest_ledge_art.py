#!/usr/bin/env python3
"""Normalize approved generated stage art and align terrain to collision geometry."""

from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image


WORLD_LEFT = -816.0
WORLD_TOP = -528.0
WORLD_WIDTH = 2912.0
WORLD_HEIGHT = 1638.0
PIECES = (
    # source crop (left, top, right, bottom) in normalized source coordinates,
    # then collision surface (left, top, width) in world coordinates.
    ((0.08, 0.60, 0.92, 1.00), (-440.0, 586.0, 2160.0)),
    ((0.12, 0.43, 0.35, 0.63), (-300.0, 470.0, 380.0)),
    ((0.32, 0.34, 0.57, 0.58), (120.0, 380.0, 420.0)),
    ((0.56, 0.39, 0.84, 0.63), (760.0, 430.0, 520.0)),
    ((0.80, 0.31, 0.99, 0.56), (1330.0, 350.0, 280.0)),
)
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


def crop_piece(image: Image.Image, region: tuple[float, float, float, float]) -> Image.Image:
    box = (
        round(region[0] * image.width), round(region[1] * image.height),
        round(region[2] * image.width), round(region[3] * image.height),
    )
    piece = image.convert("RGBA").crop(box)
    data = np.asarray(piece).copy()
    data[data[:, :, 3] < 16] = 0
    mask = data[:, :, 3] >= 16
    visited = np.zeros_like(mask, dtype=bool)
    largest: list[tuple[int, int]] = []
    height, width = mask.shape
    for seed_y, seed_x in zip(*np.where(mask & ~visited)):
        if visited[seed_y, seed_x]:
            continue
        component: list[tuple[int, int]] = []
        queue = deque([(int(seed_y), int(seed_x))])
        visited[seed_y, seed_x] = True
        while queue:
            y, x = queue.popleft()
            component.append((y, x))
            for next_y, next_x in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
                if 0 <= next_y < height and 0 <= next_x < width and mask[next_y, next_x] and not visited[next_y, next_x]:
                    visited[next_y, next_x] = True
                    queue.append((next_y, next_x))
        if len(component) > len(largest):
            largest = component
    keep = np.zeros_like(mask, dtype=bool)
    if largest:
        ys_keep, xs_keep = zip(*largest)
        keep[np.asarray(ys_keep), np.asarray(xs_keep)] = True
    data[~keep] = 0
    ys, xs = np.where(data[:, :, 3] >= 16)
    if xs.size == 0:
        raise ValueError(f"terrain source region has no visible pixels: {region}")
    tight = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
    return Image.fromarray(data, "RGBA").crop(tight)


def surface_row(piece: Image.Image) -> int:
    alpha = np.asarray(piece)[:, :, 3]
    counts = (alpha >= 16).sum(axis=1)
    # Broad horizontal grass lips are the first rows covering most of
    # the piece. Decorative leaves above them therefore do not move collisions.
    candidates = np.flatnonzero(counts >= piece.width * 0.85)
    if candidates.size == 0:
        raise ValueError("terrain piece has no readable horizontal walk surface")
    return int(candidates[0])


def world_x(value: float, width: int) -> int:
    return round((value - WORLD_LEFT) / WORLD_WIDTH * width)


def world_y(value: float, height: int) -> int:
    return round((value - WORLD_TOP) / WORLD_HEIGHT * height)


def terrain_canvas(source: Image.Image, size: tuple[int, int]) -> Image.Image:
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    for region, geometry in PIECES:
        piece = crop_piece(source, region)
        source_surface = surface_row(piece)
        left, top, world_width = geometry
        target_width = round(world_width / WORLD_WIDTH * size[0])
        source_width = piece.width
        target_height = round(piece.height * target_width / piece.width)
        piece = piece.resize((target_width, target_height), Image.Resampling.LANCZOS)
        scaled_surface = round(source_surface * target_width / source_width)
        target_left = world_x(left, size[0])
        target_top = world_y(top, size[1]) - scaled_surface
        canvas.alpha_composite(piece, (target_left, target_top))
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
