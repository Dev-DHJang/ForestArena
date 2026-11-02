"""Read-only display metadata shared by motion packaging and review tools.

No values in this module change combat ticks, movement or hit detection.
"""
from __future__ import annotations

import math
from pathlib import Path
import re

COUNTS = (16, 24, 32)
CELL_SIZE = 128


def motion_id(row: dict) -> str:
    return row.get("visual_state_id") or re.sub(r"_(?:16|24|32)f$", "", Path(row["path"]).stem)


def _positive(value, label: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or value <= 0:
        raise ValueError(f"{label} must be finite and positive")
    return float(value)


def _integer(value, label: str) -> int:
    # Godot JSON writers can serialize integer-valued numbers as floats.
    # Keep the source row unchanged; narrow only after checking finite values.
    if isinstance(value, bool) or not isinstance(value, (int, float)) or (
        isinstance(value, float) and (not math.isfinite(value) or not value.is_integer())
    ):
        raise ValueError(f"{label} must be a finite integer value")
    return int(value)


def _frame_range(value, count: int, label: str) -> tuple[int, int]:
    if not isinstance(value, list) or len(value) != 2:
        raise ValueError(f"{label} must be a valid frame range")
    begin, end = (_integer(number, label) for number in value)
    if not 0 <= begin < end <= count:
        raise ValueError(f"{label} must be a valid frame range")
    return begin, end


def _ranges(value, count: int, label: str, length: int):
    if not isinstance(value, list) or len(value) != length:
        raise ValueError(f"{label} must contain {length} ranges")
    start = 0
    for pair in value:
        if not isinstance(pair, list) or len(pair) != 2 or any(isinstance(n, bool) or not isinstance(n, int) for n in pair) or pair[0] != start or not start < pair[1] <= count:
            raise ValueError(f"{label} must cover every frame in ordered non-overlapping ranges")
        start = pair[1]
    if start != count:
        raise ValueError(f"{label} must cover every frame")


def layout(row: dict) -> dict:
    count = row.get("frame_count", 16)
    columns = row.get("atlas_columns", 16)
    cell = row.get("cell_size", CELL_SIZE)
    if isinstance(count, bool) or not isinstance(count, int) or count not in COUNTS:
        raise ValueError("frame_count must be 16, 24 or 32")
    if isinstance(columns, bool) or not isinstance(columns, int) or not 1 <= columns <= min(16, count) or math.ceil(count / columns) > 2:
        raise ValueError("atlas_columns must fit at most 16 columns and two rows")
    if isinstance(cell, bool) or not isinstance(cell, int) or cell != CELL_SIZE:
        raise ValueError("cell_size must be 128")
    durations = row.get("frame_durations", [1.0] * count)
    if not isinstance(durations, list) or len(durations) != count:
        raise ValueError("frame_durations must match frame_count")
    durations = [_positive(value, "frame_durations") for value in durations]
    if "phase_frame_ranges" in row:
        _ranges(row["phase_frame_ranges"], count, "phase_frame_ranges", 3)
    if "equipment_phase_frame_ranges" in row:
        _ranges(row["equipment_phase_frame_ranges"], count, "equipment_phase_frame_ranges", 4)
    if "jump_frame_ranges" in row:
        ranges = row["jump_frame_ranges"]
        keys = ("ascent", "apex", "descent", "landing")
        if not isinstance(ranges, dict) or set(ranges) != set(keys):
            raise ValueError("jump_frame_ranges requires ascent/apex/descent/landing")
        _ranges([ranges[key] for key in keys], count, "jump_frame_ranges", 4)
    for field in ("descent_frame_range", "landing_frame_range"):
        if field in row:
            pair = row[field]
            if not isinstance(pair, list) or len(pair) != 2 or any(isinstance(n, bool) or not isinstance(n, int) for n in pair) or not 0 <= pair[0] < pair[1] <= count:
                raise ValueError(f"{field} must be a valid frame range")
    if "landing_down_frame_range" in row:
        _frame_range(row["landing_down_frame_range"], count, "landing_down_frame_range")
    if "state_duration_ticks" in row and _integer(row["state_duration_ticks"], "state_duration_ticks") <= 0:
        raise ValueError("state_duration_ticks must be positive")
    if "state_hold_frame" in row and not 0 <= _integer(row["state_hold_frame"], "state_hold_frame") < count:
        raise ValueError("state_hold_frame must be inside the declared frame count")
    release_fields = ("launch_release_frame_range", "launch_release_ticks")
    if any(field in row for field in release_fields):
        if not all(field in row for field in release_fields):
            raise ValueError("launch_release_frame_range and launch_release_ticks must be provided together")
        declared_motion = row.get("visual_state_id") or (motion_id(row) if isinstance(row.get("path"), str) else None)
        if declared_motion != "launch":
            raise ValueError("launch_release metadata is allowed only for launch")
        begin, end = _frame_range(row["launch_release_frame_range"], count, "launch_release_frame_range")
        ticks = _integer(row["launch_release_ticks"], "launch_release_ticks")
        if not 1 <= ticks <= 12 or ticks < end - begin:
            raise ValueError("launch_release_ticks must be 1..12 and cover each release drawing")
    if "run_stride_px" in row:
        _positive(row["run_stride_px"], "run_stride_px")
    if "frame_anchors" in row:
        anchors = row["frame_anchors"]
        if not isinstance(anchors, list) or len(anchors) != count:
            raise ValueError("frame_anchors must match frame_count")
        def point(value):
            return isinstance(value, list) and len(value) == 2 and all(not isinstance(n, bool) and isinstance(n, (float, int)) and math.isfinite(n) and 0 <= n <= cell for n in value)
        for frame in anchors:
            if not isinstance(frame, dict) or set(frame) - {"scarf_root", "scarf_hand", "scarf_tips", "claw_hand", "claw_tip", "body_root", "equipment_hand"}:
                raise ValueError("frame_anchors contains an unknown anchor")
            if any(not point(frame[key]) for key in ("scarf_root", "scarf_hand", "claw_hand", "claw_tip", "body_root", "equipment_hand") if key in frame):
                raise ValueError("frame_anchors points must be finite cell coordinates")
            if "scarf_tips" in frame:
                tips = frame["scarf_tips"]
                if not isinstance(tips, list) or len(tips) != 2 or all(tip is None for tip in tips) or any(tip is not None and not point(tip) for tip in tips):
                    raise ValueError("frame_anchors scarf_tips must contain one or two visible cell points")
    return {"frame_count": count, "atlas_columns": columns, "cell_size": cell,
            "rows": math.ceil(count / columns), "sheet_size": (columns * cell, math.ceil(count / columns) * cell),
            "frame_durations": durations}


def frame_box(index: int, spec: dict) -> tuple[int, int, int, int]:
    if not 0 <= index < spec["frame_count"]:
        raise ValueError("frame index outside declared sheet")
    x, y = index % spec["atlas_columns"] * spec["cell_size"], index // spec["atlas_columns"] * spec["cell_size"]
    return x, y, x + spec["cell_size"], y + spec["cell_size"]
