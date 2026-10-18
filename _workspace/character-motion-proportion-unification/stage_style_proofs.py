"""Review-only packing with one measured scale per motion. No runtime strips."""
from pathlib import Path
import hashlib
import json
import shutil
import sys
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
WORK = Path(__file__).resolve().parent
BATCH = WORK / "06_myo_ryung-style-locked"
sys.path.insert(0, str(ROOT / "tools/forest_arena"))
from motion_sheet_regions import split_regions

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def matte(im, background="#344154"):
    canvas = Image.new("RGBA", im.size, background)
    canvas.alpha_composite(im)
    return canvas.convert("RGB")

def scale_for(row, reference):
    if row["scale_method"] == "body-height":
        return reference["body_height"]/(row["sole_y"]-row["crown_y"])
    return reference["head_height"]/(row["chin_y"]-row["crown_y"])

def sheet(frames):
    output = Image.new("RGBA", (512, 512))
    for i, frame in enumerate(frames):
        output.alpha_composite(frame, ((i%4)*128, (i//4)*128))
    return output

def support_x(pose):
    band = np.asarray(pose)[round(pose.height*.78):, :, 3] >= 64
    _, xs = np.nonzero(band)
    assert len(xs)
    return (int(xs.min())+int(xs.max())+1)/2

def durations(fps):
    # GIF units are 10 ms. Cumulative rounding avoids a repeated 80ms=12.5fps error.
    ticks = [round(i*100/fps) for i in range(17)]
    return [(ticks[i+1]-ticks[i])*10 for i in range(16)]

def main():
    spec = json.loads((BATCH / "landmarks-r01.json").read_text())
    inspections = {r["state"]: r for r in json.loads((BATCH / "04_review/inspection/report.json").read_text())}
    assert set(inspections) == set(spec["states"])
    reference = spec["reference"]
    baseline = json.loads((WORK / "01_baseline.json").read_text())
    entries = {r["visual_state_id"]: r for r in baseline["runtime_entries"] if r["character_id"] == "myo-ryung"}
    output = BATCH / "04_review"
    report, normalized, extracted_by_state = [], {}, {}
    for state, row in spec["states"].items():
        record = inspections[state]
        assert not record["source_edge_touch_frames"], state
        path = ROOT / record["source_path"]
        assert sha(path) == record["sha256"]
        original = Image.open(path)
        poses = split_regions(original)
        scale = scale_for(row, reference)
        # Horizontal source-cell placement keeps the camera steady rather than
        # recentering on an outstretched leg. Vertical contact differs on ground/air.
        first_box = record["poses"][0]["source_box"]
        anchor = support_x(poses[0]) if row["alignment"] == "ground-foot" else poses[0].width/2
        x_offset = 64-(first_box[0]+anchor)*scale
        frames, frame_rows = [], []
        for i, pose in enumerate(poses):
            size = (round(pose.width*scale), round(pose.height*scale))
            box = record["poses"][i]["source_box"]
            x = round((box[0]-(i%4)*original.width/4)*scale+x_offset)
            y = 124-size[1] if row["alignment"] == "ground-foot" else round(78-size[1]/2)
            assert x >= 2 and x+size[0] <= 126 and y >= 2 and y+size[1] <= 126, (state,i,x,y,size)
            frame = Image.new("RGBA", (128, 128))
            frame.alpha_composite(pose.resize(size, Image.Resampling.LANCZOS), (x,y))
            pixels = np.asarray(frame)
            frame_rows.append({"index": i, "fixed_scale": scale, "bbox": list(frame.getbbox()),
                               "strong_alpha_bbox": list(Image.fromarray((pixels[:,:,3]>=32).astype("uint8")*255).getbbox()),
                               "rgba_sha256": hashlib.sha256(frame.tobytes()).hexdigest()})
            frames.append(frame)
        assert len({r["rgba_sha256"] for r in frame_rows}) == 16, state
        normalized[state] = frames
        extracted_by_state[state] = poses
        folder = output / state
        folder.mkdir(exist_ok=True)
        destination = folder / f"{state}-r01-clean.png"
        sheet(frames).save(destination)
        frames[0].save(folder / f"{state}-r01-preview-128.png")
        peak = 7 if state == "attack_air_heavy" else (5 if state == "run" else 7)
        frames[peak].save(folder / f"{state}-r01-keypose-128.png")
        gif = folder / f"{state}-r01.gif"
        animation = [matte(f) for f in frames]
        timing = durations(entries[state]["fps"])
        animation[0].save(gif, save_all=True, append_images=animation[1:], duration=timing, loop=0, disposal=2, optimize=False)
        measurement = matte(poses[0].resize((poses[0].width*3,poses[0].height*3)))
        draw = ImageDraw.Draw(measurement)
        for name,color in (("crown_y","#ffca61"),("chin_y","#8fffc0"),("sole_y","white")):
            if name in row:
                yy = min(measurement.height-1,row[name]*3)
                draw.line((0,yy,measurement.width-1,yy), fill=color, width=2)
                draw.text((3,max(0,yy-13)), f"{name} = {row[name]}", fill=color)
        measurement.save(folder / "frame01-landmarks.png")
        review_im = Image.open(destination)
        assert review_im.mode == "RGBA" and review_im.size == (512,512) and review_im.getchannel("A").getextrema() == (0,255)
        animated = Image.open(gif)
        assert animated.n_frames == 16
        actual_durations = []
        for index in range(16):
            animated.seek(index)
            actual_durations.append(animated.info["duration"])
        assert actual_durations == timing
        report.append({"character_id":"myo-ryung", "visual_state_id":state, "user_approved":False,
                       "source_path":record["source_path"],"source_sha256":sha(path),"source_dimensions":list(original.size),
                       "source_alpha_range":[0,255],"review_path":str(destination.relative_to(ROOT)),"review_sha256":sha(destination),
                       "review_dimensions":[512,512],"review_alpha_range":[0,255],"frame_count":16,"unique_frames":16,
                       "fixed_motion_scale":scale,"alignment":row["alignment"],"head_height_after_scale":(row["chin_y"]-row["crown_y"])*scale,
                       "neutral_body_height_after_scale":(row["sole_y"]-row["crown_y"])*scale if state=="idle" else None,
                       "original_fps":entries[state]["fps"],"original_loop":entries[state]["loop"],
                       "gif_durations_ms":timing,"gif_display_note":"Looped for review; runtime loop unchanged, including non-loop aerial attack.",
                       "frames":frame_rows})
    master = Image.open(BATCH / "01_style_reference/user-selected-style-original.png")
    master_poses = split_regions(master)
    master_scale = scale_for(spec["selected_style"], reference)
    master_frames = []
    for pose in master_poses:
        size=(round(pose.width*master_scale),round(pose.height*master_scale))
        f=Image.new("RGBA",(128,128))
        f.alpha_composite(pose.resize(size,Image.Resampling.LANCZOS), (round(64-support_x(pose)*master_scale),124-size[1]))
        master_frames.append(f)
    columns=[("selected-style",master_frames),("idle",normalized["idle"]),("run",normalized["run"]),("attack_air_heavy",normalized["attack_air_heavy"])]
    board=Image.new("RGB",(1536,850),"#243044")
    draw=ImageDraw.Draw(board)
    draw.text((20,12),"USER-SELECTED STYLE / REMADE MOTIONS / same 128px display cells at 1.0 scale",fill="white")
    for col,(state,frames) in enumerate(columns):
        xx=col*384
        draw.text((xx+18,45),state,fill="white")
        for frame_index,yy,label in ((0,70,"frame 1"),(7,470,"frame 8")):
            image=matte(frames[frame_index]).resize((384,384),Image.Resampling.NEAREST)
            board.paste(image,(xx,yy))
            draw.text((xx+10,yy+6),label,fill="white")
    board.save(output / "style-comparison.png")
    # Original-resolution drawings at one common head scale retain the detail
    # needed for face/line/shading review, unlike enlarged 128px game previews.
    detail=Image.new("RGB",(1536,520),"#344154")
    draw=ImageDraw.Draw(detail)
    originals=[("selected-style",master_poses[0],spec["selected_style"]),*[(s,extracted_by_state[s][0],spec["states"][s]) for s in spec["states"]]]
    for col,(state,pose,row) in enumerate(originals):
        scale=100/(row["chin_y"]-row["crown_y"])
        resized=pose.resize((round(pose.width*scale),round(pose.height*scale)),Image.Resampling.LANCZOS)
        xx=col*384+(384-resized.width)//2
        yy=90-round(row["crown_y"]*scale)
        detail.paste(resized,(xx,yy),resized)
        draw.text((col*384+15,15),state+" / head=100px",fill="white")
    detail.save(output / "style-detail-comparison.png")
    ja=Image.open(WORK / "01_references/ja-hyun/idle_16f.png").crop((0,0,128,128)).convert("RGBA")
    same=Image.new("RGBA",(640,128),"#344154")
    for i,f in enumerate([ja,master_frames[0],normalized["idle"][0],normalized["run"][0],normalized["attack_air_heavy"][0]]):
        same.alpha_composite(f,(i*128,0))
    same.convert("RGB").resize((1280,256),Image.Resampling.NEAREST).save(output / "ja-hyun-size-comparison.png")
    result={"status":"style-proof-review-pending","style_selection":"01_style_reference/selection.json", "measurement_scope":spec["scope_note"],"states":report}
    (output / "report.json").write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n")
    print("STYLE PROOFS: 3 x 16 unique RGBA review frames; user approval pending; no runtime writes.")
    for r in report:
        print(r["visual_state_id"],"head",r["head_height_after_scale"],"body",r["neutral_body_height_after_scale"],r["review_sha256"])

if __name__=="__main__":
    main()
