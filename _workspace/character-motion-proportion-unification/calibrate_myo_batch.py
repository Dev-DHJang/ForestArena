"""Make neutral/calibration-pose guides. Does not change generated artwork."""
from pathlib import Path
import sys
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
WORK = Path(__file__).resolve().parent
BATCH = WORK / "05_myo_ryung"
sys.path.insert(0, str(ROOT / "tools/forest_arena"))
from motion_sheet_regions import split_regions

LAST = {"attack_light_combo_04", "attack_heavy_up", "attack_air_light", "attack_air_heavy", "wake_up", "spawn"}

def main():
    out = BATCH / "04_review/calibration"
    out.mkdir(parents=True, exist_ok=True)
    for path in sorted((BATCH / "03_alpha").glob("*-r02-alpha.png")):
        state = path.name.removesuffix("-r02-alpha.png")
        destination = out / f"{state}.jpg"
        if destination.exists():
            continue
        index = 15 if state in LAST else 0
        pose = split_regions(Image.open(path))[index]
        board = Image.new("RGB", (pose.width*3+60, pose.height*3+30), "#344154")
        enlarged = pose.resize((pose.width*3, pose.height*3))
        board.paste(enlarged, (60, 30), enlarged)
        draw = ImageDraw.Draw(board)
        draw.text((5, 5), f"{state} / frame {index+1}", fill="white")
        for y in range(0, pose.height, 10):
            draw.line((60,30+y*3,board.width,30+y*3), fill="#61718b")
            draw.text((5,30+y*3), str(y), fill="white")
        board.save(destination, quality=92)
        print(state, index, pose.size, flush=True)

if __name__ == "__main__":
    main()
