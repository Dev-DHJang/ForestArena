"""Plan or install individually user-approved 16/24/32-frame candidates.

Default operation is read-only. Historical batch-specific installers are not
used. Installation requires a human approval record bound to this exact plan;
QA pass alone never grants permission to register artwork.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
import re

from PIL import Image

from motion_layout import layout, motion_id
from motion_review_candidates import load_selection, local_path
from review_motion_actions import validate

MANIFEST = "assets/character/manifest.json"
DISPLAY_FIELDS = ("frame_count", "atlas_columns", "cell_size", "frame_durations", "fps", "loop",
                  "phase_frame_ranges", "jump_frame_ranges", "descent_frame_range", "landing_frame_range", "landing_down_frame_range",
                  "run_stride_px", "frame_anchors", "presentation_scale", "foot_pivot_y", "state_hold_frame", "state_duration_ticks",
                  "launch_release_frame_range", "launch_release_ticks",
                  "hit_reaction_lead_frame_range", "hit_reaction_lead_ticks")
PROVENANCE_FIELDS = ("source_path", "source_sha256", "creation", "rights", "conversion")


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def encoded(document: dict) -> bytes:
    return (json.dumps(document, ensure_ascii=False, indent=2) + "\n").encode()


def document(path: Path) -> dict:
    value = json.loads(path.read_text())
    if not isinstance(value, dict):
        raise ValueError("record must be a JSON object")
    return value


def relative(root: Path, path: Path) -> str:
    try:
        return str(path.resolve().relative_to(root.resolve()))
    except ValueError as error:
        raise ValueError("record must stay inside project") from error


def planned_path(root: Path, value: str, prefix: Path, suffix: str) -> Path:
    if not isinstance(value, str):
        raise ValueError("planned path must be a string")
    raw = value.removeprefix("res://")
    if not raw or Path(raw).is_absolute() or "\\" in raw or ":" in raw or any(p in {".", "..", ""} for p in raw.split("/")):
        raise ValueError("unsafe registration target")
    target = (root / raw).resolve()
    if not target.is_relative_to(prefix.resolve()) or target.suffix != suffix:
        raise ValueError("registration target outside its character runtime directory")
    return target


def candidate_provenance(root: Path, source: dict) -> dict:
    """A replacement's origin belongs to its new drawing, never the old entry."""
    if any(field not in source for field in PROVENANCE_FIELDS):
        raise ValueError("registration requires explicit source_path/source_sha256/creation/rights/conversion")
    origin = local_path(root, source["source_path"])
    if origin.suffix != ".png" or source["source_sha256"] != digest(origin.read_bytes()):
        raise ValueError("candidate original source PNG SHA256 differs from its bytes")
    for field, required in (("creation", ("method", "provider", "version")),
                            ("rights", ("status",)), ("conversion", ("method",))):
        value = source[field]
        if not isinstance(value, dict) or any(not isinstance(value.get(key), str) or not value[key].strip() for key in required):
            raise ValueError(f"candidate {field} requires explicit nonempty {', '.join(required)}")
    references = source["rights"].get("references")
    if not isinstance(references, list) or any(not isinstance(value, str) or not value.strip() for value in references):
        raise ValueError("candidate rights requires an explicit references list")
    return {field: copy.deepcopy(source[field]) for field in PROVENANCE_FIELDS}


