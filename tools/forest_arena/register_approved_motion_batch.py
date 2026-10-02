"""Register normalized, explicitly approved local-AI motion batches.

Normalization writes immutable runtime sheets and a report containing their
hashes. This script adds only the approved visual IDs below to the character
manifest and refuses missing report/runtime files.
"""
from pathlib import Path
import json


ROOT = Path(__file__).resolve().parents[2]
MANIFEST_PATH = ROOT / "assets/character/manifest.json"

YU_RAN_STATES = {
    "attack_heavy_charge", "hitstun", "launch", "knock_down", "wake_up",
    "death", "ring_out", "spawn",
}
YU_RAN_ATTACKS = {
    "attack_light_up", "attack_light_down", "attack_dash_light", "attack_air_light",
    "attack_heavy_side", "attack_heavy_up", "attack_heavy_down",
    "attack_dash_heavy", "attack_air_heavy", "special_neutral", "special_side",
    "special_up", "special_down", "ultimate",
}
JA_HYUN_STATES = {
    "guard", "evade", "attack_heavy_charge", "hitstun", "launch", "knock_down",
    "wake_up", "death", "ring_out", "spawn",
}
JA_HYUN_ATTACKS = {
    "attack_light_up", "attack_light_down", "attack_dash_light", "attack_air_light",
    "attack_heavy_side", "attack_heavy_up", "attack_heavy_down",
    "attack_dash_heavy", "attack_air_heavy", "special_neutral", "special_side",
    "special_up", "special_down", "ultimate",
}
ALL_ATTACKS = YU_RAN_ATTACKS | JA_HYUN_ATTACKS
MYO_RYUNG_STATES = {"guard", "evade", "hitstun", "launch"}


def phase_ranges(name):
    if name.startswith("attack_light") or name == "attack_dash_light" or name == "attack_air_light":
        return [[0, 5], [5, 8], [8, 16]]
    if name.startswith("attack_heavy") or name in {"attack_dash_heavy", "attack_air_heavy"}:
        return [[0, 6], [6, 10], [10, 16]]
    if name == "special_up":
        return [[0, 4], [4, 10], [10, 16]]
    return [[0, 5], [5, 10], [10, 16]]


def make_entry(character_id, name, sha256):
    kebab = name.replace("_", "-")
    relative = f"assets/character/{character_id}/animation/runtime/local_ai_v01"
    entry = {
        "asset_id": f"{character_id}-{kebab}-16f-local-v01",
        "character_id": character_id,
        "type": "animation-runtime",
        "path": f"{relative}/{name}_16f.png",
        "creation": {
            "method": "user-approved review plus project-local background extraction and normalization",
            "provider": "OpenAI image generation and local Pillow processing",
            "version": "local-v01",
        },
        "rights": {
            "status": f"derived from approved {character_id} concept; no additional external rights verification asserted",
            "references": ["User approved all previously presented motion drafts, 2026-10-02"],
        },
        "verified_on": "2026-10-02",
        "sha256": sha256,
        "modifications": [
            "Removed the gray review background and cross-cell fragments without repainting poses.",
            "Packed 16 RGBA 128x128 cells with the approved base scale, safe per-frame fit, and foot pivot; preserved review sources.",
        ],
        "frame_count": 16,
        "fps": 80 if name == "evade" else (24 if name in {"guard", "hitstun"} else 12),
        "loop": False,
        "sprite_frames_path": f"res://{relative}/{name}.tres",
        "consumer_path": f"res://{relative}/{name}.tres",
        "visual_state_id": name,
        "presentation_scale": 1.2,
        "foot_pivot_y": 124,
    }
    if name in ALL_ATTACKS:
        entry["phase_frame_ranges"] = phase_ranges(name)
    if name in {"attack_heavy_charge", "knock_down", "death"}:
        entry["state_hold_frame"] = 15
    return entry


def main():
    manifest = json.loads(MANIFEST_PATH.read_text())
    existing = {
        (entry.get("character_id"), entry.get("visual_state_id")): entry
        for entry in manifest["assets"] if isinstance(entry, dict)
    }
    batches = {
        "yu-ran": YU_RAN_STATES | YU_RAN_ATTACKS,
        "ja-hyun": JA_HYUN_STATES | JA_HYUN_ATTACKS,
        "myo-ryung": MYO_RYUNG_STATES,
    }
    added = 0
    for character_id, approved in batches.items():
        report_path = ROOT / f"_workspace/local-ai-playable/motion-review/{character_id}/normalized/report.json"
        report = json.loads(report_path.read_text())
        hashes = {motion["name"]: motion["sha256"] for motion in report["motions"]}
        missing = approved - hashes.keys()
        if missing:
            raise ValueError(f"normalized report is missing approved motions: {character_id}/{sorted(missing)}")
        for name in sorted(approved):
            key = (character_id, name)
            entry = make_entry(character_id, name, hashes[name])
            runtime_path = ROOT / entry["path"]
            frames_path = ROOT / entry["sprite_frames_path"].removeprefix("res://")
            if not runtime_path.is_file() or not frames_path.is_file():
                raise ValueError(f"missing runtime output for {character_id}/{name}")
            if key in existing:
                current = existing[key]
                if current.get("path") != entry["path"] or current.get("sha256") != entry["sha256"]:
                    raise ValueError(f"conflicting approved motion: {character_id}/{name}")
                continue
            manifest["assets"].append(entry)
            existing[key] = entry
            added += 1
    MANIFEST_PATH.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    print(f"registered {added} new approved motions")


if __name__ == "__main__":
    main()
