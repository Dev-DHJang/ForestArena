"""Strict technical checks for 31 review sheets; no automated aesthetic claim."""
from pathlib import Path
import hashlib
import json
import math
from PIL import Image,ImageDraw
from stage_style_proofs import matte

ROOT=Path(__file__).resolve().parents[2]
WORK=Path(__file__).resolve().parent
BATCH=WORK/"06_myo_ryung-style-locked"

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    report=json.loads((BATCH/"04_review/31-motion-report.json").read_text())
    baseline=json.loads((WORK/"01_baseline.json").read_text())
    expected={r["visual_state_id"]:r for r in baseline["runtime_entries"] if r["character_id"]=="myo-ryung"}
    approval=json.loads((BATCH/"approval-proof-3.json").read_text())
    assert len(report["states"])==31 and report["approved_count"]==3 and report["pending_count"]==28
    assert {r["visual_state_id"] for r in report["states"]}==set(expected)
    clean=list((BATCH/"04_review").glob("*/*-r01-clean.png"))
    assert len(clean)==31
    for f in approval["files"]:
        assert sha(ROOT/f["path"])==f["sha256"],f["path"]
    sources=[]
    for row in report["states"]:
        state=row["visual_state_id"]
        assert row["user_approved"]==(state in approval["approved_states"])
        path=ROOT/row["review_path"]
        assert path.name==f"{state}-r01-clean.png" and sha(path)==row["review_sha256"]
        image=Image.open(path)
        image.load()
        assert image.size==(512,512) and image.mode=="RGBA" and image.getchannel("A").getextrema()==(0,255)
        hashes=[]
        for i in range(16):
            frame=image.crop(((i%4)*128,(i//4)*128,(i%4+1)*128,(i//4+1)*128))
            box=frame.getbbox()
            assert box and box[0]>=2 and box[1]>=2 and box[2]<=126 and box[3]<=126,(state,i,box)
            digest=hashlib.sha256(frame.tobytes()).hexdigest()
            assert digest==row["frames"][i]["rgba_sha256"],(state,i)
            hashes.append(digest)
        assert len(set(hashes))==16
        assert len({r["fixed_scale"] for r in row["frames"]})==1
        source=ROOT/row["source_path"]
        assert sha(source)==row["source_sha256"]
        original=Image.open(source)
        original.load()
        assert original.mode=="RGBA" and list(original.size)==row["source_dimensions"]
        assert original.getchannel("A").getextrema()==(0,255)
        sources.append(row["source_path"])
        assert row["original_fps"]==expected[state]["fps"] and row["original_loop"]==expected[state]["loop"]
        assert abs(row["head_height_after_scale"]/26-1)<=.1
        gif=Image.open(path.parent/f"{state}-r01.gif")
        assert gif.n_frames==16
        timing=[]
        for i in range(16):
            gif.seek(i)
            timing.append(gif.info["duration"])
        assert timing==row["gif_durations_ms"]
        for suffix in ("preview-128","keypose-128"):
            small=Image.open(path.parent/f"{state}-r01-{suffix}.png")
            assert small.size==(128,128) and small.mode=="RGBA"
    assert len(set(sources))==31
    # Matte contact boards let a person inspect every cell without raw-alpha RGB noise.
    qa=BATCH/"04_review/qa-pages"
    qa.mkdir(exist_ok=True)
    for start in range(0,31,4):
        page=Image.new("RGB",(1024,1120),"#243044")
        draw=ImageDraw.Draw(page)
        draw.text((8,8),f"MYO_RYUNG_REMAINING_STYLE_REVIEW_R01 / page {start//4+1} / row-major16",fill="white")
        for n,row in enumerate(report["states"][start:start+4]):
            x,y=(n%2)*512,32+(n//2)*544
            draw.text((x+5,y),row["visual_state_id"]+(" / APPROVED" if row["user_approved"] else " / pending"),fill="white")
            page.paste(matte(Image.open(ROOT/row["review_path"])),(x,y+20))
        page.save(qa/f"page-{start//4+1:02}.png")
    result={"regression":"MYO_RYUNG_REMAINING_STYLE_STRUCTURAL_R01","status":"pass","total_motions":31,
            "frames":496,"unique_frames_per_motion":16,"user_approved_count":3,"pending_user_approval_count":28,
            "approval_3_files_unchanged":True,"report_sha256":sha(BATCH/"04_review/31-motion-report.json"),
            "scope":"Decode, RGBA/alpha, 4x4 cells, unique pixels, one fixed scale per motion, no cell edge clipping, IDs/FPS/loop, hashes and approved-file preservation. Not aesthetic, 3D-joint or Android device approval."}
    (BATCH/"05_remaining/structural-check.json").write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n")
    print("MYO_REMAINING_STYLE_STRUCTURAL_R01: PASS (31 sheets / 496 cells / approved 3 unchanged / 28 approval pending)")

if __name__=="__main__":
    main()