def plan_registration(root: Path, catalog: Path, scope: Path, scope_sha256: str, review: Path, targets: Path) -> tuple[dict, dict[str, bytes]]:
    """Return a reproducible plan and final bytes without changing any file."""
    root = root.resolve()
    selected = load_selection(root, catalog, scope, scope_sha256)
    failures = validate(root, review, True, catalog, scope, scope_sha256)
    if failures:
        raise ValueError("independent QA review is not current/pass: " + "; ".join(failures))
    config = document(targets)
    if config.get("schema_version") != 1 or config.get("kind") != "motion-registration-targets":
        raise ValueError("invalid registration targets schema")
    config_path = relative(root, targets)
    if not config_path.startswith("_workspace/"):
        raise ValueError("registration targets must stay inside _workspace")
    approval_path = planned_path(root, config.get("approval_record"), root / "_workspace", ".json")
    approved_record = relative(root, approval_path)
    rows = [row for row in selected["rows"] if not row.get("reuse_approved_runtime", False)]
    wanted = {(row["character_id"], motion_id(row)): row for row in rows}
    declared = config.get("motions")
    if not isinstance(declared, list) or any(not isinstance(row, dict) for row in declared):
        raise ValueError("registration targets must declare motions")
    keys = [(row.get("character_id"), row.get("motion")) for row in declared]
    if len(set(keys)) != len(keys) or set(keys) != set(wanted):
        raise ValueError("registration targets must cover each pending candidate exactly once")
    original = document(root / MANIFEST)
    updated = copy.deepcopy(original)
    current = {(row.get("character_id"), motion_id(row)): row for row in updated["assets"] if row.get("type") == "animation-runtime"}
    if len(current) != sum(row.get("type") == "animation-runtime" for row in updated["assets"]):
        raise ValueError("runtime manifest contains duplicate motions")
    ids = {row.get("asset_id") for row in updated["assets"]}
    consumers = {row.get("sprite_frames_path") for row in updated["assets"] if row.get("type") == "animation-runtime"}
    sources = {relative(root, local_path(root, row[field])) for row in rows for field in ("path", "sprite_frames_path")}
    pending = {}
    motions = []
    for target in declared:
        key = target["character_id"], target["motion"]
        source = wanted[key]
        provenance = candidate_provenance(root, source)
        spec = layout(source)
        runtime = root / "assets/character" / key[0] / "animation/runtime"
        png = planned_path(root, target.get("png_path"), runtime, ".png")
        sprite = planned_path(root, target.get("sprite_frames_path"), runtime, ".tres")
        png_path, sprite_path = relative(root, png), relative(root, sprite)
        if png.exists() or png_path in pending or png_path in sources:
            raise ValueError("new versioned PNG must not overwrite any existing file")
        if not re.fullmatch(r".+_%df(?:_[a-zA-Z0-9-]+)+\.png" % spec["frame_count"], png.name):
            raise ValueError("new PNG name requires declared _<count>f and an explicit version suffix")
        if sprite_path in pending or sprite_path in sources:
            raise ValueError("duplicate or pending SpriteFrames target")
        asset_id = target.get("asset_id")
        if not isinstance(asset_id, str) or not re.fullmatch(r"[a-z][a-z0-9-]*", asset_id):
            raise ValueError("explicit stable asset_id is required")
        existing = current.get(key)
        if existing is not None:
            if asset_id != existing.get("asset_id") or "res://" + sprite_path != existing.get("sprite_frames_path") or existing.get("consumer_path") != existing.get("sprite_frames_path") or not sprite.is_file():
                raise ValueError("replacement must preserve its existing logical ID and SpriteFrames consumer path")
            history = copy.deepcopy(existing.get("registration_history", []))
            if not isinstance(history, list):
                raise ValueError("existing registration_history must be a list")
            history.append({field: copy.deepcopy(value) for field, value in existing.items() if field != "registration_history"})
            # Keep old source/rights/approval records as history, not as the
            # current drawing's origin. Avoid recursively nesting that history.
            existing.clear()
            existing.update({field: copy.deepcopy(value) for field, value in source.items() if field not in {"expected_action", "action_source", "reuse_approved_runtime", "registration_history", "motion_registration"}})
            existing["registration_history"] = history
            result = existing
        else:
            if asset_id in ids or sprite.exists() or "res://" + sprite_path in consumers:
                raise ValueError("new motion asset ID/consumer path already exists")
            result = {field: copy.deepcopy(value) for field, value in source.items() if field not in {"expected_action", "action_source", "reuse_approved_runtime", "registration_history", "motion_registration"}}
            updated["assets"].append(result)
            ids.add(asset_id)
            consumers.add("res://" + sprite_path)
        source_png = local_path(root, source["path"], candidate=True)
        png_bytes = source_png.read_bytes()
        if source.get("sha256") is not None and source["sha256"] != digest(png_bytes):
            raise ValueError("candidate declared PNG SHA256 differs from its bytes")
        with Image.open(source_png, formats=["PNG"]) as image:
            if image.mode != "RGBA" or image.size != spec["sheet_size"]:
                raise ValueError("candidate PNG does not match declared layout")
            for index in range(spec["frame_count"], spec["atlas_columns"] * spec["rows"]):
                x,y=index % spec["atlas_columns"] * 128,index // spec["atlas_columns"] * 128
                if image.crop((x,y,x+128,y+128)).getchannel("A").getbbox() is not None:
                    raise ValueError("unused atlas cell must be transparent")
        candidate_sprite = local_path(root, source["sprite_frames_path"], candidate=True)
        source_text = candidate_sprite.read_text()
        old_reference = 'path="res://' + source["path"] + '"'
        if source_text.count(old_reference) != 1:
            raise ValueError("candidate SpriteFrames must have exactly one declared PNG reference")
        sprite_bytes = source_text.replace(old_reference, 'path="res://' + png_path + '"').encode()
        if b"res://_workspace/" in sprite_bytes:
            raise ValueError("registered SpriteFrames cannot reference workspace assets")
        for field in DISPLAY_FIELDS:
            result.pop(field, None)
            if field in source: result[field] = copy.deepcopy(source[field])
        result.update(asset_id=asset_id,type="animation-runtime",path=png_path,sha256=digest(png_bytes),
                      visual_state_id=key[1],sprite_frames_path="res://"+sprite_path,consumer_path="res://"+sprite_path)
        result["frame_count"] = spec["frame_count"]
        result["motion_registration"] = {"catalog_path":relative(root,catalog),"catalog_sha256":digest(catalog.read_bytes()),
            "scope_path":relative(root,scope),"scope_sha256":scope_sha256,"qa_review_path":relative(root,review),
            "qa_review_sha256":digest(review.read_bytes()),"candidate_png_path":source["path"],
            "candidate_sprite_frames_path":source["sprite_frames_path"],"candidate_sprite_frames_sha256":digest(candidate_sprite.read_bytes()),
            "approval_record":approved_record, "provenance":provenance}
        pending[png_path], pending[sprite_path] = png_bytes, sprite_bytes
        motions.append({"character_id":key[0],"motion":key[1],"asset_id":asset_id,"png_path":png_path,
            "png_sha256":digest(png_bytes),"candidate_sprite_frames_sha256":digest(candidate_sprite.read_bytes()),
            "sprite_frames_path":"res://"+sprite_path,"registered_sprite_frames_sha256":digest(sprite_bytes),"operation":"replace" if existing else "add"})
    pending[MANIFEST] = encoded(updated)
    plan = {"schema_version":1,"kind":"motion-registration-plan","registrar_sha256":digest(Path(__file__).read_bytes()),"layout_validator_sha256":digest(Path(__file__).with_name("motion_layout.py").read_bytes()),"catalog_path":relative(root,catalog),"catalog_sha256":digest(catalog.read_bytes()),
        "scope_path":relative(root,scope),"scope_sha256":scope_sha256,"qa_review_path":relative(root,review),"qa_review_sha256":digest(review.read_bytes()),
        "registration_targets_path":config_path,"registration_targets_sha256":digest(targets.read_bytes()),"approval_record":approved_record,
        "motions":motions,"outputs":[{"path":path,"before_sha256":digest((root/path).read_bytes()) if (root/path).is_file() else None,"after_sha256":digest(data)} for path,data in sorted(pending.items())]}
    return plan, pending


