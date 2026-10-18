"""Freeze user-selected style and create mechanical reference crops only."""
from pathlib import Path
import hashlib
import json
import shutil
import sys
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
WORK = Path(__file__).resolve().parent
OUT = WORK / "06_myo_ryung-style-locked"
SOURCE = Path("/Users/jdh/.codex/generated_images/01a0912f-ac1e-7a73-9e6e-c5111b754fd8/exec-4403f063-962b-4785-a41d-a6857256c288.png")
sys.path.insert(0, str(ROOT / "tools/forest_arena"))
from motion_sheet_regions import split_regions

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    refs = OUT / "01_style_reference"
    refs.mkdir(parents=True, exist_ok=True)
    selected = refs / "user-selected-style-original.png"
    if not selected.exists():
        shutil.copy2(SOURCE, selected)
    assert sha(selected) == sha(SOURCE)
    original = Image.open(selected)
    assert original.mode == "RGBA"
    frames = split_regions(original)
    # Region extraction and matte compositing are technical reference packing,
    # not a new drawing, recolor or an approved animation deliverable.
    pose = frames[0]
    matte = Image.new("RGBA", (384, 384), "#808080")
    matte.alpha_composite(pose, ((384-pose.width)//2, (384-pose.height)//2))
    primary = refs / "style-master-pose01-matte.png"
    matte.convert("RGB").save(primary)
    sheet = Image.new("RGBA", (1536, 1536), "#808080")
    for i, frame in enumerate(frames):
        sheet.alpha_composite(frame, ((i%4)*384+(384-frame.width)//2, (i//4)*384+(384-frame.height)//2))
    secondary = refs / "style-master-16poses-matte.png"
    sheet.convert("RGB").save(secondary)
    record = {"user_selected": True, "selection_date": "2026-10-15", "user_text": "이 그림체로 진행한다.",
              "original_path": str(selected.relative_to(ROOT)), "original_sha256": sha(selected),
              "original_dimensions": list(original.size), "original_alpha_range": list(original.getchannel("A").getextrema()),
              "reference_paths": [str(p.relative_to(ROOT)) for p in (primary, secondary)],
              "reference_sha256": [sha(primary), sha(secondary)],
              "derived_reference_method": "16 region crops, unchanged subject pixels, matte gray composition; no recolor or redraw",
              "scope": "style direction only; not approval of newly remade motions or runtime installation"}
    (refs / "selection.json").write_text(json.dumps(record, ensure_ascii=False, indent=2)+"\n")
    for folder in ("02_drafts", "03_alpha", "04_review"):
        (OUT / folder).mkdir(exist_ok=True)
    print(json.dumps(record, ensure_ascii=False))

if __name__ == "__main__":
    main()
