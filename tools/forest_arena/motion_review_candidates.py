"""Strict, read-only candidate scope preflight shared by Python and Godot review tools."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import re

from motion_layout import layout, motion_id


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def local_path(root: Path, value: str, *, candidate: bool = False) -> Path:
    if not isinstance(value, str):
        raise ValueError("path must be a string")
    raw = value.removeprefix("res://")
    path = Path(raw)
    if not raw or path.is_absolute() or "\\" in raw or any(p in {"..", "."} for p in raw.split("/")) or "//" in raw or ":" in raw:
        raise ValueError(f"unsafe path: {value}")
    resolved = (root / path).resolve()
    if not resolved.is_relative_to(root.resolve()) or not resolved.is_file():
        raise ValueError(f"missing or escaping project file: {value}")
    if candidate and (not raw.startswith("_workspace/") or not resolved.is_relative_to((root / "_workspace").resolve())):
        raise ValueError(f"unapproved candidate must stay inside _workspace: {value}")
    return resolved



# These fields affect the actual selected drawing, placement or playback. A
# layout-only candidate may change only presentation_scale, never these values.
LAYOUT_ONLY_FIXED_FIELDS = (
    "frame_count", "atlas_columns", "cell_size", "frame_durations", "fps", "loop",
    "phase_frame_ranges", "jump_frame_ranges", "descent_frame_range", "landing_frame_range",
    "landing_down_frame_range", "run_stride_px", "frame_anchors", "foot_pivot_y",
    "state_hold_frame", "state_duration_ticks", "launch_release_frame_range", "launch_release_ticks",
)


def layout_only_source(root: Path, row: dict, manifest: list[dict]) -> dict | None:
    """Verify a copied approved drawing whose pending change is only its scale."""
    if "layout_only_from_asset_id" not in row:
        return None
    identifier = row["layout_only_from_asset_id"]
    sources = [entry for entry in manifest if entry.get("type") == "animation-runtime"
               and entry.get("asset_id") == identifier]
    if not isinstance(identifier, str) or not identifier or len(sources) != 1:
        raise ValueError("layout-only candidate requires one exact registered asset ID")
    source = sources[0]
    if (row.get("type") != "animation-candidate" or row.get("reuse_approved_runtime")
            or row.get("character_id") != source.get("character_id") or motion_id(row) != motion_id(source)):
        raise ValueError("layout-only candidate must match its registered character and motion")
    scale = row.get("presentation_scale")
    if isinstance(scale, bool) or not isinstance(scale, (int, float)) or not math.isfinite(scale) or scale <= 0:
        raise ValueError("layout-only presentation_scale must be finite and positive")
    if scale == source.get("presentation_scale", 1.0):
        raise ValueError("layout-only candidate must change presentation_scale")
    if any(row.get(field) != source.get(field) for field in LAYOUT_ONLY_FIXED_FIELDS):
        raise ValueError("layout-only candidate cannot change frame composition or playback metadata")
    approved_png = local_path(root, source.get("path", ""))
    candidate_png = local_path(root, row.get("path", ""), candidate=True)
    png_sha = digest(approved_png)
    if digest(candidate_png) != png_sha or row.get("sha256") != png_sha or source.get("sha256") != png_sha:
        raise ValueError("layout-only PNG bytes must match the exact registered drawing")
    approved_sprite = local_path(root, source.get("sprite_frames_path", "")).read_text()
    candidate_sprite = local_path(root, row.get("sprite_frames_path", ""), candidate=True).read_text()
    old_texture = 'path="res://' + str(source["path"]).removeprefix("res://") + '"'
    new_texture = 'path="res://' + str(row["path"]).removeprefix("res://") + '"'
    if approved_sprite.count(old_texture) != 1 or candidate_sprite != approved_sprite.replace(old_texture, new_texture, 1):
        raise ValueError("layout-only SpriteFrames must differ only in its PNG reference")
    return source


def load_selection(root: Path, catalog: Path, scope: Path, scope_sha256: str | None = None) -> dict:
    root = root.resolve()
    for path in (catalog, scope):
        if not path.resolve().is_relative_to((root / "_workspace").resolve()) or not path.is_file():
            raise ValueError("candidate catalog and scope must be project _workspace files")
    if scope_sha256 is not None and digest(scope) != scope_sha256:
        raise ValueError("scope original SHA256 changed")
    document = json.loads(catalog.read_text())
    selected = json.loads(scope.read_text())
    if not isinstance(document, dict) or not isinstance(selected, dict):
        raise ValueError("candidate catalog and scope must be JSON objects")
    if document.get("schema_version") != 1 or document.get("kind") != "motion-candidates" or document.get("approval_status") != "pending":
        raise ValueError("candidate catalog must declare pending motion-candidates schema 1")
    if selected.get("schema_version") != 1 or selected.get("kind") != "candidate-motion-review":
        raise ValueError("invalid explicit candidate review scope")
    if selected.get("catalog_sha256") != digest(catalog):
        raise ValueError("scope catalog SHA256 changed")
    rows = document.get("assets", [])
    if not isinstance(rows, list) or not rows:
        raise ValueError("candidate catalog must contain motions")
    manifest_path = root / "assets/character/manifest.json"
    manifest = json.loads(manifest_path.read_text())["assets"]
    known_characters = {row.get("character_id") for row in manifest if isinstance(row.get("character_id"), str)}
    keys, paths, pending_paths, layout_sources = set(), set(), set(), set()
    for row in rows:
        if not isinstance(row, dict):
            raise ValueError("candidate asset must be an object")
        cid, motion = row.get("character_id"), row.get("visual_state_id")
        if cid not in known_characters or not isinstance(motion, str) or not re.fullmatch(r"[a-z][a-z0-9_-]*", motion):
            raise ValueError("unknown character or invalid motion ID")
        layout(row)
        key = (cid, motion)
        if key in keys:
            raise ValueError("duplicate candidate motion")
        keys.add(key)
        reuse = row.get("type") == "animation-runtime" and row.get("reuse_approved_runtime") is True
        if row.get("type") != "animation-candidate" and not reuse:
            raise ValueError("candidate row requires animation-candidate or explicitly approved runtime reuse")
        if reuse:
            registered = [entry for entry in manifest if entry.get("type") == "animation-runtime" and entry.get("character_id") == cid and motion_id(entry) == motion]
            if len(registered) != 1 or any(row.get(field) != registered[0].get(field) for field in ("path", "sprite_frames_path", "fps", "loop", "frame_count", "atlas_columns", "cell_size", "frame_durations", "jump_frame_ranges", "run_stride_px", "frame_anchors")):
                raise ValueError("approved runtime reuse must exactly match the registered PNG/SpriteFrames/fps/loop")
        if not isinstance(row.get("fps"), (int, float)) or isinstance(row["fps"], bool) or not 0 < row["fps"] <= 120 or not isinstance(row.get("loop"), bool):
            raise ValueError("candidate fps/loop is invalid")
        for field, suffix in (("path", ".png"), ("sprite_frames_path", ".tres")):
            path = local_path(root, row.get(field, ""), candidate=not reuse)
            if path.suffix != suffix or path in paths:
                raise ValueError("duplicate candidate asset path or wrong extension")
            paths.add(path)
            if not reuse: pending_paths.add(path)
        if str(row["path"]).startswith("res://") or not str(row["sprite_frames_path"]).startswith("res://") or str(row.get("action_source", "")).startswith("res://"):
            raise ValueError("PNG/action source paths must be project-relative and SpriteFrames must use res://")
        if not isinstance(row.get("expected_action"), str) or not row["expected_action"].strip():
            raise ValueError("candidate requires an explicit expected action")
        local_path(root, row.get("action_source", ""))
        copied_source = layout_only_source(root, row, manifest)
        if copied_source is not None:
            layout_sources.update(str(copied_source[field]).removeprefix("res://") for field in ("path", "sprite_frames_path"))
        # A candidate cannot already be exposed through the approved manifest,
        # nor can a copy of its bytes be registered there under another name.
        for approved in ([] if reuse else manifest):
            if approved.get("type") != "animation-runtime":
                continue
            for field in ("path", "sprite_frames_path"):
                published = root / str(approved.get(field, "")).removeprefix("res://")
                candidate_path = local_path(root, row[field], candidate=True)
                if published.is_file() and (published.resolve() == candidate_path or digest(published) == digest(candidate_path)):
                    if copied_source is approved and field == "path" and published.resolve() != candidate_path:
                        continue
                    raise ValueError("unapproved candidate is already exposed in runtime manifest")
    candidate_paths = {str(path.relative_to(root)) for path in pending_paths}
    for directory in ("scripts", "scenes", "assets", "forest_arena/data"):
        for consumer in (root / directory).rglob("*"):
            if consumer.is_file() and consumer.suffix in {".gd", ".tscn", ".tres", ".json"}:
                text = consumer.read_text(errors="replace")
                if any(path in text for path in candidate_paths):
                    raise ValueError(f"unapproved candidate exposed by runtime consumer: {consumer.relative_to(root)}")
    for row in rows:
        sprite = local_path(root, row["sprite_frames_path"], candidate=row.get("type") == "animation-candidate").read_text()
        resources = re.findall(r"\[ext_resource([^\]]*)\]", sprite, flags=re.S)
        references = [dict(re.findall(r'(\w+)\s*=\s*"([^"]*)"', spec)) for spec in resources]
        expected_texture = "res://" + str(row["path"]).removeprefix("res://")
        subtypes = re.findall(r'\[sub_resource\s+type="([^"]+)"', sprite)
        if len(references) != 1 or references[0].get("type") != "Texture2D" or references[0].get("path") != expected_texture or set(references[0]) - {"type", "path", "id"} or 'type="SpriteFrames"' not in sprite or re.search(r"\bscript\s*=", sprite) or any(kind != "AtlasTexture" for kind in subtypes):
            raise ValueError("candidate SpriteFrames must reference only its declared PNG without scripts")
    scope_rows = selected.get("motions", [])
    if not isinstance(scope_rows, list) or any(not isinstance(row, dict) for row in scope_rows):
        raise ValueError("invalid scope motions")
    scoped = [(row.get("character_id"), row.get("motion")) for row in scope_rows]
    if len(set(scoped)) != len(scoped):
        raise ValueError("duplicate scope motion")
    if set(scoped) != keys:
        raise ValueError("missing or unknown scope motion; catalog coverage must match exactly")
    attack_sources = document.get("attack_sources", [])
    if not isinstance(attack_sources, list) or not attack_sources or len(attack_sources) != len(set(attack_sources)):
        raise ValueError("candidate requires explicit unique AttackData source paths")
    for source in attack_sources:
        if local_path(root, source).suffix != ".tres":
            raise ValueError("AttackData source must be a tres resource")
    character_movesets = document.get("character_movesets", {})
    if not isinstance(character_movesets, dict) or set(character_movesets) != {row["character_id"] for row in rows}:
        raise ValueError("candidate requires exact character_movesets mapping for every scoped character")
    if any(path not in attack_sources for path in character_movesets.values()):
        raise ValueError("character_movesets must refer to explicitly pinned AttackData sources")
    mandatory = ["assets/character/manifest.json", "scripts/local_fighter_presentation.gd", "scripts/fighter_controller.gd", "docs/contracts/attack-system-v01.json", "docs/gameplay/combat.md", "tools/forest_arena/motion_review_timeline.gd", "tools/forest_arena/motion_review_candidate_frames.gd", "tools/forest_arena/motion_review_candidates.py", "tools/forest_arena/review_motion_actions.py", "tools/forest_arena/motion_layout.py"]
    for source in ("scripts/data/attack_data.gd", "scripts/data/combat_rules.gd", "scripts/fighter_attack_effects.gd"):
        if (root / source).is_file(): mandatory.append(source)
    required = set(mandatory + attack_sources) | layout_sources
    for row in rows:
        required.update(str(row[field]).removeprefix("res://") for field in ("path", "sprite_frames_path", "action_source"))
    required.update(str(path.resolve().relative_to(root)) for path in (catalog, scope))
    for source in required: local_path(root, source)
    return {"rows": rows, "character_movesets": character_movesets, "required_sources": sorted(required), "candidate_selection": {"catalog_path": str(catalog.resolve().relative_to(root)), "catalog_sha256": digest(catalog), "scope_path": str(scope.resolve().relative_to(root)), "scope_sha256": digest(scope), "approval_status": "pending"}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root", required=True, type=Path)
    parser.add_argument("--catalog", required=True, type=Path)
    parser.add_argument("--scope", required=True, type=Path)
    parser.add_argument("--scope-sha256")
    args = parser.parse_args()
    try:
        print(json.dumps(load_selection(args.project_root, args.catalog, args.scope, args.scope_sha256), ensure_ascii=False))
    except (ValueError, OSError, KeyError, TypeError) as error:
        parser.exit(1, f"candidate preflight failed: {error}\n")


if __name__ == "__main__":
    main()
