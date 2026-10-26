"""Lay out approved-appearance source poses as review-only SpriteFrames.

This converts positions and a single scale for an entire motion. It never
repaints, stretches an individual pose, changes combat data, or registers art.
Each source sheet receives one uniform scale chosen to keep that character's head size
consistent across sheets; folded and lying poses may be shorter than idle.
"""

import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path

from PIL import Image


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


parser = argparse.ArgumentParser()
parser.add_argument("spec", type=Path, help="Review-only JSON with source paths and layout settings")
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
base = Path(__file__).resolve().parent
spec_path = args.spec if args.spec.is_absolute() else root / args.spec
spec = json.loads(spec_path.read_text())
assert spec.get("kind") == "remaining-motion-layout"
character = spec["character_id"]
motion = spec["motion"]
sources = [root / p for p in spec["source_paths"]]
assert 1 <= len(sources) <= 2 and all(p.is_file() for p in sources)
columns = int(spec.get("source_columns", 4))
rows_per_source = int(spec.get("source_rows", 4))
count = columns * rows_per_source * len(sources)
assert count in (16, 24, 32) and columns in (4, 6, 8)
images = [Image.open(p).convert("RGBA") for p in sources]
for index, im in enumerate(images):
    alpha = im.getchannel("A")
    edge_max = max(alpha.crop(box).getextrema()[1] for box in (
        (0, 0, im.width, 1), (0, im.height - 1, im.width, im.height),
        (0, 0, 1, im.height), (im.width - 1, 0, im.width, im.height)))
    assert edge_max < 32, f"source image touches outer edge: {sources[index]}"

