#!/usr/bin/env python3
"""MENU09 소개용 영상. 기존 원화/리소스를 읽기만 하며 게임 실행 경로는 바꾸지 않는다."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent / "video"
SIZE = (1280, 720)
FPS = 60
FONT = "/System/Library/Fonts/AppleSDGothicNeo.ttc"
BG = ROOT / "forest_arena/assets/quality/high/background/bg_splash_forest.png"
MANIFEST = ROOT / "assets/character/manifest.json"
LAYOUT = ROOT / "forest_arena/data/character_display_layout_v01.json"
NAMES = {"ja-hyun": "자현", "nabi": "나비", "myo-ryung": "묘령", "yu-ran": "유란"}
MOTIONS = {
    "light": ("attack_light_combo_01", "약공격"),
    "heavy": ("attack_heavy_side", "강공격"),
    "jump-light": ("attack_air_light", "공중 약공격"),
    "jump-heavy": ("attack_air_heavy", "공중 강공격"),
    "special": ("special_neutral", "특수공격"),
}
MOVESETS = {
    "ja-hyun": "assets/combat/movesets/two_fighter_ja_hyun_moveset.tres",
    "nabi": "assets/combat/movesets/two_fighter_nabi_moveset.tres",
    "myo-ryung": "assets/combat/movesets/myo_ryung_moveset.tres",
    "yu-ran": "assets/combat/movesets/yu_ran_moveset.tres",
}


def source_motion_ids(cid, short):
    # Two-fighter movesets are the active game selection; library-only characters
    # retain their existing complete authored combo sequence.
    if cid in ("ja-hyun", "nabi"):
        text = (ROOT / MOVESETS[cid]).read_text()
        parts = dict(re.findall(r'\[sub_resource type="Resource" id="([^"]+)"\](.*?)(?=\n\[)', text, re.S))
        ids = sorted(k for k in parts if re.fullmatch(r"Attack_light_\d+", k)) if short == "light" else [{
            "heavy": "Attack_heavy", "jump-light": "Attack_air_light", "jump-heavy": "Attack_air_heavy", "special": "Attack_special"}[short]]
        return [re.search(r'visual_state_id = &"([^"]+)"', parts[k])[1] for k in ids]
    if short == "light":
        return [f"attack_light_combo_{i:02}" for i in range(1, 5 if cid == "myo-ryung" else 4)]
    return [MOTIONS[short][0]]


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def rel(path: Path) -> str:
    return str(path.relative_to(ROOT))


def font(size: int):
    return ImageFont.truetype(FONT, size)


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def entries():
    return {(a.get("character_id"), a.get("visual_state_id")): a
            for a in json.loads(MANIFEST.read_text())["assets"] if a.get("type") == "animation-runtime"}


def read_motion(entry):
    tres = ROOT / entry["sprite_frames_path"].removeprefix("res://")
    text = tres.read_text()
    ext = dict((eid, ROOT / p.removeprefix("res://")) for p, eid in re.findall(
        r'\[ext_resource type="Texture2D" path="([^"]+)" id="([^"]+)"\]', text))
    atlas = {}
    for rid, body in re.findall(r'\[sub_resource type="AtlasTexture" id="([^"]+)"\](.*?)(?=\n\[)', text, re.S):
        atlas_id = re.search(r'atlas = ExtResource\("([^"]+)"\)', body)[1]
        region = [float(v.strip()) for v in re.search(r'region = Rect2\(([^)]+)\)', body)[1].split(",")]
        atlas[rid] = (ext[atlas_id], region)
    frame_rows = re.findall(r'\{"duration": ([0-9.]+), "texture": SubResource\("([^"]+)"\)\}', text)
    fps = float(re.search(r'"speed": ([0-9.]+)', text)[1])
    frames, record = [], []
    for duration, rid in frame_rows:
        path, (x, y, w, h) = atlas[rid]
        sheet = Image.open(path).convert("RGBA")
        frames.append(sheet.crop((int(x), int(y), int(x+w), int(y+h))))
        record.append({"sub_resource": rid, "region": [x, y, w, h], "duration_weight": float(duration)})
    paths = sorted({p for p, _ in atlas.values()})
    for p in paths:
        if p == ROOT / entry["path"]:
            assert sha(p) == entry["sha256"], str(p)
    layout = {"scale": entry.get("presentation_scale", 1), "foot_pivot_y": entry.get("foot_pivot_y", 128)}
    for row in json.loads(LAYOUT.read_text())["motions"]:
        if row["character_id"] == entry["character_id"] and row["motion_id"] == entry["visual_state_id"] and row["asset_sha256"] == entry["sha256"]:
            layout = {"scale": row["scale"], "foot_pivot_y": row["foot_pivot_y"]}
    return frames, {
        "asset_id": entry["asset_id"], "character_id": entry["character_id"], "motion_id": entry["visual_state_id"],
        "sprite_frames": rel(tres), "sprite_frames_sha256": sha(tres),
        "sheets": [{"path": rel(p), "sha256": sha(p)} for p in paths],
        "source_fps": fps, "source_loop": '"loop": true' in text, "frames": record,
        "display_layout": layout, "manifest_status_verbatim": entry.get("status"),
        "registration_approval_record": entry.get("motion_registration", {}).get("approval_record"),
    }


def base(title, subtitle, badge="원화 모션 시연", footer="기존 원화 재사용 · 전투 판정·이동·효과를 재현한 게임 녹화가 아닙니다"):
    bg = ImageOps.fit(Image.open(BG).convert("RGBA"), SIZE)
    bg.alpha_composite(Image.new("RGBA", SIZE, (4, 13, 12, 210)))
    d = ImageDraw.Draw(bg)
    d.text((64, 34), "FOREST ARENA  /  MENU09", font=font(20), fill="#B5C9BC")
    d.text((64, 76), title, font=font(42), fill="#F2E8C9")
    d.text((64, 132), subtitle, font=font(23), fill="#D1DED4")
    badge_w = d.textbbox((0, 0), badge, font=font(20))[2]+40
    d.rounded_rectangle((1216-badge_w, 42, 1216, 86), radius=18, fill="#183B31", outline="#7A9F86")
    d.text((1236-badge_w, 53), badge, font=font(20), fill="#B8E3C2")
    d.line((64, 184, 1216, 184), fill="#877C51", width=1)
    d.ellipse((320, 552, 960, 624), fill=(12, 29, 24, 190), outline="#556C59", width=1)
    d.line((64, 648, 1216, 648), fill="#465C4D", width=1)
    d.text((64, 667), footer, font=font(18), fill="#ADBFB1")
    return bg


def composite_sprite(canvas, frame, layout, anchor=(640, 580), zoom=3.35):
    s = zoom * float(layout["scale"])
    sprite = frame.resize((round(frame.width*s), round(frame.height*s)), Image.Resampling.LANCZOS)
    pos = (round(anchor[0] - 64*s), round(anchor[1] - float(layout["foot_pivot_y"])*s))
    canvas.alpha_composite(sprite, pos)
    return pos, s


def contact_frames(slug, all_frames, source_records):
    # Every source frame is visible, including repeated poses and full 128px cells.
    n = len(all_frames)
    columns = 8
    tile_w, tile_h = 160, 182
    sheet = Image.new("RGB", (columns*tile_w, math.ceil(n/columns)*tile_h+52), "#10241C")
    draw = ImageDraw.Draw(sheet)
    draw.text((16, 12), slug + "  /  전체 원화 프레임", font=font(20), fill="#E6DBB9")
    for i, frame in enumerate(all_frames):
        x, y = (i % columns)*tile_w, (i//columns)*tile_h+52
        sheet.paste(frame, (x+16, y+8), frame)
        draw.text((x+16, y+145), f"F{i:02}", font=font(18), fill="#C0D5C4")
    path = OUT / (slug + "-frames.png")
    sheet.save(path)
    return rel(path)


def encode(slug, timeline, render, poster_index, meta):
    target = OUT / (slug + ".mp4")
    log = OUT / (slug + "-encode.log")
    with log.open("w") as handle:
        p = subprocess.Popen(["ffmpeg", "-y", "-loglevel", "warning", "-f", "rawvideo", "-pix_fmt", "rgb24",
                              "-s", "1280x720", "-r", str(FPS), "-i", "-", "-an", "-c:v", "libx264",
                              "-preset", "fast", "-crf", "20", "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(target)],
                             stdin=subprocess.PIPE, stdout=handle, stderr=handle)
        cache = {}
        for t in timeline:
            key = json.dumps(t, sort_keys=True)
            if key not in cache:
                cache[key] = render(t).convert("RGB").tobytes()
            p.stdin.write(cache[key])
        p.stdin.close()
        assert p.wait() == 0, log.read_text()
    poster = OUT / (slug + "-poster.png")
    render(timeline[poster_index]).convert("RGB").save(poster)
    # Compositor timeline contact sheet. Independent QA additionally extracts actual encoded MP4 frames.
    samples = [min(len(timeline)-1, round(i*(len(timeline)-1)/7)) for i in range(8)]
    sheet = Image.new("RGB", (1280, 2*202+32), "#10241C")
    for i, tick in enumerate(samples):
        thumb = render(timeline[tick]).convert("RGB").resize((320,180), Image.Resampling.LANCZOS)
        x, y = (i%4)*320, (i//4)*202
        sheet.paste(thumb, (x,y))
        ImageDraw.Draw(sheet).text((x+8,y+182), f"{tick/FPS:.3f} s", font=font(16), fill="#C0D5C4")
    sheet.save(OUT / (slug+"-timeline.png"))
    probe = json.loads(subprocess.check_output(["ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", str(target)]))
    subprocess.run(["ffmpeg", "-v", "error", "-i", str(target), "-f", "null", "-"], check=True, capture_output=True)
    meta.update({"file": rel(target), "sha256": sha(target), "poster": rel(poster), "poster_sha256": sha(poster),
                 "timeline_sheet": rel(OUT/(slug+"-timeline.png")), "width": 1280, "height": 720,
                 "output_fps": FPS, "duration_seconds": len(timeline)/FPS, "audio": False, "codec": "h264",
                 "encoded_probe": probe, "presentation_timeline": timeline, "decode": "pass"})
    return meta


def character_video(cid, short, selected_entries):
    motion, label = MOTIONS[short]
    slug = cid+"-"+short
    data = [read_motion(entry) for entry in selected_entries]
    frames = [f for fs, _ in data for f in fs]
    active = cid in ("ja-hyun", "nabi")
    subtitle = (f"{len(data)}타 연계 원화 · 정상 원화 속도 · 2회 시연" if short == "light" else
                "기존 원화 모션 · 정상 원화 속도 · 2회 시연")
    board = base(f"{NAMES[cid]} · {label}", subtitle,
                 "현재 캐릭터" if active else "설계 도감용 · 현재 경기 비활성")
    if short == "heavy":
        label = "상향 강공격 원화" if data[0][1]["motion_id"] == "attack_heavy_up" else "가로 강공격 원화"
        ImageDraw.Draw(board).text((64, 207), label, font=font(20), fill="#C9BC8E")
    elif short == "special":
        label = {"special_scarf_sweep": "스카프 연속 휩쓸기 원화", "special_side": "측면 특수공격 원화"}.get(data[0][1]["motion_id"], "중립 특수공격 원화")
        ImageDraw.Draw(board).text((64, 207), label, font=font(20), fill="#C9BC8E")
    # Source duration is sampled at 60FPS; cumulative boundaries preserve total
    # duration for the approved 24FPS/32-frame special sheets without interpolation.
    cycle = []
    for section, (fs, src) in enumerate(data):
        elapsed = 0.0
        last_boundary = 0
        for i, row in enumerate(src["frames"]):
            elapsed += row["duration_weight"] / src["source_fps"]
            boundary = math.floor(elapsed*FPS+.5)
            cycle.extend([{"section": section, "frame": i}]*(boundary-last_boundary))
            last_boundary = boundary
    first, last = {"section": 0, "frame": 0}, {"section": len(data)-1, "frame": len(data[-1][0])-1}
    timeline = [first]*24 + cycle + [last]*30 + cycle + [last]*30
    anchor = (640, 520 if "jump" in short else 580)
    def render(t):
        fs, src = data[t["section"]]
        result = board.copy()
        composite_sprite(result, fs[t["frame"]], src["display_layout"], anchor)
        if short == "light":
            ImageDraw.Draw(result).text((64, 207), f"연계 {t['section']+1} / {len(data)}", font=font(20), fill="#C9BC8E")
        return result
    meta = {"slot": f"VIDEO/{cid}/{short}", "title": NAMES[cid]+" · "+label,
            "kind": "existing-sprite-art-demonstration", "current_match_active": active,
            "source": [src for _, src in data], "source_frame_sheet": contact_frames(slug, frames, []),
            "source_moveset": {"path": MOVESETS[cid], "sha256": sha(ROOT/MOVESETS[cid])},
            "sampling": "원본 시간 누적 경계를60fps로 반올림. 12fps는각5프레임,24fps는각2/3프레임 교대로 표시. 총 원본재생시간 보존·새중간그림없음.",
            "common_canvas_zoom": 3.35, "presentation_note": "현재 moveset 연결(비활성 캐릭터는 기존 도감 순서), SpriteFrames 순서·FPS와 해시 결합 표시 배율을 재사용한 원화 시연. 실제 전투·판정·절차 효과 녹화가 아님."}
    return encode(slug, timeline, render, 24+5*5, meta)


def weighted_frame(progress, begin, end, weights):
    cursor = min(max(progress,0), .999999)*sum(weights[begin:end])
    for i in range(begin,end):
        cursor -= weights[i]
        if cursor < 0: return i
    return end-1


def yoyo_video(source_entries):
    # Existing phase timings are used for the intro drawing. No hits, terrain or cooldown simulation.
    data = [(entry, *read_motion(entry)) for entry in source_entries]
    icon = Image.open(ROOT/"forest_arena/assets/common/accessory/pebble_yoyo.png").convert("RGBA")
    combat = Image.open(ROOT/"forest_arena/assets/common/accessory/pebble_yoyo_combat.png").convert("RGBA")
    ability = ROOT/"assets/loadouts/pebble_yoyo_accessory.tres"
    text = ability.read_text()
    durations = [int(re.search(rf"{name}_ticks = (\d+)",text)[1]) for name in ("startup","extend","return","recovery")]
    reach = float(re.search(r"reach = ([0-9.]+)",text)[1])
    phases = ["준비", "발사", "회수", "회복"]
    timeline = []
    for section, (entry, frames, src) in enumerate(data):
        spans = entry["equipment_phase_frame_ranges"]
        timeline.extend([{"section":section,"frame":0,"phase":-1,"tick":0}]*24)
        for phase, duration in enumerate(durations):
            for tick in range(duration):
                i = weighted_frame(tick/max(duration-1,1),*spans[phase],[f["duration_weight"] for f in src["frames"]])
                timeline.append({"section":section,"frame":i,"phase":phase,"tick":tick})
        timeline.extend([{"section":section,"frame":len(frames)-1,"phase":-1,"tick":0}]*36)
    def render(t):
        entry, frames, src = data[t["section"]]
        air = entry["visual_state_id"].endswith("air")
        result = base("조약돌 요요", f"{NAMES[entry['character_id']]} · {'공중' if air else '지상'} 사용 원화", "현재 사용 가능한 신기",
                      "기존 원화·장비 단계 시간을 활용한 소개 · 충돌·적중 판정은 표현하지 않습니다")
        icon_small = ImageOps.contain(icon,(112,112),Image.Resampling.LANCZOS)
        result.alpha_composite(icon_small,(1032,222))
        anchor = (500,520 if air else 580)
        pos,s = composite_sprite(result,frames[t["frame"]],src["display_layout"],anchor,zoom=2.8)
        d=ImageDraw.Draw(result)
        for phase, name in enumerate(phases):
            d.text((64+phase*110,211),name,font=font(20),fill="#E8D18C" if phase==t["phase"] else "#93AD9A")
        if t["phase"] >= 0:
            phase,tick=t["phase"],t["tick"]
            hand=entry["frame_anchors"][t["frame"]]["equipment_hand"]
            root=(pos[0]+hand[0]*s,pos[1]+hand[1]*s)
            origin=(anchor[0]+24*2.8,anchor[1]-46*2.8)
            if phase in (0,3): tip=root
            elif phase==1:
                progress=(tick+1)/durations[1]
                tip=(origin[0]+reach*progress*2.8,origin[1])
            else:
                progress=(tick+1)/durations[2]
                raw=(origin[0]+reach*(1-progress)*2.8,origin[1])
                tip=(raw[0]+(root[0]-origin[0])*progress,raw[1]+(root[1]-origin[1])*progress)
            if math.dist(root,tip)>2:
                d.line((root,tip),fill="#FFF0CA",width=4)
            disc=ImageOps.contain(combat,(78,78),Image.Resampling.LANCZOS)
            rotation=0 if phase==0 else ((sum(durations[:phase])-durations[0]+tick+1)*360/12 if phase<3 else sum(durations[1:3])*360/12)
            disc=disc.rotate(-rotation,Image.Resampling.BICUBIC,expand=True)
            result.alpha_composite(disc,(round(tip[0]-disc.width/2),round(tip[1]-disc.height/2)))
        return result
    all_frames=[frame for _,frames,_ in data for frame in frames]
    meta={"slot":"VIDEO/accessory/pebble-yoyo","title":"조약돌 요요 소개","kind":"existing-equipment-art-introduction",
          "current_match_active":True,"source":[src for _,_,src in data],"phase_durations_ticks":durations,"tick_rate":60,
          "supporting_sources":[{"path":rel(p),"sha256":sha(p)} for p in (ability,ROOT/"forest_arena/assets/common/accessory/pebble_yoyo.png",ROOT/"forest_arena/assets/common/accessory/pebble_yoyo_combat.png",ROOT/"scripts/equipment_visual.gd",ROOT/"scripts/local_fighter_presentation.gd")],
          "source_frame_sheet":contact_frames("accessory-pebble-yoyo",all_frames,[]),"common_canvas_zoom":2.8,
          "presentation_note":"기존 장비 4구간 시간/손 앵커/요요 이미지를 활용한 무충돌 소개 합성. 실제 경기 녹화가 아니며 전투 코드·판정·쿨다운은 변경하지 않음."}
    return encode("accessory-pebble-yoyo",timeline,render,24+6+15,meta)


def iron_video():
    image=OUT.parent/"images/iron-armor.png"
    if not image.exists(): return None
    resource=ROOT/"assets/loadouts/fixtures/iron_armor_accessory.tres"
    icon=Image.open(image).convert("RGBA")
    board=base("철갑옷", "기존 신기 정보 소개", "현재 경기 비활성", "설계 도감용 소개 · 현재 경기에서 장착할 수 없습니다")
    icon=ImageOps.contain(icon,(400,400),Image.Resampling.LANCZOS)
    board.alpha_composite(icon,(220+(400-icon.width)//2,215+(400-icon.height)//2))
    d=ImageDraw.Draw(board)
    d.text((720,290),"무게  +5%",font=font(36),fill="#E8D18C")
    d.text((720,355),"지상 속도  -5%",font=font(36),fill="#D1DED4")
    d.text((720,431),"현재 데이터 기준",font=font(22),fill="#A5B8A9")
    d.text((720,466),"능동 사용 기술 없음",font=font(22),fill="#A5B8A9")
    meta={"slot":"VIDEO/accessory/iron-armor","title":"철갑옷 소개","kind":"inactive-fixture-information",
          "current_match_active":False,"source":[],"supporting_sources":[{"path":rel(p),"sha256":sha(p)} for p in (image,resource)],
          "presentation_note":"신규 아이콘과 기존 비활성 fixture의 무게1.05/지상속도0.95 정보를 설명. 경기 사용·새 전투 모션을 표현하지 않음."}
    return encode("accessory-iron-armor",[0]*240,lambda _:board,0,meta)


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--iron-only",action="store_true")
    parser.add_argument("--slot")
    args=parser.parse_args()
    OUT.mkdir(exist_ok=True)
    destination=OUT/"manifest.json"
    records=[]
    if args.iron_only or args.slot:
        if destination.exists(): records=json.loads(destination.read_text())["videos"]
    e=entries()
    if not args.iron_only:
        for cid in NAMES:
            for short,(motion,label) in MOTIONS.items():
                if args.slot and args.slot != f"VIDEO/{cid}/{short}": continue
                print(f"Rendering {cid}/{short}",flush=True)
                row=character_video(cid,short,[e[cid,m] for m in source_motion_ids(cid,short)])
                records=[r for r in records if r["slot"]!=row["slot"]]+[row]
                write_json(destination,{"schema_version":1,"videos":records})
        if not args.slot or args.slot=="VIDEO/accessory/pebble-yoyo":
            print("Rendering accessory/pebble-yoyo",flush=True)
            row=yoyo_video([e[cid,m] for cid in ("ja-hyun","nabi") for m in ("equipment_yoyo_ground","equipment_yoyo_air")])
            records=[r for r in records if r["slot"]!=row["slot"]]+[row]
    if not args.slot or args.slot=="VIDEO/accessory/iron-armor":
        row=iron_video()
        if row: records=[r for r in records if r["slot"]!=row["slot"]]+[row]
    write_json(destination,{"schema_version":1,"created_on":"2026-11-05","generator":rel(Path(__file__).resolve()),
                            "video_count":len(records),"background":{"path":rel(BG),"sha256":sha(BG)},
                            "source_manifest":{"path":rel(MANIFEST),"sha256":sha(MANIFEST)},
                            "display_calibration":{"path":rel(LAYOUT),"sha256":sha(LAYOUT)},"videos":records})
    print(f"Completed {len(records)} videos",flush=True)


if __name__=="__main__": main()
