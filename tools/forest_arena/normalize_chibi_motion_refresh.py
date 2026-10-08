"""Normalize and install the explicitly approved Nabi/Yu-Ran chibi motion set.

The approved 4x4 review sheets remain immutable inputs.  This tool splits the
16 poses, removes only near-transparent pixels and detached cross-cell
fragments, applies one character-wide scale, anchors the lower contact point at
(64, 124), and stages 2048x128 RGBA sheets.  Runtime and manifest writes happen
only with --install.
"""

from __future__ import annotations

from argparse import ArgumentParser
from collections import deque
from pathlib import Path
import hashlib
import json
import shutil
import statistics

import numpy as np
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / "_workspace/chibi-motion-refresh-yu-ran-nabi"
DRAFTS = WORK / "01_drafts"
NORMALIZED = WORK / "02_normalized"
MANIFEST_PATH = ROOT / "assets/character/manifest.json"
CHARACTERS = {"nabi": 29, "yu-ran": 30}
FRAME_COUNT = 16
CELL_SIZE = 128
FOOT_PIVOT = (64, 124)
ALPHA_THRESHOLD = 8
TARGET_IDLE_HEIGHT = 112


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def motion_name(entry: dict) -> str:
    return entry.get("visual_state_id") or Path(entry["path"]).stem.removesuffix("_16f")


def connected_component(mask: np.ndarray, seed: tuple[int, int]) -> np.ndarray:
    height, width = mask.shape
    seen = np.zeros_like(mask, dtype=bool)
    queue: deque[tuple[int, int]] = deque([seed])
    seen[seed[1], seed[0]] = True
    while queue:
        x, y = queue.popleft()
        for next_x, next_y in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if (0 <= next_x < width and 0 <= next_y < height
                    and mask[next_y, next_x] and not seen[next_y, next_x]):
                seen[next_y, next_x] = True
                queue.append((next_x, next_y))
    return seen


def clean_cell(cell: Image.Image) -> tuple[Image.Image, tuple[int, int, int, int], tuple[float, float]]:
    resized = cell.convert("RGBA").resize((CELL_SIZE, CELL_SIZE), Image.Resampling.LANCZOS)
    pixels = np.asarray(resized).copy()
    pixels[pixels[:, :, 3] < ALPHA_THRESHOLD] = 0
    mask = pixels[:, :, 3] >= ALPHA_THRESHOLD

    remaining = mask.copy()
    parts: list[dict] = []
    while remaining.any():
        y, x = np.argwhere(remaining)[0]
        part = connected_component(remaining, (int(x), int(y)))
        ys, xs = np.nonzero(part)
        bounds = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
        touches_edge = (xs.min() == 0 or ys.min() == 0
                        or xs.max() == CELL_SIZE - 1 or ys.max() == CELL_SIZE - 1)
        parts.append({
            "mask": part, "size": int(part.sum()), "touches_edge": touches_edge,
            "bounds": bounds,
        })
        remaining[part] = False
    if not parts:
        raise ValueError("empty source cell")

    # A falling or downed pose often crosses the equal 4x4 row boundary.  The
    # upper strip of the previous pose then appears at y=0 in the next cell.
    # Reject that strip when a substantial component exists lower in the cell.
    def is_boundary_fragment(bounds: tuple[int, int, int, int]) -> bool:
        top_strip = bounds[1] == 0 and bounds[3] <= 64
        left_strip = bounds[0] == 0 and bounds[2] <= 32
        right_strip = bounds[2] == CELL_SIZE and bounds[0] >= 96
        return top_strip or left_strip or right_strip

    eligible = [part for part in parts if not is_boundary_fragment(part["bounds"])]
    if not eligible:
        eligible = parts
    primary = max(eligible, key=lambda item: item["size"])
    primary_bounds = primary["bounds"]
    silhouette = np.zeros_like(mask)
    for item in parts:
        bounds = item["bounds"]
        boundary_fragment = is_boundary_fragment(bounds)
        horizontal_gap = max(primary_bounds[0] - bounds[2], bounds[0] - primary_bounds[2], 0)
        vertical_gap = max(primary_bounds[1] - bounds[3], bounds[1] - primary_bounds[3], 0)
        nearby = horizontal_gap <= 12 and vertical_gap <= 12
        if item is primary or (not boundary_fragment and item["size"] >= 12 and nearby):
            silhouette |= item["mask"]
    pixels[~silhouette] = 0
    image = Image.fromarray(pixels, "RGBA")
    bounds = image.getbbox()
    if bounds is None:
        raise ValueError("empty cell after cleanup")

    # Prefer the lower central foreground band so a low tail tip does not pull
    # the fighter's foot anchor away from the body.
    y_grid, x_grid = np.indices(silhouette.shape)
    lower = silhouette & (y_grid >= bounds[3] - 14) & (np.abs(x_grid - 64) <= 42)
    ys, xs = np.nonzero(lower)
    if not len(xs):
        ys, xs = np.nonzero(silhouette & (y_grid >= bounds[3] - 14))
    pivot_x = float(np.median(xs)) if len(xs) else (bounds[0] + bounds[2]) / 2.0
    return image, bounds, (pivot_x, float(bounds[3]))


