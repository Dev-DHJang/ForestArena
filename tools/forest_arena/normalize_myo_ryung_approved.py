"""Normalize all user-approved Myo-Ryung motion reviews.

The approved review PNG files are immutable inputs. This tool removes only the
border-connected gray review background and cross-cell fragments, then packs
the approved poses into 128 px RGBA cells with one shared scale and foot pivot.
It also applies the explicitly approved combo-02 review order.
"""
from collections import deque
from pathlib import Path
import hashlib
import json

import numpy as np
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
REVIEW = ROOT / "_workspace/local-ai-playable/motion-review/myo-ryung"
OUT = REVIEW / "normalized"
RUNTIME = ROOT / "assets/character/myo-ryung/animation/runtime/local_ai_v01"
# Match the established local-AI normalization scale. Extremely wide poses may
# shrink per frame to stay inside their 128 px cell.
BASE_SCALE = 0.35398230088495575
SOURCES = [
    {"name": "guard", "file": "guard-r01.png", "order": list(range(16)), "fps": 24},
    {"name": "evade", "file": "evade-r01.png", "order": list(range(16)), "fps": 80},
    {"name": "hitstun", "file": "hitstun-r01.png", "order": list(range(16)), "fps": 24},
    {"name": "launch", "file": "launch-r01.png", "order": list(range(16)), "fps": 12},
    {"name": "attack_heavy_charge", "file": "heavy-charge-r01.png", "order": list(range(16)), "fps": 12},
    {"name": "knock_down", "file": "knock-down-r01.png", "order": list(range(16)), "fps": 12},
    {"name": "wake_up", "file": "wake-up-r01.png", "order": list(range(16)), "fps": 12},
    {"name": "death", "file": "death-r01.png", "order": list(range(16)), "fps": 12},
    {"name": "ring_out", "file": "ring-out-r01.png", "order": list(range(16)), "fps": 12},
    {"name": "spawn", "file": "spawn-r01.png", "order": list(range(16)), "fps": 12},
    {"name": "attack_light_up", "file": "light-up-r01.png", "order": list(range(16)), "fps": 12},
    {"name": "attack_light_down", "file": "light-down-r01.png", "order": list(range(16)), "fps": 12},
    {"name": "attack_dash_light", "file": "dash-light-r01.png", "order": list(range(16)), "fps": 12},
    {"name": "attack_air_light", "file": "air-light-r01.png", "order": list(range(16)), "fps": 12},
    {"name": "attack_heavy_side", "file": "heavy-side-r01.png", "order": list(range(16)), "fps": 12},
    {"name": "attack_heavy_up", "file": "heavy-up-r01.png", "order": list(range(16)), "fps": 12},
    {"name": "attack_heavy_down", "file": "heavy-down-r01.png", "order": list(range(16)), "fps": 12},
    {"name": "attack_dash_heavy", "file": "dash-heavy-r01.png", "order": list(range(16)), "fps": 12},
    {"name": "attack_air_heavy", "file": "air-heavy-r01.png", "order": list(range(16)), "fps": 12},
    {"name": "special_neutral", "file": "special-neutral-r01.png", "order": list(range(16)), "fps": 12},
    {"name": "special_side", "file": "special-side-r01.png", "order": list(range(16)), "fps": 12},
    {"name": "special_up", "file": "special-up-r01.png", "order": list(range(16)), "fps": 12},
    {"name": "special_down", "file": "special-down-r01.png", "order": list(range(16)), "fps": 12},
    {"name": "ultimate", "file": "ultimate-r02.png", "order": list(range(16)), "fps": 12},
]


def component(mask, seeds):
    height, width = mask.shape
    seen = np.zeros_like(mask)
    queue = deque()
    for x, y in seeds:
        if mask[y, x] and not seen[y, x]:
            seen[y, x] = True
            queue.append((x, y))
    while queue:
        x, y = queue.popleft()
        for next_x, next_y in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if (0 <= next_x < width and 0 <= next_y < height
                    and mask[next_y, next_x] and not seen[next_y, next_x]):
                seen[next_y, next_x] = True
                queue.append((next_x, next_y))
    return seen


