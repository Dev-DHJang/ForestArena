"""Draw technical coordinates on extracted first poses for manual measurements."""
from pathlib import Path
import sys
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
WORK = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "tools/forest_arena"))
from motion_sheet_regions import split_regions

SOURCES = {"myo-ryung": "idle-r05-alpha.png", "nabi": "idle-r07-alpha.png", "yu-ran": "idle-r05-alpha.png"}


def main():
    output = WORK / "03_sample_review"
    output.mkdir(exist_ok=True)
    reference = Image.open(WORK / "01_references/ja-hyun/idle_16f.png").crop((0, 0, 128, 128))
    poses = {"ja-hyun": reference}
    for cid, name in SOURCES.items():
        poses[cid] = split_regions(Image.open(WORK / "02_samples" / cid / name))[0]
    for cid, pose in poses.items():
        pose.save(output / f"{cid}-pose01.png")
        board = Image.new("RGB", (pose.width * 3 + 100, pose.height * 3 + 20), "#343e50")
        board.paste(pose.resize((pose.width * 3, pose.height * 3)), (80, 10), pose.resize((pose.width * 3, pose.height * 3)))
        draw = ImageDraw.Draw(board)
        for y in range(0, pose.height, 10):
            draw.line((80, y * 3 + 10, board.width, y * 3 + 10), fill="#62718b")
            draw.text((10, y * 3 + 10), str(y), fill="white")
        board.save(output / f"{cid}-coordinates.png")
    print("MANUAL MEASUREMENT REFERENCES: four first-pose images with 10px guides.")


if __name__ == "__main__":
    main()
