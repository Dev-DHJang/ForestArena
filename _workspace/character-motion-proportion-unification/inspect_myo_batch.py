"""Inspect generated alpha candidates without declaring user approval or installing."""
from pathlib import Path
import hashlib
import json
import sys
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
WORK = Path(__file__).resolve().parent
BATCH = WORK / "05_myo_ryung"
sys.path.insert(0, str(ROOT / "tools/forest_arena"))
from motion_sheet_regions import split_regions


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def locate_pose(source_pixels, pose, index):
    cropped = np.asarray(pose)
    coords = np.argwhere(cropped[:, :, 3] >= 200)
    assert len(coords), "No opaque subject"
    samples = coords[np.linspace(0, len(coords)-1, 13).astype(int)]
    candidates = []
    for cy, cx in samples:
        hits = np.argwhere(np.all(source_pixels == cropped[cy, cx], axis=2))
        candidates.append((len(hits), cy, cx, hits))
    _, cy, cx, hits = min(candidates, key=lambda row: row[0])
    h, w = source_pixels.shape[:2]
    matches = []
    for sy, sx in hits:
        x, y = int(sx-cx), int(sy-cy)
        if x < 0 or y < 0 or x+pose.width > w or y+pose.height > h:
            continue
        if all(np.array_equal(source_pixels[y+py, x+px], cropped[py, px]) for py, px in samples):
            expected_x, expected_y = (index%4+.5)*w/4, (index//4+.5)*h/4
            distance = abs(x+pose.width/2-expected_x)+abs(y+pose.height/2-expected_y)
            matches.append((distance, x, y))
    assert matches, (index, "Cannot locate extracted pose in source")
    _, x, y = min(matches)
    return [x, y, x+pose.width, y+pose.height]


def main():
    output = BATCH / "04_review/inspection"
    output.mkdir(parents=True, exist_ok=True)
    records = []
    for path in sorted((BATCH / "03_alpha").glob("*-r02-alpha.png")):
        state = path.name.removesuffix("-r02-alpha.png")
        try:
            cached_path = output / f"{state}-inspection.json"
            if cached_path.exists():
                cached = json.loads(cached_path.read_text())
                if cached.get("source_sha256") == sha(path):
                    records.append(cached)
                    print(state, "cached 16 poses", flush=True)
                    continue
            image = Image.open(path)
            assert image.mode == "RGBA" and image.getchannel("A").getextrema()[0] == 0, "No real alpha"
            frames = split_regions(image)
            assert len(frames) == 16
            pixels = np.asarray(image)
            boxes = [locate_pose(pixels, f, i) for i, f in enumerate(frames)]
            edges = [i for i, b in enumerate(boxes) if b[0] <= 1 or b[1] <= 1 or b[2] >= image.width-1 or b[3] >= image.height-1]
            scale = min(170/max(f.width for f in frames), 170/max(f.height for f in frames))
            board = Image.new("RGB", (768, 800), "#344154")
            draw = ImageDraw.Draw(board)
            draw.text((8, 8), state + " / source poses, uniform preview scale", fill="white")
            for i, frame in enumerate(frames):
                thumb = frame.resize((round(frame.width*scale), round(frame.height*scale)), Image.Resampling.LANCZOS)
                x, y = (i%4)*192+(192-thumb.width)//2, 30+(i//4)*192+(180-thumb.height)//2
                board.paste(thumb, (x, y), thumb)
                draw.text(((i%4)*192+3, 32+(i//4)*192), str(i+1), fill="white")
            board.save(output / f"{state}-poses.jpg", quality=92)
            pose = frames[0]
            pose.save(output / f"{state}-pose01.png")
            coordinate = Image.new("RGB", (pose.width*3+60, pose.height*3+10), "#344154")
            scaled = pose.resize((pose.width*3, pose.height*3))
            coordinate.paste(scaled, (60, 0), scaled)
            guide = ImageDraw.Draw(coordinate)
            for y in range(0, pose.height, 10):
                guide.line((60,y*3,coordinate.width,y*3), fill="#61718b")
                guide.text((5,y*3), str(y), fill="white")
            coordinate.save(output / f"{state}-coordinates.jpg", quality=92)
            record = {"state": state, "source_path": str(path.relative_to(ROOT)), "source_sha256": sha(path),
                            "source_size": list(image.size), "alpha_range": list(image.getchannel("A").getextrema()),
                            "poses": [{"index": i, "source_box": boxes[i], "size": list(f.size)} for i,f in enumerate(frames)],
                            "source_edge_touch_frames_for_review": edges, "structural_status": "16-poses-extracted"}
            records.append(record)
            cached_path.write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n")
            print(state, "16 poses", "edges:", edges, flush=True)
        except (ValueError, AssertionError) as error:
            records.append({"state": state, "source_path": str(path.relative_to(ROOT)), "structural_status": "fix-required", "error": str(error)})
            print(state, "FIX:", error)
    (output / "report.json").write_text(json.dumps(records, ensure_ascii=False, indent=2) + "\n")
    print("Inspected", len(records), "alpha candidates; this is not approval.")


if __name__ == "__main__":
    main()