def extract(cell):
    rgb = np.asarray(cell.convert("RGB")).astype(np.int16)
    height, width = rgb.shape[:2]
    # The review backdrop has a slight two-axis gradient. Reconstruct that
    # gradient from corner patches so it cannot become attached to the pose.
    patch = 8
    corners = [
        np.median(rgb[:patch, :patch], axis=(0, 1)),
        np.median(rgb[:patch, -patch:], axis=(0, 1)),
        np.median(rgb[-patch:, :patch], axis=(0, 1)),
        np.median(rgb[-patch:, -patch:], axis=(0, 1)),
    ]
    x_mix = np.linspace(0.0, 1.0, width)[None, :, None]
    y_mix = np.linspace(0.0, 1.0, height)[:, None, None]
    top = corners[0] * (1.0 - x_mix) + corners[1] * x_mix
    bottom = corners[2] * (1.0 - x_mix) + corners[3] * x_mix
    background = top * (1.0 - y_mix) + bottom * y_mix
    foreground = np.max(np.abs(rgb - background), axis=2) > 48

    # Cross-cell fragments touch an edge. The approved pose is isolated and
    # centred; retain its substantial enclosed components only.
    remaining = foreground.copy()
    silhouette = np.zeros_like(remaining)
    removed_edge_fragments = 0
    parts = []
    while remaining.any():
        y, x = np.argwhere(remaining)[0]
        part = component(remaining, [(int(x), int(y))])
        ys, xs = np.nonzero(part)
        touches_edge = xs.min() == 0 or ys.min() == 0 or xs.max() == width - 1 or ys.max() == height - 1
        if part.sum() >= 50:
            parts.append((part, int(part.sum()), touches_edge))
        remaining[part] = False
    if not parts:
        raise ValueError("empty frame after background extraction")
    primary = max(parts, key=lambda item: item[1])[0]
    for part, size, touches_edge in parts:
        # The evade source has a few frames whose authored hair or ground
        # contact reaches a cell edge. Preserve the largest (pose) component,
        # while rejecting any other edge-connected neighbour fragments.
        if part is primary or not touches_edge:
            silhouette |= part
        else:
            removed_edge_fragments += size

    rgba = np.dstack((rgb.astype(np.uint8), silhouette.astype(np.uint8) * 255))
    rgba[~silhouette, :3] = 0
    image = Image.fromarray(rgba)
    box = image.getbbox()
    if box is None:
        raise ValueError("empty frame after background extraction")
    # The lowest foreground band anchors the average shoe contact point.
    y_grid = np.indices(silhouette.shape)[0]
    ys, xs = np.nonzero(silhouette & (y_grid >= box[3] - 14))
    pivot = ((float(xs.min()) + float(xs.max())) / 2, float(box[3]))
    return image, box, pivot, removed_edge_fragments


def split(source, order):
    frames = []
    for index in order:
        column, row = index % 4, index // 4
        edges = (
            round(column * source.width / 4), round(row * source.height / 4),
            round((column + 1) * source.width / 4), round((row + 1) * source.height / 4),
        )
        try:
            frames.append(extract(source.crop(edges)))
        except ValueError as error:
            raise ValueError(f"source frame {index + 1}: {error}") from error
    return frames