def plan_digest(plan: dict) -> str:
    return digest(json.dumps(plan,ensure_ascii=False,sort_keys=True,separators=(",", ":")).encode())


def verify_approval(root: Path, plan: dict) -> dict:
    path = root / plan["approval_record"]
    if not path.is_file():
        raise ValueError("explicit per-motion human approval record is missing")
    approved = document(path)
    if approved.get("schema_version") != 1 or approved.get("kind") != "user-motion-registration-approval" or approved.get("source") != "user":
        raise ValueError("approval must explicitly identify a user decision")
    if approved.get("plan_sha256") != plan_digest(plan) or any(approved.get(field) != plan[field] for field in ("catalog_sha256","scope_sha256","qa_review_sha256","registration_targets_sha256")):
        raise ValueError("approval is not bound to the current exact plan/scope/QA hashes")
    decisions = approved.get("motions")
    if not isinstance(decisions,list) or any(not isinstance(row,dict) for row in decisions):
        raise ValueError("approval requires per-motion decisions")
    wanted={(row["character_id"],row["motion"]):row for row in plan["motions"]}
    keys=[(row.get("character_id"),row.get("motion")) for row in decisions]
    if len(set(keys)) != len(keys) or set(keys) != set(wanted):
        raise ValueError("approval must cover every planned motion exactly once")
    for row in decisions:
        expected=wanted[row["character_id"],row["motion"]]
        if row.get("user_approved") is not True or any(row.get(field) != expected[field] for field in ("png_sha256","candidate_sprite_frames_sha256","registered_sprite_frames_sha256")):
            raise ValueError("per-motion approval or approved artwork hashes differ")
        if any(not isinstance(row.get(field),str) or not row[field].strip() for field in ("user_message","message_reference","approved_on")):
            raise ValueError("approval requires the explicit human message, its reference and date")
    return approved


