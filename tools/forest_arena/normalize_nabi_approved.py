"""User-approved local extraction/packing of the two approved Nabi reviews.

No generation or pose repainting: border-connected gray removal, largest
silhouette components, one shared scale, foot alignment and approved ordering.
Requires Pillow and numpy. Outputs review artifacts, never edits the inputs.
"""
from collections import deque
from pathlib import Path
import hashlib
import json

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
REVIEW = ROOT / "_workspace/local-ai-playable/motion-review/nabi"
OUT = REVIEW / "normalized"
SOURCES = [("light01-r04.png", list(range(16))),
           ("light02-r01.png", [0, 4, 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15])]


def component(mask, seeds):
    h, w = mask.shape
    seen = np.zeros_like(mask)
    queue = deque()
    for x, y in seeds:
        if mask[y, x] and not seen[y, x]:
            seen[y, x] = True
            queue.append((x, y))
    while queue:
        x, y = queue.popleft()
        for nx, ny in ((x-1, y), (x+1, y), (x, y-1), (x, y+1)):
            if 0 <= nx < w and 0 <= ny < h and mask[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True
                queue.append((nx, ny))
    return seen


def extract(cell):
    rgb = np.asarray(cell.convert("RGB")).astype(np.int16)
    h, w = rgb.shape[:2]
    border = np.concatenate((rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]))
    background = np.median(border, axis=0)
    candidate = np.max(np.abs(rgb - background), axis=2) <= 8
    seeds = [(x, 0) for x in range(w)] + [(x, h-1) for x in range(w)]
    seeds += [(0, y) for y in range(h)] + [(w-1, y) for y in range(h)]
    foreground = ~component(candidate, seeds)
    # Discard detached background islands, not clothing enclosed by outlines.
    remaining = foreground.copy()
    silhouette = np.zeros_like(remaining)
    while remaining.any():
        y, x = np.argwhere(remaining)[0]
        part = component(remaining, [(int(x), int(y))])
        if part.sum() >= 50: silhouette |= part
        remaining[part] = False
    rgba = np.dstack((rgb.astype(np.uint8), silhouette.astype(np.uint8) * 255))
    rgba[~silhouette, :3] = 0
    image = Image.fromarray(rgba)
    box = image.getbbox()
    if box is None: raise ValueError("empty frame")
    if min(box[:2]) <= 0 or box[2] >= w or box[3] >= h:
        raise ValueError("source silhouette touches cell edge")
    ys, xs = np.nonzero(silhouette & (np.indices(silhouette.shape)[0] >= box[3] - 14))
    pivot = ((float(xs.min()) + float(xs.max())) / 2, float(box[3]))
    return image, box, pivot


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    extracted = []
    for filename, order in SOURCES:
        source = Image.open(REVIEW / filename)
        frames = []
        for index in order:
            col, row = index % 4, index // 4
            edges = (round(col * source.width / 4), round(row * source.height / 4),
                     round((col+1) * source.width / 4), round((row+1) * source.height / 4))
            frames.append(extract(source.crop(edges)))
        extracted.append(frames)
    # Center the foot pivot at x64, baseline124, with at least4px side clearance.
    scale = min(min(60 / max(p[0]-b[0], b[2]-p[0]), 118 / (b[3]-b[1]))
                for frames in extracted for _, b, p in frames)
    report = {"scale": scale, "foot_pivot": [64, 124], "motions": []}
    for motion_index, frames in enumerate(extracted, 1):
        cells = []
        details = []
        for image, box, pivot in frames:
            cropped = image.crop(box)
            size = (round(cropped.width * scale), round(cropped.height * scale))
            resized = cropped.resize(size, Image.Resampling.LANCZOS)
            # Remove sub-visible ringing pixels introduced by the reconstruction filter.
            pixels = np.asarray(resized).copy()
            pixels[pixels[:, :, 3] < 8] = 0
            resized = Image.fromarray(pixels)
            x = round(64 - (pivot[0] - box[0]) * scale)
            y = 124 - size[1]
            if x < 2 or y < 2 or x + size[0] > 126: raise ValueError("packing overflow")
            cell = Image.new("RGBA", (128, 128))
            cell.alpha_composite(resized, (x, y))
            cells.append(cell)
            details.append({"source_box": list(box), "source_pivot": pivot, "bounds": cell.getbbox()})
        name = f"attack_light_combo_{motion_index:02d}"
        sheet = Image.new("RGBA", (2048, 128))
        preview = Image.new("RGB", (768, 768), "#829ba2")
        draw = ImageDraw.Draw(preview)
        for index, cell in enumerate(cells):
            sheet.alpha_composite(cell, (index * 128, 0))
            enlarged = cell.resize((192, 192), Image.Resampling.NEAREST)
            preview.paste(enlarged, ((index % 4)*192, (index//4)*192), enlarged)
            draw.text(((index % 4)*192+4, (index//4)*192+4), str(index+1), fill="black")
        sheet_path = OUT / f"{name}_16f.png"
        sheet.save(sheet_path)
        preview.save(OUT / f"{name}_contact.png")
        playback = []
        for cell in cells:
            background = Image.new("RGBA", (128, 128), "#829ba2")
            background.alpha_composite(cell)
            playback.append(background.convert("RGB").resize((384, 384)))
        playback[0].save(OUT / f"{name}.gif", save_all=True, append_images=playback[1:], duration=83, loop=0)
        report["motions"].append({"name": name, "source": SOURCES[motion_index-1][0],
            "order": SOURCES[motion_index-1][1], "frames": details,
            "sha256": hashlib.sha256(sheet_path.read_bytes()).hexdigest()})
    (OUT / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"scale": scale, "motions": [m["sha256"] for m in report["motions"]]}))


if __name__ == "__main__": main()