split_spec = importlib.util.spec_from_file_location("split_figures", base / "split-figures.py")
split = importlib.util.module_from_spec(split_spec)
split_spec.loader.exec_module(split)
figures = []
unused = []
for source_index, im in enumerate(images):
    source_figures, source_unused = split.split_figures(im, columns, rows_per_source)
    figures.extend((figure, box, source_index, frame_index % columns,
                    frame_index // columns) for frame_index, (figure, box) in enumerate(source_figures))
    unused.extend(dict(region, source_index=source_index) for region in source_unused)
assert len(figures) == count
source_cell_sizes = [(im.width / columns, im.height / rows_per_source) for im in images]
reference_scale = float(spec["source_to_cell_scale"])
source_factors = spec.get("source_scale_multipliers", [1.0] * len(images))
assert len(source_factors) == len(images)
source_factors = [float(value) for value in source_factors]
assert all(math.isfinite(value) and 0.5 <= value <= 2.0 for value in source_factors)
display_scale = float(spec["presentation_scale"])
baseline = float(spec["source_baseline_y"])
target_baseline = float(spec.get("target_baseline_y", 124))
assert 0 < reference_scale <= 1 and 0 < display_scale <= 3
assert all(0 < baseline <= cell_height * 1.25 for _, cell_height in source_cell_sizes)

# One whole-motion fit scale keeps the source figures complete in 128px cells.
# Compensating the display scale preserves the chosen common world head size.
left_extent = right_extent = upper_extent = lower_extent = 0.0
for _, box, source_index, col, row in figures:
    source_cell_width, source_cell_height = source_cell_sizes[source_index]
    left_extent = max(left_extent, ((col + 0.5) * source_cell_width - box[0]) * source_factors[source_index])
    right_extent = max(right_extent, (box[2] - (col + 0.5) * source_cell_width) * source_factors[source_index])
    upper_extent = max(upper_extent, (baseline - (box[1] - row * source_cell_height)) * source_factors[source_index])
    lower_extent = max(lower_extent, ((box[3] - row * source_cell_height) - baseline) * source_factors[source_index])
limits = [reference_scale, 63 / max(left_extent, 1), 63 / max(right_extent, 1),
          (target_baseline - 1) / max(upper_extent, 1),
          (127 - target_baseline) / max(lower_extent, 1)]
scale = min(limits)
assert scale > 0 and scale >= reference_scale * float(spec.get("min_fit_fraction", 0.65)), ("source pose too wide/tall", scale, reference_scale)
world_scale = display_scale * reference_scale / scale

sheet = Image.new("RGBA", (2048, math.ceil(count / 16) * 128))
frame_bounds = []
for index, (figure, box, source_index, col, row) in enumerate(figures):
    source_cell_width, source_cell_height = source_cell_sizes[source_index]
    effective_scale = scale * source_factors[source_index]
    sized = figure.resize((max(1, round(figure.width * effective_scale)), max(1, round(figure.height * effective_scale))), Image.Resampling.LANCZOS)
    x = round(64 + (box[0] - (col + 0.5) * source_cell_width) * effective_scale)
    y = round(target_baseline + (box[1] - row * source_cell_height - baseline) * effective_scale)
    visible = sized.getchannel("A").point(lambda value: 255 if value >= 32 else 0).getbbox()
    assert visible is not None
    frame_box = [x + visible[0], y + visible[1], x + visible[2], y + visible[3]]
    assert min(frame_box[:2]) >= 1 and max(frame_box[2:]) <= 127, ("packed pose clipped", index, frame_box)
    sheet.alpha_composite(sized, (index % 16 * 128 + x, index // 16 * 128 + y))
    frame_bounds.append(frame_box)

phase = spec.get("phase_frame_ranges", [])
if phase:
    assert len(phase) == 3 and phase[0][0] == 0 and phase[2][1] == count
    assert phase[0][1] == phase[1][0] and phase[1][1] == phase[2][0]
    assert all(begin < end for begin, end in phase)
    combat_ticks = spec["actual_attack_timings_60hz"]
    assert len(combat_ticks) == 3 and all(int(value) > 0 for value in combat_ticks)
    assert all(end - begin <= int(combat_ticks[index]) for index, (begin, end) in enumerate(phase)), "authored phase exceeds actual combat ticks"
durations = spec.get("frame_durations", [1.0] * count)
assert len(durations) == count and all(float(value) > 0 for value in durations)
fps = float(spec.get("fps", 12))
loop = bool(spec.get("loop", False))
frames_anchors = spec.get("frame_anchors", [])
source_anchors = spec.get("source_frame_anchors", [])
assert not (frames_anchors and source_anchors)
assert not frames_anchors or len(frames_anchors) == count
assert not source_anchors or len(source_anchors) == count
if source_anchors:
    def packed_point(point, source_index):
        assert isinstance(point, list) and len(point) == 2
        source_cell_width = source_cell_sizes[source_index][0]
        x = 64 + (float(point[0]) - source_cell_width / 2) * scale * source_factors[source_index]
        y = target_baseline + (float(point[1]) - baseline) * scale * source_factors[source_index]
        assert 0 <= x <= 128 and 0 <= y <= 128, ("source anchor outside packed cell", point, x, y)
        return [round(x, 2), round(y, 2)]

    frames_anchors = []
    for index, frame in enumerate(source_anchors):
        assert isinstance(frame, dict)
        source_index = index // (columns * rows_per_source)
        converted = {}
        for key, value in frame.items():
            if key == "scarf_tips":
                assert isinstance(value, list) and len(value) == 2
                assert any(point is not None for point in value)
                converted[key] = [packed_point(point, source_index) if point is not None else None for point in value]
            else:
                assert key in ("scarf_root", "scarf_hand", "claw_hand", "claw_tip", "body_root")
                converted[key] = packed_point(value, source_index)
        frames_anchors.append(converted)
output_directory = spec.get("candidate_output_directory")
if output_directory is None:
    folder = base / "candidates" / "remaining" / character
else:
    folder = (root / output_directory).resolve()
    assert folder.is_relative_to(root / "_workspace"), "review candidates must stay inside _workspace"
folder.mkdir(parents=True, exist_ok=True)
version = spec.get("version", "r01")
png = folder / f"{motion}_{count}f_{version}.png"
tres = folder / f"{motion}_{version}.tres"
row_path = folder / f"{motion}_{version}.json"
sheet.save(png)

lines = [f'[gd_resource type="SpriteFrames" load_steps={count + 2} format=3]', '',
         f'[ext_resource type="Texture2D" path="res://{png.relative_to(root).as_posix()}" id="1"]']
for index in range(count):
    lines.extend(['', f'[sub_resource type="AtlasTexture" id="Frame_{index}"]',
                  'atlas = ExtResource("1")',
                  f'region = Rect2({index % 16 * 128}, {index // 16 * 128}, 128, 128)'])
frames = ', '.join('{"duration": %s, "texture": SubResource("Frame_%d")}' % (float(duration), index) for index, duration in enumerate(durations))
lines.extend(['', '[resource]', 'animations = [{', f'"frames": [{frames}],',
              f'"loop": {str(loop).lower()},', f'"name": &"{motion}",',
              f'"speed": {fps}', '}]'])
tres.write_text('\n'.join(lines) + '\n')

record = {
    "type": "animation-candidate", "character_id": character,
    "visual_state_id": motion, "path": png.relative_to(root).as_posix(),
    "sprite_frames_path": "res://" + tres.relative_to(root).as_posix(),
    "sha256": digest(png), "frame_count": count, "atlas_columns": 16,
    "cell_size": 128, "frame_durations": durations, "fps": fps, "loop": loop,
    "presentation_scale": world_scale, "foot_pivot_y": target_baseline,
    "source_paths": [p.relative_to(root).as_posix() for p in sources],
    "source_sha256": [digest(p) for p in sources],
    "expected_action": spec["expected_action"],
    "action_source": spec.get("action_source", "_workspace/motion-naturalness-v1/remaining-motion-brief.json"),
    "conversion": {"method": "original connected figures; uniform scale per source sheet, shared display scale and cell placement; no per-pose or body-part warping",
                   "uniform_scale": scale, "per_source_uniform_scales": [scale * factor for factor in source_factors], "source_scale_multipliers": source_factors, "reference_scale": reference_scale,
                   "presentation_scale": world_scale, "source_baseline_y": baseline,
                   "target_baseline_y": target_baseline, "frame_bounds": frame_bounds,
                   "unassigned_small_regions": unused, "spec_path": spec_path.relative_to(root).as_posix(),
                   "spec_sha256": digest(spec_path)},
}
for key in ("phase_frame_ranges", "frame_anchors", "state_duration_ticks", "state_hold_frame",
            "landing_down_frame_range", "run_stride_px", "actual_attack_timings_60hz"):
    if key in spec:
        record[key] = spec[key]
if frames_anchors:
    record["frame_anchors"] = frames_anchors
row_path.write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n')
print(row_path.relative_to(root))
