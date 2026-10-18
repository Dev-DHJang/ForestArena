"""Check frozen inputs before any production replacement is approved."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[2]
WORK = Path(__file__).resolve().parent


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    baseline = json.loads((WORK / "01_baseline.json").read_text())
    current = json.loads((ROOT / "assets/character/manifest.json").read_text())
    assert sha(ROOT / "assets/character/manifest.json") == baseline["manifest_start_sha256"], "Manifest changed since start"
    assert [e for e in current["assets"] if e.get("character_id") == "ja-hyun"] == baseline["retained_ja_hyun_entries"]
    for rel, expected in baseline["protected_files"].items():
        assert sha(ROOT / rel) == expected, rel
    for entry in baseline["runtime_entries"]:
        assert sha(ROOT / entry["path"]) == entry["actual_start_sha256"], entry["path"]
        path = ROOT / entry["sprite_frames_path"].removeprefix("res://")
        assert sha(path) == entry["sprite_frames_start_sha256"], str(path)
    print("PROPORTION_BASELINE: PASS (all 120 runtime PNGs, SpriteFrames, Ja-Hyun entries, concepts, combat data unchanged)")


if __name__ == "__main__":
    main()
