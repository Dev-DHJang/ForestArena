"""Audit every registered playable-character motion sheet and render full-frame review boards."""

from __future__ import annotations

from collections import Counter
from pathlib import Path
import argparse
import hashlib
import json

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from normalize_chibi_motion_refresh import connected_component


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "assets/character/manifest.json"
OUT_DEFAULT = ROOT / "_workspace/character-motion-visual-unification/01_audit"
CHARACTERS = ("ja-hyun", "myo-ryung", "nabi", "yu-ran")
CELL = 128
FRAME_COUNT = 16
EXPECTED_MOTIONS = {"ja-hyun":30, "myo-ryung":31, "nabi":29, "yu-ran":30}
LEGACY_ALIASES = {
    f'assets/character/nabi/animation/runtime/attack_light_combo_0{i}_16f.png':
    f'assets/character/nabi/animation/runtime/local_ai_v01/attack_light_combo_0{i}_16f.png'
    for i in (1,2)
}


def validation_errors(report: dict) -> list[str]:
    """Fail closed on missing roster/sheets, not only malformed present sheets.

    Geometry flags still require visual review; they do not prove clipping.
    """
    errors = []
    characters = report.get('characters', {})
    if set(characters) != set(EXPECTED_MOTIONS):
        errors.append('registered roster differs from the four approved characters')
    for cid, expected in EXPECTED_MOTIONS.items():
        motions = characters.get(cid, {}).get('motions', [])
        if len(motions) != expected:
            errors.append(f'{cid}: expected {expected} sheets, found {len(motions)}')
        names = [row.get('motion') for row in motions]
        if None in names or len(set(names)) != len(names):
            errors.append(f'{cid}: missing or duplicate motion names')
        for row in motions:
            key = f"{cid}/{row.get('motion')}"
            for field in ('valid_runtime_shape','manifest_sha_matches','valid_transparency'):
                if row.get(field) is not True:
                    errors.append(f'{key}: {field} failed')
            if row.get('nonempty_frames') != FRAME_COUNT:
                errors.append(f'{key}: expected 16 nonempty frames')
    for alias in report.get('unregistered_sheets', []):
        if not alias.get('approved_alias') or not alias.get('canonical_sha_matches'):
            errors.append(f"unregistered or stale motion sheet: {alias['path']}")
    return errors


def detached_regions(alpha: np.ndarray) -> list[dict]:
    """Flag separated opaque regions for manual review; not an automatic failure."""
    remaining = alpha >= 32
    parts = []
    while remaining.any():
        y, x = np.argwhere(remaining)[0]
        part = connected_component(remaining, (int(x), int(y)))
        ys, xs = np.nonzero(part)
        size = int(part.sum())
        if size >= 12:
            parts.append({'pixels': size, 'bbox': [int(xs.min()), int(ys.min()), int(xs.max())+1, int(ys.max())+1]})
        remaining[part] = False
    if not parts:
        return []
    primary = max(parts, key=lambda p: p['pixels'])
    pb = primary['bbox']
    suspicious = []
    for part in parts:
        b = part['bbox']
        gap_x = max(pb[0]-b[2], b[0]-pb[2], 0)
        gap_y = max(pb[1]-b[3], b[1]-pb[3], 0)
        if part is not primary and max(gap_x, gap_y) >= 8:
            suspicious.append(part)
    return suspicious


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def motion_name(entry: dict) -> str:
    return entry.get("visual_state_id") or Path(entry["path"]).stem.removesuffix("_16f")


def foreground_histogram(image: Image.Image) -> np.ndarray:
    rgba = np.asarray(image.convert("RGBA"))
    pixels = rgba[:, :, :3][rgba[:, :, 3] >= 32]
    if not len(pixels):
        return np.zeros(24, dtype=np.float64)
    hist = []
    for channel in range(3):
        values, _ = np.histogram(pixels[:, channel], bins=8, range=(0, 256))
        hist.extend(values)
    result = np.asarray(hist, dtype=np.float64)
    return result / max(result.sum(), 1.0)