def install(root: Path, plan: dict, pending: dict[str, bytes], backup: Path) -> dict:
    """Only call with a fresh plan. No existing PNG is removed or overwritten."""
    root=root.resolve()
    verify_approval(root,plan)  # Before any directory or file is created.
    fresh,fresh_pending=plan_registration(root,root/plan["catalog_path"],root/plan["scope_path"],plan["scope_sha256"],root/plan["qa_review_path"],root/plan["registration_targets_path"])
    if plan_digest(fresh) != plan_digest(plan) or fresh_pending != pending:
        raise ValueError("registration source or QA changed after dry-run")
    backup=backup.resolve()
    if not backup.is_relative_to((root/"_workspace").resolve()) or backup.exists():
        raise ValueError("installation backup must be a new project _workspace directory")
    # Recheck every preimage before the first write, including new immutable PNGs.
    for output in plan["outputs"]:
        target=root/output["path"]
        actual=digest(target.read_bytes()) if target.is_file() else None
        if actual != output["before_sha256"] or digest(pending[output["path"]]) != output["after_sha256"]:
            raise ValueError("registration inputs/targets changed after dry-run")
    previous={path:(root/path).read_bytes() if (root/path).is_file() else None for path in pending}
    backup.mkdir(parents=True)
    for path,data in previous.items():
        if data is not None:
            saved=backup/path; saved.parent.mkdir(parents=True,exist_ok=True); saved.write_bytes(data)
    receipt={"schema_version":1,"kind":"motion-registration-receipt","plan_sha256":plan_digest(plan),
             "approval_sha256":digest((root/plan["approval_record"]).read_bytes()),"plan":plan,"status":"installed"}
    try:
        for path,data in pending.items():
            target=root/path; target.parent.mkdir(parents=True,exist_ok=True); target.write_bytes(data)
        (backup/"receipt.json").write_bytes(encoded(receipt))
    except OSError:
        for path,data in previous.items():
            target=root/path
            if data is None: target.unlink(missing_ok=True)
            else: target.write_bytes(data)
        receipt["status"]="rolled-back"
        (backup/"receipt.json").write_bytes(encoded(receipt))
        raise
    return receipt


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root",type=Path,required=True)
    parser.add_argument("--catalog",type=Path,required=True)
    parser.add_argument("--scope",type=Path,required=True)
    parser.add_argument("--scope-sha256",required=True)
    parser.add_argument("--review",type=Path,required=True)
    parser.add_argument("--targets",type=Path,required=True)
    parser.add_argument("--install",action="store_true",help="requires exact per-motion user approval; default is read-only")
    parser.add_argument("--backup-dir",type=Path)
    args=parser.parse_args()
    try:
        plan,pending=plan_registration(args.project_root,args.catalog,args.scope,args.scope_sha256,args.review,args.targets)
        if args.install:
            if args.backup_dir is None: raise ValueError("--install requires --backup-dir")
            print(json.dumps(install(args.project_root,plan,pending,args.backup_dir),ensure_ascii=False,indent=2))
        else:
            try:
                verify_approval(args.project_root.resolve(),plan)
                approval_status="ready"
            except (ValueError,OSError) as error:
                approval_status=str(error)
            print(json.dumps({"plan":plan,"plan_sha256":plan_digest(plan),"writes":False,"approval_status":approval_status},ensure_ascii=False,indent=2))
    except (ValueError,OSError,KeyError,TypeError) as error:
        parser.exit(1,f"motion registration refused: {error}\n")


if __name__=="__main__": main()
