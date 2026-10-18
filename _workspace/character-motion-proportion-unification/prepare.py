"""Freeze actual dirty-worktree inputs without modifying production assets."""
from collections import Counter
from copy import deepcopy
from pathlib import Path
import hashlib
import json
import shutil

ROOT = Path(__file__).resolve().parents[2]
WORK = Path(__file__).resolve().parent
TARGETS = {"myo-ryung": 31, "nabi": 29, "yu-ran": 30}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    baseline_path = WORK / "01_baseline.json"
    if baseline_path.exists():
        raise SystemExit("Baseline already exists; inspect it instead of replacing inputs.")
    manifest_path = ROOT / "assets/character/manifest.json"
    manifest = json.loads(manifest_path.read_text())
    rows = [deepcopy(e) for e in manifest["assets"] if e.get("type") == "animation-runtime"]
    targets = [e for e in rows if e["character_id"] in TARGETS]
    assert Counter(e["character_id"] for e in targets) == Counter(TARGETS)
    assert len({(e["character_id"], e["visual_state_id"]) for e in targets}) == 90
    for e in rows:
        e["actual_start_sha256"] = sha(ROOT / e["path"])
        e["sprite_frames_start_sha256"] = sha(ROOT / e["sprite_frames_path"].removeprefix("res://"))
    protected_paths = set((ROOT / "assets/character/ja-hyun").rglob("*"))
    protected_paths.update((ROOT / "assets/combat").rglob("*"))
    for cid in TARGETS:
        protected_paths.update((ROOT / f"assets/character/{cid}/concept").rglob("*"))
    protected_paths.add(ROOT / "docs/contracts/character-appearance-v01.json")
    protected = {str(p.relative_to(ROOT)): sha(p) for p in sorted(protected_paths) if p.is_file() and p.suffix != ".import"}
    output = {"created_on": "2026-10-15", "target_counts": TARGETS,
              "manifest_start_sha256": sha(manifest_path), "runtime_entries": rows,
              "retained_ja_hyun_entries": [e for e in manifest["assets"] if e.get("character_id") == "ja-hyun"],
              "protected_files": protected}
    shutil.copy2(manifest_path, WORK / "01_manifest_before.json")
    for cid in ("ja-hyun", *TARGETS):
        folder = WORK / "01_references" / cid
        folder.mkdir(parents=True, exist_ok=True)
        for name in ("idle", "attack_heavy_charge"):
            entry = next(e for e in rows if e["character_id"] == cid and e["visual_state_id"] == name)
            shutil.copy2(ROOT / entry["path"], folder / f"{name}_16f.png")
        shutil.copy2(ROOT / f"assets/character/{cid}/concept/{cid}-concept-v01.png", folder / "concept.png")
    baseline_path.write_text(json.dumps(output, ensure_ascii=False, indent=2) + "\n")
    print("BASELINE: 90 targets frozen; 30 Ja-Hyun runtime entries and protected files hashed.")


if __name__ == "__main__":
    main()