def split_review(source: Path) -> list[tuple[Image.Image, tuple[int, int, int, int], tuple[float, float]]]:
    image = Image.open(source).convert("RGBA")
    frames = []
    for index in range(FRAME_COUNT):
        column, row = index % 4, index // 4
        edges = (
            round(column * image.width / 4), round(row * image.height / 4),
            round((column + 1) * image.width / 4), round((row + 1) * image.height / 4),
        )
        try:
            frames.append(clean_cell(image.crop(edges)))
        except ValueError as error:
            raise ValueError(f"{source.name} frame {index + 1}: {error}") from error
    return frames


def find_source(character_id: str, name: str) -> Path:
    matches = list((DRAFTS / character_id).rglob(f"{name}-r01.png"))
    if len(matches) != 1:
        raise ValueError(f"expected one review source for {character_id}/{name}, got {len(matches)}")
    return matches[0]


def runtime_entries(manifest: dict, character_id: str) -> dict[str, dict]:
    result: dict[str, dict] = {}
    for entry in manifest["assets"]:
        if entry.get("character_id") != character_id or entry.get("type") != "animation-runtime":
            continue
        name = motion_name(entry)
        if name in result:
            raise ValueError(f"duplicate manifest motion {character_id}/{name}")
        result[name] = entry
    expected = CHARACTERS[character_id]
    if len(result) != expected:
        raise ValueError(f"expected {expected} manifest motions for {character_id}, got {len(result)}")
    return result