def frame_hash(image: Image.Image) -> str:
    composite = Image.new("RGBA", image.size, (0, 0, 0, 255))
    composite.alpha_composite(image.convert("RGBA"))
    thumb = composite.convert("L").resize((16, 16), Image.Resampling.BILINEAR)
    values = np.asarray(thumb, dtype=np.float32)
    bits = values >= values.mean()
    return np.packbits(bits).tobytes().hex()


def analyze_sheet(path: Path) -> tuple[dict, list[Image.Image]]:
    with Image.open(path) as opened:
        original_mode = opened.mode
        has_alpha = "A" in opened.getbands()
        image = opened.convert("RGBA")
    frames = [image.crop((index * CELL, 0, (index + 1) * CELL, CELL)) for index in range(FRAME_COUNT)]
    frame_rows = []
    for index, frame in enumerate(frames):
        alpha = np.asarray(frame)[:, :, 3]
        bbox = frame.getbbox()
        frame_rows.append(
            {
                "index": index,
                "bbox": list(bbox) if bbox else None,
                "opaque_pixels": int((alpha >= 8).sum()),
                "touches_left": bool(bbox and bbox[0] == 0),
                "touches_top": bool(bbox and bbox[1] == 0),
                "touches_right": bool(bbox and bbox[2] == CELL),
                "touches_bottom": bool(bbox and bbox[3] == CELL),
                "perceptual_hash": frame_hash(frame),
                "detached_regions_for_review": detached_regions(alpha),
            }
        )
    counts = Counter(row["perceptual_hash"] for row in frame_rows)
    duplicate_groups = sorted((count for count in counts.values() if count > 1), reverse=True)
    return (
        {
            "path": str(path.relative_to(ROOT)),
            "sha256": sha256(path),
            "size": list(image.size),
            "mode": original_mode,
            "has_alpha": has_alpha,
            "alpha_range": list(image.getchannel("A").getextrema()),
            "nonempty_frames": sum(row["bbox"] is not None for row in frame_rows),
            "duplicate_hash_group_sizes": duplicate_groups,
            "edge_touch_frames": {
                edge: [row["index"] for row in frame_rows if row[f"touches_{edge}"]]
                for edge in ("left", "top", "right", "bottom")
            },
            "foreground_histogram": foreground_histogram(image).round(8).tolist(),
            "frames": frame_rows,
        },
        frames,
    )


