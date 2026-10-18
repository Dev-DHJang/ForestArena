"""Incrementally pack the 28 unapproved motions; preserve approved 3 exactly."""
from pathlib import Path
import hashlib
import html
import json
import math
import sys
import numpy as np
from PIL import Image, ImageDraw
from stage_style_proofs import matte, sheet, support_x, durations

ROOT=Path(__file__).resolve().parents[2]
WORK=Path(__file__).resolve().parent
BATCH=WORK/"06_myo_ryung-style-locked"
sys.path.insert(0,str(ROOT/"tools/forest_arena"))
from motion_sheet_regions import split_regions

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def approved_unchanged():
    receipt=json.loads((BATCH/"approval-proof-3.json").read_text())
    for row in receipt["files"]:
        assert sha(ROOT/row["path"])==row["sha256"],row["path"]
    return receipt

def main():
    receipt=approved_unchanged()
    approved=json.loads((BATCH/"04_review/report.json").read_text())["states"]
    assert all(r["user_approved"] for r in approved)
    baseline=json.loads((WORK/"01_baseline.json").read_text())
    entries={r["visual_state_id"]:r for r in baseline["runtime_entries"] if r["character_id"]=="myo-ryung"}
    spec=json.loads((BATCH/"05_remaining/landmarks-r01.json").read_text())
    inspections={r["state"]:r for r in json.loads((BATCH/"04_review/inspection/report.json").read_text())}
    assert not set(spec["states"]) & set(receipt["approved_states"])
    records=list(approved)
    for state,row in spec["states"].items():
        if state not in inspections:
            continue
        inspected=inspections[state]
        assert not inspected["source_edge_touch_frames"],state
        path=ROOT/inspected["source_path"]
        assert sha(path)==inspected["sha256"]
        original=Image.open(path)
        poses=split_regions(original)
        assert len(poses)==16
        calibration_index=row.get("index",inspected.get("calibration_index",0))
        scale=72/(row["sole_y"]-row["crown_y"]) if row.get("scale_method")=="neutral-body-height" else spec["target_head_height"]/(row["chin_y"]-row["crown_y"])
        measured_head=(row["chin_y"]-row["crown_y"])*scale
        assert abs(measured_head/26-1)<=.1,(state,"calibrated head differs by over 10%",measured_head)
        sizes=[(round(p.width*scale),round(p.height*scale)) for p in poses]
        lefts=[(r["source_box"][0]-(i%4)*original.width/4)*scale for i,r in enumerate(inspected["poses"])]
        first_box=inspected["poses"][calibration_index]["source_box"]
        origin=first_box[0]-(calibration_index%4)*original.width/4
        anchor=support_x(poses[calibration_index]) if row.get("alignment","ground")=="ground" or calibration_index in row.get("ground_indices",[]) else poses[calibration_index].width/2
        preferred=64-(origin+anchor)*scale
        low,high=2-min(lefts),126-max(x+s[0] for x,s in zip(lefts,sizes))
        assert low<=high,(state,"fixed camera footprint too wide",low,high)
        offset=max(low,min(high,preferred))
        max_height=max(h for _,h in sizes)
        assert max_height<=122,(state,"body cannot fit without shrinking",max_height)
        air_center=min(row.get("air_center_y",78),126-math.ceil(max_height/2))
        assert air_center>=2+math.ceil(max_height/2)
        ground_indices=set(row.get("ground_indices",[]))
        frames,frame_records=[],[]
        for i,(pose,size) in enumerate(zip(poses,sizes)):
            x=round(lefts[i]+offset)
            ground=row.get("alignment","ground")=="ground" or i in ground_indices
            y=124-size[1] if ground else round(air_center-size[1]/2)
            assert x>=2 and x+size[0]<=126 and y>=2 and y+size[1]<=126,(state,i,x,y,size)
            frame=Image.new("RGBA",(128,128))
            frame.alpha_composite(pose.resize(size,Image.Resampling.LANCZOS),(x,y))
            frames.append(frame)
            frame_records.append({"index":i,"fixed_scale":scale,"bbox":list(frame.getbbox()),"ground_foot_anchor":ground,
                                  "rgba_sha256":hashlib.sha256(frame.tobytes()).hexdigest()})
        assert len({r["rgba_sha256"] for r in frame_records})==16,state
        folder=BATCH/"04_review"/state
        folder.mkdir(exist_ok=True)
        destination=folder/f"{state}-r01-clean.png"
        sheet(frames).save(destination)
        frames[0].save(folder/f"{state}-r01-preview-128.png")
        peak=row.get("keypose_index",7)
        frames[peak].save(folder/f"{state}-r01-keypose-128.png")
        gif=folder/f"{state}-r01.gif"
        animation=[matte(f) for f in frames]
        timing=durations(entries[state]["fps"])
        animation[0].save(gif,save_all=True,append_images=animation[1:],duration=timing,loop=0,disposal=2,optimize=False)
        decoded=Image.open(gif)
        assert decoded.n_frames==16
        for i in range(16):
            decoded.seek(i)
            assert decoded.info["duration"]==timing[i]
        calibration=poses[calibration_index]
        guide=matte(calibration.resize((calibration.width*3,calibration.height*3)))
        draw=ImageDraw.Draw(guide)
        for name,color in (("crown_y","#ffca61"),("chin_y","#8fffc0")):
            yy=row[name]*3
            draw.line((0,yy,guide.width-1,yy),fill=color,width=2)
            draw.text((3,max(0,yy-13)),f"{name} = {row[name]} / frame {calibration_index+1}",fill=color)
        guide.save(folder/"head-calibration.png")
        decoded=Image.open(destination)
        assert decoded.mode=="RGBA" and decoded.size==(512,512) and decoded.getchannel("A").getextrema()==(0,255)
        records.append({"character_id":"myo-ryung","visual_state_id":state,"user_approved":False,
                        "source_path":inspected["source_path"],"source_sha256":sha(path),"source_dimensions":list(original.size),
                        "source_alpha_range":[0,255],"review_path":str(destination.relative_to(ROOT)),"review_sha256":sha(destination),
                        "review_dimensions":[512,512],"review_alpha_range":[0,255],"frame_count":16,"unique_frames":16,
                        "fixed_motion_scale":scale,"head_height_after_scale":measured_head,
                        "neutral_body_height_after_scale":72 if row.get("scale_method")=="neutral-body-height" else None,
                        "calibration_index":calibration_index,"head_landmarks":row,"common_horizontal_offset":offset,
                        "air_center_y":air_center,"original_fps":entries[state]["fps"],"original_loop":entries[state]["loop"],
                        "gif_durations_ms":timing,"keypose_index":peak,"frames":frame_records})
        print(state,"staged",round(scale,5),"head",round(measured_head,2),flush=True)
    by_state={r["visual_state_id"]:r for r in records}
    records=[by_state[s] for s in entries if s in by_state]
    report={"status":"complete-review-pending-28-approvals" if len(records)==31 else "production-in-progress",
            "approved_count":3,"pending_count":len(records)-3,"expected_total":31,
            "approval_record":"approval-proof-3.json","style_selection":"01_style_reference/selection.json",
            "quantitative_scope":"Neutral body and comparable head height; one scale per motion. No automatic claim of all-joint 10% compliance or perfect style identity.",
            "states":records}
    out=BATCH/"04_review"
    (out/"31-motion-report.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n")
    board=Image.new("RGB",(1536,math.ceil(len(records)/6)*280+40),"#243044")
    draw=ImageDraw.Draw(board)
    draw.text((12,10),"MYO-RYUNG / USER-SELECTED STYLE / 3 approved + remaining review candidates",fill="white")
    cards=[]
    for n,r in enumerate(records):
        state=r["visual_state_id"]
        col,row=n%6,n//6
        xx,yy=col*256,40+row*280
        pose=Image.open(out/state/f"{state}-r01-keypose-128.png")
        board.paste(matte(pose).resize((256,256),Image.Resampling.NEAREST),(xx,yy))
        draw.text((xx+4,yy+258),state+(" [approved]" if r["user_approved"] else ""),fill="white")
        escaped=html.escape(state)
        cards.append(f'<article><h2>{escaped}</h2><p>{"승인 완료" if r["user_approved"] else "승인 대기"}</p><img class="motion" src="{escaped}/{escaped}-r01.gif"><p><a href="{escaped}/{escaped}-r01-clean.png">16포즈 투명 시트</a> · <a href="{escaped}/{escaped}-r01.gif">GIF</a></p></article>')
    board.save(out/"31-motion-overview.png")
    page='<!doctype html><html lang="ko"><meta charset="utf-8"><title>묘령 그림체 통일 모션 검토</title><style>body{background:#202b3b;color:#edf2ff;font:16px system-ui;margin:28px}a{color:#9bdfff}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(250px,1fr));gap:18px}article{background:#344154;border-radius:12px;padding:16px}h2{font-size:16px}.motion{width:256px;height:256px;image-rendering:pixelated}p{line-height:1.5}</style><h1>묘령 그림체 통일 모션 검토</h1><p>승인된 3종은 변경하지 않았습니다. 나머지 모션은 개별 승인 대기입니다. GIF는 검토용 반복 재생이며 전투 판정·실제 게임 반복 설정을 바꾸지 않습니다.</p><p><a href="style-detail-comparison.png">그림체 기준 비교</a> · <a href="ja-hyun-size-comparison.png">자현 크기 비교</a> · <a href="31-motion-report.json">파일·해시 기록</a></p><div class="grid">'+''.join(cards)+'</div></html>'
    (out/"index.html").write_text(page)
    approved_unchanged()
    print("REVIEW",len(records),"/31; approved 3 unchanged; remaining user approval pending.")

if __name__=="__main__":
    main()
