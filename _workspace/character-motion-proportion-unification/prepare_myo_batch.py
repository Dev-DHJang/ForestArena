"""Freeze action references and create review-only generation inputs for Myo-Ryung."""
from pathlib import Path
import hashlib
import json
import shutil
import sys
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
WORK = Path(__file__).resolve().parent
BATCH = WORK / "05_myo_ryung"
sys.path.insert(0, str(ROOT / "tools/forest_arena"))
from motion_sheet_regions import split_regions


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    approval = json.loads((WORK / "03_sample_approval.json").read_text())
    sample = next(r for r in approval["samples"] if r["character_id"] == "myo-ryung")
    assert approval["user_approved"] is True and sha(ROOT / sample["path"]) == sample["sha256"]
    baseline = json.loads((WORK / "01_baseline.json").read_text())
    entries = [e for e in baseline["runtime_entries"] if e["character_id"] == "myo-ryung"]
    assert len(entries) == 31
    refs = BATCH / "01_action_references"
    refs.mkdir(parents=True, exist_ok=True)
    for e in entries:
        name = e["visual_state_id"]
        source = ROOT / e["path"]
        assert sha(source) == e["actual_start_sha256"], name
        target = refs / f"{name}_16f.png"
        if not target.exists():
            shutil.copy2(source, target)
        assert sha(target) == e["actual_start_sha256"], name
        strip = Image.open(target).convert("RGBA")
        board = Image.new("RGBA", (512, 512), "#808080")
        for i in range(16):
            frame = strip.crop((i*128, 0, (i+1)*128, 128))
            board.alpha_composite(frame, ((i%4)*128, (i//4)*128))
        board.convert("RGB").resize((1536, 1536), Image.Resampling.NEAREST).save(refs / f"{name}-action-reference.png")
    selected_source = WORK / "02_samples/myo-ryung/idle-r05-alpha.png"
    artwork = Image.open(selected_source).convert("RGBA")
    matte = Image.new("RGBA", artwork.size, "#808080")
    matte.alpha_composite(artwork)
    matte.convert("RGB").save(BATCH / "approved-idle-body-reference.png")
    pose = split_regions(artwork)[0]
    isolated = Image.new("RGBA", (384, 384), "#808080")
    isolated.alpha_composite(pose, ((384-pose.width)//2, 354-pose.height))
    isolated.convert("RGB").save(BATCH / "approved-idle-pose01-reference.png")
    for folder in ("02_drafts", "03_alpha", "04_review"):
        (BATCH / folder).mkdir(exist_ok=True)
    print("MYO BATCH REFERENCES: 31 frozen sheets, 30 remaining actions, approved idle identity/body reference.")


if __name__ == "__main__":
    main()