def render_board(character_id: str, rows: list[tuple[str, list[Image.Image]]], output: Path) -> None:
    label_width = 250
    tile = 96
    header = 54
    gutter = 2
    width = label_width + FRAME_COUNT * (tile + gutter) + gutter
    height = header + len(rows) * (tile + gutter) + gutter
    board = Image.new("RGB", (width, height), (24, 26, 32))
    draw = ImageDraw.Draw(board)
    font = ImageFont.load_default()
    draw.text((12, 16), f"{character_id}: registered motions, all 16 frames", fill=(245, 245, 245), font=font)
    for row_index, (name, frames) in enumerate(rows):
        y = header + row_index * (tile + gutter)
        draw.rectangle((0, y, width, y + tile), fill=(32, 35, 42) if row_index % 2 == 0 else (38, 41, 49))
        draw.text((10, y + tile // 2 - 5), name, fill=(238, 238, 238), font=font)
        for index, frame in enumerate(frames):
            thumb = frame.copy()
            thumb.thumbnail((tile - 4, tile - 4), Image.Resampling.LANCZOS)
            checker = Image.new("RGB", (tile, tile), (210, 210, 210))
            checker_draw = ImageDraw.Draw(checker)
            block = 12
            for cy in range(0, tile, block):
                for cx in range(0, tile, block):
                    if (cx // block + cy // block) % 2:
                        checker_draw.rectangle((cx, cy, cx + block - 1, cy + block - 1), fill=(178, 178, 178))
            ox = (tile - thumb.width) // 2
            oy = (tile - thumb.height) // 2
            checker.paste(thumb, (ox, oy), thumb)
            x = label_width + gutter + index * (tile + gutter)
            board.paste(checker, (x, y))
            draw.text((x + 3, y + 3), str(index + 1), fill=(20, 20, 20), font=font)
    output.parent.mkdir(parents=True, exist_ok=True)
    board.save(output, quality=92)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=OUT_DEFAULT)
    args = parser.parse_args()
    output = args.output if args.output.is_absolute() else ROOT / args.output
    output.mkdir(parents=True, exist_ok=True)

    manifest = json.loads(MANIFEST.read_text())
    report = {"schema_version": 1, "characters": {}, "totals": {}}
    registered = {entry['path'] for entry in manifest['assets'] if entry.get('type') == 'animation-runtime'}
    report['unregistered_sheets'] = []
    for path in sorted((ROOT/'assets/character').rglob('*_16f.png')):
        relative = str(path.relative_to(ROOT))
        if relative not in registered:
            canonical = LEGACY_ALIASES.get(relative)
            report['unregistered_sheets'].append({
                'path':relative, 'approved_alias':canonical is not None,
                'canonical_path':canonical,
                'canonical_sha_matches':bool(canonical and sha256(path) == sha256(ROOT/canonical)),
            })
    total = 0
    for character_id in CHARACTERS:
        entries = [
            entry
            for entry in manifest["assets"]
            if entry.get("type") == "animation-runtime"
            and entry.get("path", "").startswith(f"assets/character/{character_id}/")
        ]
        rows = []
        records = []
        for entry in entries:
            name = motion_name(entry)
            path = ROOT / entry["path"]
            record, frames = analyze_sheet(path)
            record["motion"] = name
            record["manifest_sha_matches"] = record["sha256"] == entry.get("sha256")
            record["valid_runtime_shape"] = record["size"] == [2048, 128] and record["mode"] == "RGBA"
            record["valid_transparency"] = record["has_alpha"] and record["alpha_range"][0] == 0 and record["alpha_range"][1] >= 128
            records.append(record)
            rows.append((name, frames))
        render_board(character_id, rows, output / f"{character_id}-all-frames.jpg")
        for start in range(0,len(rows),6):
            render_board(character_id,rows[start:start+6],output/f"{character_id}-page-{start//6+1:02}.jpg")
        report["characters"][character_id] = {
            "motion_count": len(records),
            "valid_runtime_count": sum(row["valid_runtime_shape"] for row in records),
            "manifest_sha_match_count": sum(row["manifest_sha_matches"] for row in records),
            "all_frames_nonempty_count": sum(row["nonempty_frames"] == FRAME_COUNT for row in records),
            "motions": records,
        }
        total += len(records)
    report["totals"] = {
        "registered_motion_count": total,
        "expected_motion_count": 120,
        "all_shapes_valid": all(
            row["valid_runtime_shape"]
            for character in report["characters"].values()
            for row in character["motions"]
        ),
        "all_manifest_hashes_match": all(
            row["manifest_sha_matches"]
            for character in report["characters"].values()
            for row in character["motions"]
        ),
        "all_frames_nonempty": all(
            row["nonempty_frames"] == FRAME_COUNT
            for character in report["characters"].values()
            for row in character["motions"]
        ),
        "all_transparency_valid": all(
            row["valid_transparency"]
            for character in report["characters"].values()
            for row in character["motions"]
        ),
    }
    errors = validation_errors(report)
    report['validation_errors'] = errors
    (output / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(report["totals"], ensure_ascii=False))
    if errors:
        print('\n'.join(errors))
        raise SystemExit(1)


if __name__ == "__main__":
    main()