def write_sprite_frames(name, fps):
    lines = [
        '[gd_resource type="SpriteFrames" load_steps=18 format=3]', '',
        f'[ext_resource type="Texture2D" path="res://assets/character/myo-ryung/animation/runtime/local_ai_v01/{name}_16f.png" id="1_sheet"]',
        '',
    ]
    for index in range(16):
        lines += [
            f'[sub_resource type="AtlasTexture" id="AtlasTexture_{index}"]',
            'atlas = ExtResource("1_sheet")',
            f'region = Rect2({index * 128}, 0, 128, 128)', '',
        ]
    frames = ', '.join(
        f'{{"duration": 1.0, "texture": SubResource("AtlasTexture_{index}")}}'
        for index in range(16)
    )
    lines += [
        '[resource]', 'animations = [{', f'"frames": [{frames}],',
        '"loop": false,', f'"name": &"{name}",', f'"speed": {float(fps):.1f}', '}]', '',
    ]
    (RUNTIME / f"{name}.tres").write_text('\n'.join(lines))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    RUNTIME.mkdir(parents=True, exist_ok=True)
    extracted = []
    source_hashes = {}
    for definition in SOURCES:
        path = REVIEW / definition["file"]
        source_hashes[definition["file"]] = hashlib.sha256(path.read_bytes()).hexdigest()
        try:
            extracted.append(split(Image.open(path), definition["order"]))
        except ValueError as error:
            raise ValueError(f"{definition['file']}: {error}") from error

    # Shared scale prevents motion-to-motion size popping. A two-pixel safe
    # edge and y=124 baseline match the other approved local-AI sheets.
    scale = BASE_SCALE
    report = {
        "schema_version": 1,
        "scale": scale,
        "foot_pivot": [64, 124],
        "source_sha256": source_hashes,
        "motions": [],
    }
    for definition, frames in zip(SOURCES, extracted):
        cells = []
        details = []
        for image, box, pivot, removed_edge_fragments in frames:
            frame_scale = min(
                scale,
                60 / max(pivot[0] - box[0], box[2] - pivot[0]),
                118 / (box[3] - box[1]),
            )
            cropped = image.crop(box)
            size = (round(cropped.width * frame_scale), round(cropped.height * frame_scale))
            resized = cropped.resize(size, Image.Resampling.LANCZOS)
            pixels = np.asarray(resized).copy()
            pixels[pixels[:, :, 3] < 8] = 0
            resized = Image.fromarray(pixels)
            x = round(64 - (pivot[0] - box[0]) * frame_scale)
            y = 124 - size[1]
            if x < 2 or y < 2 or x + size[0] > 126 or y + size[1] > 126:
                raise ValueError(f"packing overflow for {definition['name']}")
            cell = Image.new("RGBA", (128, 128))
            cell.alpha_composite(resized, (x, y))
            cells.append(cell)
            details.append({
                "source_box": list(box), "source_pivot": pivot,
                "bounds": cell.getbbox(), "scale": frame_scale,
                "removed_edge_pixels": removed_edge_fragments,
            })

        name = definition["name"]
        sheet = Image.new("RGBA", (2048, 128))
        preview = Image.new("RGB", (768, 768), "#829ba2")
        draw = ImageDraw.Draw(preview)
        for index, cell in enumerate(cells):
            sheet.alpha_composite(cell, (index * 128, 0))
            enlarged = cell.resize((192, 192), Image.Resampling.NEAREST)
            preview.paste(enlarged, ((index % 4) * 192, (index // 4) * 192), enlarged)
            draw.text(((index % 4) * 192 + 4, (index // 4) * 192 + 4), str(index + 1), fill="black")
        sheet_path = OUT / f"{name}_16f.png"
        sheet.save(sheet_path)
        sheet.save(RUNTIME / f"{name}_16f.png")
        write_sprite_frames(name, definition["fps"])
        preview.save(OUT / f"{name}_contact.png")
        playback = []
        for cell in cells:
            background = Image.new("RGBA", (128, 128), "#829ba2")
            background.alpha_composite(cell)
            playback.append(background.convert("RGB").resize((384, 384)))
        duration = 50 if name == "evade" else 83
        playback[0].save(OUT / f"{name}.gif", save_all=True,
                         append_images=playback[1:], duration=duration, loop=0)
        report["motions"].append({
            "name": name, "source": definition["file"], "order": definition["order"],
            "frames": details, "sha256": hashlib.sha256(sheet_path.read_bytes()).hexdigest(),
        })
    (OUT / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"scale": scale, "motions": {
        motion["name"]: motion["sha256"] for motion in report["motions"]
    }}))


if __name__ == "__main__":
    main()