def normalize_character(character_id: str, entries: dict[str, dict]) -> dict:
    sources = {name: find_source(character_id, name) for name in entries}
    extracted = {name: split_review(path) for name, path in sources.items()}
    idle_heights = [bounds[3] - bounds[1] for _, bounds, _ in extracted["idle"]]
    base_scale = TARGET_IDLE_HEIGHT / statistics.median(idle_heights)
    output_dir = NORMALIZED / character_id
    output_dir.mkdir(parents=True, exist_ok=True)

    report = {
        "character_id": character_id,
        "base_scale": base_scale,
        "foot_pivot": list(FOOT_PIVOT),
        "alpha_threshold": ALPHA_THRESHOLD,
        "motions": [],
    }
    for name in sorted(entries):
        cells: list[Image.Image] = []
        frame_report = []
        for image, bounds, pivot in extracted[name]:
            width = bounds[2] - bounds[0]
            height = bounds[3] - bounds[1]
            half_width = max(pivot[0] - bounds[0], bounds[2] - pivot[0], 1.0)
            frame_scale = min(base_scale, 60.0 / half_width, 118.0 / height)
            cropped = image.crop(bounds)
            size = (max(1, round(width * frame_scale)), max(1, round(height * frame_scale)))
            pose = cropped.resize(size, Image.Resampling.LANCZOS)
            pixels = np.asarray(pose).copy()
            pixels[pixels[:, :, 3] < ALPHA_THRESHOLD] = 0
            pose = Image.fromarray(pixels, "RGBA")
            x = round(FOOT_PIVOT[0] - (pivot[0] - bounds[0]) * frame_scale)
            y = round(FOOT_PIVOT[1] - height * frame_scale)
            if x < 2 or y < 2 or x + size[0] > 126 or y + size[1] > 126:
                raise ValueError(f"packing overflow for {character_id}/{name}: {(x, y, *size)}")
            cell = Image.new("RGBA", (CELL_SIZE, CELL_SIZE))
            cell.alpha_composite(pose, (x, y))
            if cell.getbbox() is None:
                raise ValueError(f"empty normalized frame for {character_id}/{name}")
            cells.append(cell)
            frame_report.append({
                "source_bounds": list(bounds), "source_pivot": list(pivot),
                "scale": frame_scale, "runtime_bounds": list(cell.getbbox()),
            })

        sheet = Image.new("RGBA", (CELL_SIZE * FRAME_COUNT, CELL_SIZE))
        preview = Image.new("RGB", (CELL_SIZE * 4, CELL_SIZE * 4), "#34383f")
        draw = ImageDraw.Draw(preview)
        for index, cell in enumerate(cells):
            sheet.alpha_composite(cell, (index * CELL_SIZE, 0))
            review_cell = Image.new("RGBA", (CELL_SIZE, CELL_SIZE), "#34383f")
            review_cell.alpha_composite(cell)
            preview.paste(review_cell.convert("RGB"), ((index % 4) * CELL_SIZE, (index // 4) * CELL_SIZE))
            draw.text(((index % 4) * CELL_SIZE + 3, (index // 4) * CELL_SIZE + 3), str(index + 1), fill="white")
        sheet_path = output_dir / f"{name}_16f.png"
        sheet.save(sheet_path)
        preview.save(output_dir / f"{name}_contact.jpg", quality=92)
        report["motions"].append({
            "name": name,
            "source": str(sources[name].relative_to(ROOT)),
            "source_sha256": sha256(sources[name]),
            "normalized_sha256": sha256(sheet_path),
            "frames": frame_report,
        })
    return report


def validate_staged(reports: dict[str, dict]) -> None:
    count = 0
    for character_id, report in reports.items():
        if len(report["motions"]) != CHARACTERS[character_id]:
            raise ValueError(f"incomplete report for {character_id}")
        for motion in report["motions"]:
            path = NORMALIZED / character_id / f"{motion['name']}_16f.png"
            image = Image.open(path).convert("RGBA")
            if image.size != (2048, 128):
                raise ValueError(f"invalid staged size: {path}")
            if image.getchannel("A").getextrema()[0] == image.getchannel("A").getextrema()[1]:
                raise ValueError(f"staged sheet lacks alpha variation: {path}")
            for index in range(FRAME_COUNT):
                if image.crop((index * 128, 0, (index + 1) * 128, 128)).getbbox() is None:
                    raise ValueError(f"empty staged frame {index + 1}: {path}")
            if sha256(path) != motion["normalized_sha256"]:
                raise ValueError(f"staged hash mismatch: {path}")
            count += 1
    if count != sum(CHARACTERS.values()):
        raise ValueError(f"expected 59 staged sheets, got {count}")


def install(reports: dict[str, dict], manifest: dict) -> None:
    references = ["User explicitly approved the complete 59-motion Nabi and Yu-Ran chibi review set, 2026-10-07"]
    by_character = {character_id: runtime_entries(manifest, character_id) for character_id in CHARACTERS}
    for character_id, report in reports.items():
        hashes = {motion["name"]: motion["normalized_sha256"] for motion in report["motions"]}
        for name, entry in by_character[character_id].items():
            staged = NORMALIZED / character_id / f"{name}_16f.png"
            runtime = ROOT / entry["path"]
            runtime.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(staged, runtime)
            if sha256(runtime) != hashes[name]:
                raise ValueError(f"installed hash mismatch: {runtime}")
            entry["sha256"] = hashes[name]
            entry["creation"] = {
                "method": "user-approved chibi review plus project-local alpha cleanup and normalization",
                "provider": "OpenAI built-in image generation and local Pillow processing",
                "version": "chibi-r01",
            }
            entry["rights"] = {
                "status": f"derived from approved {character_id} concept; no additional external rights verification asserted",
                "references": references,
            }
            entry["verified_on"] = "2026-10-07"
            entry["modifications"] = [
                "Used the approved target concept for identity and completed Ja-Hyun/Myo-Ryung motions for style and timing reference only.",
                "Removed alpha below 8, discarded detached cross-cell fragments, and packed 16 RGBA 128x128 cells at foot pivot (64,124).",
                "Preserved the existing logical asset ID, visual state ID, SpriteFrames path, FPS, loop setting, and combat authority boundary.",
            ]
            entry["foot_pivot_y"] = 124
    MANIFEST_PATH.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")


def main() -> None:
    parser = ArgumentParser()
    parser.add_argument("--install", action="store_true", help="replace runtime sheets and update manifest after staging")
    args = parser.parse_args()
    manifest = json.loads(MANIFEST_PATH.read_text())
    reports = {}
    for character_id in CHARACTERS:
        entries = runtime_entries(manifest, character_id)
        reports[character_id] = normalize_character(character_id, entries)
    validate_staged(reports)
    report_path = NORMALIZED / "report.json"
    report_path.write_text(json.dumps({"schema_version": 1, "characters": reports}, indent=2) + "\n")
    if args.install:
        install(reports, manifest)
    print(json.dumps({
        "staged": sum(len(report["motions"]) for report in reports.values()),
        "installed": bool(args.install),
        "report": str(report_path.relative_to(ROOT)),
    }))


if __name__ == "__main__":
    main()
