"""Read-only subject inspection and calibration guides for the selected-style restart."""
from pathlib import Path
import hashlib
import json
import sys
import numpy as np
from PIL import Image, ImageDraw
from inspect_myo_batch import locate_pose

ROOT = Path(__file__).resolve().parents[2]
WORK = Path(__file__).resolve().parent
BATCH = WORK / "06_myo_ryung-style-locked"
sys.path.insert(0, str(ROOT / "tools/forest_arena"))
from motion_sheet_regions import split_regions

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main(allow_incomplete=False):
    out = BATCH / "04_review/inspection"
    out.mkdir(parents=True, exist_ok=True)
    old_report = out / "report.json"
    cached = {r["state"]:r for r in json.loads(old_report.read_text())} if old_report.exists() else {}
    last_calibration = {"attack_light_combo_04", "attack_heavy_up", "wake_up", "spawn"}
    rows = []
    failures = []
    selected_paths = {}
    for path in sorted((BATCH / "03_alpha").glob("*-alpha.png")):
        selected_paths[path.stem.rsplit("-r", 1)[0]] = path
    for path in selected_paths.values():
        state = path.stem.rsplit("-r", 1)[0]
        if state in cached and cached[state]["sha256"] == sha(path):
            rows.append(cached[state])
            print(state, "cached", flush=True)
            continue
        im = Image.open(path)
        assert im.mode == "RGBA" and im.getchannel("A").getextrema() == (0, 255)
        try:
            frames = split_regions(im)
        except ValueError as error:
            if not allow_incomplete:
                raise
            failures.append({"state":state,"source_path":str(path.relative_to(ROOT)),"sha256":sha(path),"error":str(error)})
            print(state, "REJECTED", str(error), flush=True)
            continue
        assert len(frames) == 16
        boxes = [locate_pose(np.asarray(im), f, i) for i, f in enumerate(frames)]
        edge_frames = [i for i, b in enumerate(boxes) if b[0] <= 1 or b[1] <= 1 or b[2] >= im.width-1 or b[3] >= im.height-1]
        scale = min(170/max(f.width for f in frames), 170/max(f.height for f in frames))
        board = Image.new("RGB", (768, 800), "#344154")
        draw = ImageDraw.Draw(board)
        draw.text((8, 8), state+" / uniform source scale / user-selected style", fill="white")
        for i, frame in enumerate(frames):
            thumb = frame.resize((round(frame.width*scale), round(frame.height*scale)), Image.Resampling.LANCZOS)
            board.paste(thumb, ((i%4)*192+(192-thumb.width)//2, 30+(i//4)*192+(180-thumb.height)//2), thumb)
            draw.text(((i%4)*192+3, 32+(i//4)*192), str(i+1), fill="white")
            frame.save(out / f"{state}-pose{i+1:02}.png")
        board.save(out / f"{state}-poses.jpg", quality=92)
        pose = frames[0]
        coordinate = Image.new("RGB", (pose.width*3+60, pose.height*3+30), "#344154")
        enlarged = pose.resize((pose.width*3, pose.height*3))
        coordinate.paste(enlarged, (60, 30), enlarged)
        guide = ImageDraw.Draw(coordinate)
        guide.text((5, 5), state+" frame1 calibration", fill="white")
        for y in range(0, pose.height, 10):
            guide.line((60,30+y*3,coordinate.width,30+y*3), fill="#61718b")
            guide.text((5,30+y*3), str(y), fill="white")
        coordinate.save(out / f"{state}-coordinates.jpg", quality=92)
        calibration_index = 15 if state in last_calibration else 0
        calibration_pose = frames[calibration_index]
        calibration = Image.new("RGB", (calibration_pose.width*3+60, calibration_pose.height*3+30), "#344154")
        enlarged = calibration_pose.resize((calibration_pose.width*3,calibration_pose.height*3))
        calibration.paste(enlarged, (60,30), enlarged)
        guide = ImageDraw.Draw(calibration)
        guide.text((5,5), state+f" / calibration frame {calibration_index+1}", fill="white")
        for y in range(0, calibration_pose.height, 10):
            guide.line((60,30+y*3,calibration.width,30+y*3), fill="#61718b")
            guide.text((5,30+y*3),str(y),fill="white")
        calibration.save(out / f"{state}-calibration.jpg", quality=92)
        row = {"state": state, "source_path": str(path.relative_to(ROOT)), "sha256": sha(path),
               "source_dimensions": list(im.size), "source_alpha_range": [0, 255],
               "source_edge_touch_frames": edge_frames,
               "calibration_index": calibration_index,
               "poses": [{"index": i, "source_box": boxes[i], "size": list(f.size)} for i,f in enumerate(frames)]}
        rows.append(row)
        print(state, "16 poses", "source edges", edge_frames, flush=True)
    (out / "report.json").write_text(json.dumps(rows, ensure_ascii=False, indent=2)+"\n")
    if allow_incomplete:
        (out / "inspection-failures.json").write_text(json.dumps(failures,ensure_ascii=False,indent=2)+"\n")

if __name__ == "__main__":
    main()
