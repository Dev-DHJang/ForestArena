"""Prepare visual evidence and validate human motion reviews; never infer action quality."""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import html
import json
import math
from pathlib import Path
import shutil

from PIL import Image, ImageDraw
from motion_review_candidates import load_selection, local_path
from motion_layout import layout, frame_box, motion_id

STATES = {
    "idle": "대기 호흡; 이동·공격과 구별되고 자연스럽게 반복",
    "run": "달리기; 발 교대와 몸의 무게 이동, 자연스러운 반복",
    "jump": "상승→정점→하강→지상 착지; 공중에 착지 자세를 표시하지 않음",
    "guard": "앞을 막는 방어 자세를 만들고 실제 정지 프레임에서도 유지",
    "evade": "몸을 낮추거나 이동하며 피하기; 달리기·공격과 구별",
    "attack_heavy_charge": "CHARGE 상태의 힘 모으기와 해제 후 강공격에 같은 ID를 사용한다. 두 맥락을 각각 검토",
    "hitstun": "맞은 순간의 반응과 경직; 자발적 공격·방어와 구별",
    "launch": "타격으로 공중에 밀려나는 반응; 점프·착지와 구별",
    "knock_down": "균형을 잃고 바닥에 넘어짐; 일어남과 구별",
    "wake_up": "넘어진 자세에서 몸을 일으켜 대기 자세로 복귀",
    "death": "마지막 사망과 끝 자세; 방어·대기와 구별",
    "ring_out": "장외 탈락하며 균형을 잃거나 화면 밖으로 떨어짐",
    "spawn": "등장해 전투 가능한 자세로 자리 잡음",
    "attack_light_up": "짧고 빠른 위쪽 약공격",
    "attack_light_down": "짧고 빠른 아래쪽 약공격",
    "attack_heavy_side": "옆 방향의 큰 준비와 강한 타격·회복",
    "attack_heavy_up": "위쪽을 향한 강한 타격·회복",
    "attack_heavy_down": "낮은 방향을 향한 강한 타격·회복",
    "attack_dash_light": "전진 접근하며 빠른 약공격",
    "attack_dash_heavy": "전진 접근하며 큰 강공격",
    "attack_air_light": "공중에서 빠른 약공격; 지상 발 디딤과 구별",
    "attack_air_heavy": "공중에서 큰 강공격; 지상 발 디딤과 구별",
}
CHECKS = ("all_frames", "normal_playback", "slow_playback", "runtime_timing", "mirrored", "small_scale")


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path: Path):
    return json.loads(path.read_text())


def write(path: Path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def entries(root: Path):
    return [r for r in read(root / "assets/character/manifest.json")["assets"] if r.get("type") == "animation-runtime"]


def action(root: Path, cid: str, motion: str):
    for row in entries(root):
        if row.get('character_id') != cid or motion_id(row) != motion:
            continue
        registration = row.get('motion_registration', {})
        if not registration:
            break
        catalog = local_path(root, registration['catalog_path'], candidate=True)
        if sha(catalog) != registration['catalog_sha256']:
            raise ValueError('registered motion catalog changed: ' + str(catalog))
        original = next(r for r in read(catalog)['assets']
                        if r['character_id'] == cid and motion_id(r) == motion)
        return original['expected_action'], original['action_source']
    if motion == "attack_heavy_charge":
        return STATES[motion], "scripts/fighter_controller.gd"
    for character in read(root / "docs/contracts/attack-system-v01.json")["characters"]:
        if character["character_id"] == cid:
            if motion in {"attack_light_up", "attack_light_down", "attack_heavy_up", "attack_heavy_down"} and character.get("directional_attack_profile"):
                return STATES[motion] + "; " + character["directional_attack_profile"], "docs/contracts/attack-system-v01.json"
            for move in character.get("moves", []):
                if move.get("visual_state_id") == motion:
                    return move["role"], "docs/contracts/attack-system-v01.json"
    return STATES.get(motion, "미정: 기대 행위를 담당자에게 확인"), "docs/gameplay/combat.md"


def compact(samples):
    result = []
    for sample in samples:
        key = (sample["frame"], sample["phase"], sample["shown"])
        if result and tuple(result[-1][:3]) == key:
            result[-1][3] += sample["duration_ms"]
        else:
            result.append([*key, sample["duration_ms"]])
    return result


def timeline_errors(root: Path, timeline: dict, rows: list, selection: dict | None = None) -> list[str]:
    errors = list(timeline.get("errors", []))
    if timeline.get("schema_version") != 1 or not timeline.get("sources"):
        errors.append("missing timeline source fingerprints")
    required_sources = {"assets/character/manifest.json", "scripts/local_fighter_presentation.gd", "scripts/fighter_controller.gd", "docs/contracts/attack-system-v01.json", "docs/gameplay/combat.md"}
    if (root / "tools/forest_arena/motion_layout.py").is_file():
        required_sources.add("tools/forest_arena/motion_layout.py")
    if (root / "scripts/fighter_attack_effects.gd").is_file():
        required_sources.add("scripts/fighter_attack_effects.gd")
    if selection is not None:
        required_sources.update(selection["required_sources"])
        if timeline.get("candidate_selection") != selection["candidate_selection"]:
            errors.append("timeline candidate catalog or original scope changed")
        if timeline.get("generator_sha256") != sha(root / "tools/forest_arena/motion_review_timeline.gd"):
            errors.append("candidate timeline generator changed or missing")
    elif timeline.get("candidate_selection"):
        errors.append("candidate timeline requires explicit catalog and scope")
    required_sources.update(r["sprite_frames_path"].removeprefix("res://") for r in rows)
    if not required_sources.issubset(timeline.get("sources", {})):
        errors.append("timeline lacks required code, action or SpriteFrames fingerprints")
    for path, digest in timeline.get("sources", {}).items():
        try:
            actual = local_path(root, path)
        except ValueError:
            errors.append(f"unsafe timeline source: {path}")
            continue
        if sha(actual) != digest:
            errors.append(f"timeline source changed: {path}")
    wanted = {(r["character_id"], motion_id(r)): r for r in rows}
    if len(wanted) != len(rows):
        errors.append("duplicate manifest motion")
    seen = Counter((r["character_id"], r["motion"]) for r in timeline.get("motions", []))
    if set(seen) != set(wanted) or any(n != 1 for n in seen.values()):
        errors.append("timeline coverage differs from manifest")
    for row in timeline.get("motions", []):
        key = row["character_id"], row["motion"]
        if key not in wanted:
            continue
        try:
            spec = layout(wanted[key])
        except ValueError as error:
            errors.append(f"invalid motion layout: {key}: {error}")
            continue
        if row.get("sheet_sha256") != sha(root / wanted[key]["path"]):
            errors.append(f"timeline sheet changed: {key}")
        if not row.get("variants"):
            errors.append(f"missing runtime variants: {key}")
        variants = row.get("variants", [])
        identifiers = [v.get("attack_id") for v in variants]
        if not row.get("required_variant_ids") or identifiers != row["required_variant_ids"]:
            errors.append(f"missing or unexpected runtime variant: {key}")
        if len(set(identifiers)) != len(identifiers):
            errors.append(f"duplicate runtime variant: {key}")
        if row["motion"] == "attack_heavy_charge" and not ("state:attack_heavy_charge" in identifiers and any("#charged-" in str(v) for v in identifiers)):
            errors.append(f"missing charge hold or dynamic release context: {key}")
        for variant in variants:
            samples = variant.get("samples", [])
            phase_counts = Counter(s.get("phase") for s in samples)
            if str(variant.get("attack_id", "")).startswith("state:"):
                source = wanted[key]
                state_ticks = math.ceil(sum(spec["frame_durations"]) / float(source["fps"]) * 60) * 2 if source.get("loop") and float(source.get("fps", 0)) > 0 else 120
                expected_phases = {"ascent": 20, "apex": 12, "descent": 20, "landing": 16} if row["motion"] == "jump" else {row["motion"]: state_ticks}
                if selection is not None and variant.get("attack_id") == "state:landing-down-18" and row["motion"] == "knock_down":
                    expected_phases = {"knock_down": 18}
                elif selection is not None and variant.get("attack_id") == "state:wakeup-protection-12" and row["motion"] == "wake_up":
                    expected_phases = {"wake_up": 12}
            else:
                lengths = variant.get("phase_ticks", [])
                expected_phases = dict(zip(("startup", "active", "recovery"), lengths)) if len(lengths) == 3 and all(isinstance(n, int) and n > 0 for n in lengths) else {}
            if str(variant.get("attack_id", "")).startswith("state:") and wanted[key].get("equipment_resource_path"):
                lengths = variant.get("phase_ticks", [])
                valid_lengths = len(lengths) == 4 and all(type(n) in (int,float) and math.isfinite(n) and n > 0 and int(n) == n for n in lengths)
                expected_phases = dict(zip(("startup","extend","return","recovery"),map(int,lengths))) if valid_lengths else {}
                spans = wanted[key].get("equipment_phase_frame_ranges", [])
                if len(spans) != 4:
                    errors.append(f"equipment requires four drawing phase ranges: {key}")
                elif valid_lengths:
                    for phase,(begin,end),ticks in zip(expected_phases,spans,lengths):
                        visible = {sample.get("frame") for sample in samples if sample.get("phase") == phase}
                        if end-begin > ticks or not set(range(begin,end)).issubset(visible):
                            errors.append(f"equipment phase skips authored drawings: {key}/{phase}")
            if selection is not None and not wanted[key].get("reuse_approved_runtime", False) and spec["frame_count"] != 16 and not str(variant.get("attack_id", "")).startswith("state:") and "phase_frame_ranges" not in wanted[key]:
                errors.append(f"variable-count attack requires explicit phase_frame_ranges: {key}")
            if selection is not None and not wanted[key].get("reuse_approved_runtime", False) and not str(variant.get("attack_id", "")).startswith("state:"):
                visible = {sample.get("frame") for sample in samples}
                if not set(range(spec["frame_count"])).issubset(visible):
                    errors.append(f"candidate authored drawing skipped by full attack playback: {key}")
            if not str(variant.get("attack_id", "")).startswith("state:") and "phase_frame_ranges" in wanted[key] and selection is not None and not wanted[key].get("reuse_approved_runtime", False):
                ranges = wanted[key]["phase_frame_ranges"]
                if len(lengths) == 3 and any(end - begin > ticks for (begin, end), ticks in zip(ranges, lengths)):
                    errors.append(f"candidate phase has more drawings than visible combat ticks: {key}")
                if len(lengths) == 3:
                    for phase, (begin,end) in zip(("startup","active","recovery"),ranges):
                        visible={sample.get("frame") for sample in samples if sample.get("phase")==phase}
                        if not set(range(begin,end)).issubset(visible):
                            errors.append(f"candidate authored drawing skipped by actual phase playback: {key}/{phase}")
            expected_order = [phase for phase, count in expected_phases.items() for _ in range(count)]
            if not expected_phases or dict(phase_counts) != expected_phases or [s.get("phase") for s in samples] != expected_order:
                errors.append(f"incomplete runtime phases or tick counts: {key}")
            if not variant.get("samples"):
                errors.append(f"missing runtime samples: {key}")
            for sample in variant.get("samples", []):
                if sample.get("shown") != row["motion"] or not isinstance(sample.get("frame"), int) or isinstance(sample.get("frame"), bool) or not 0 <= sample.get("frame", -1) < spec["frame_count"] or abs(sample.get("duration_ms", 0) - 1000 / 60) > 0.01:
                    errors.append(f"invalid runtime sample: {key}")
                    break
                if row["motion"] == "jump" and "jump_frame_ranges" in wanted[key]:
                    begin, end = wanted[key]["jump_frame_ranges"].get(sample.get("phase"), [-1,-1])
                    if not begin <= sample["frame"] < end:
                        errors.append(f"jump sample outside declared phase; airborne landing forbidden: {key}")
                        break
            if row["motion"] == "run" and "run_stride_px" in wanted[key] and str(variant.get("attack_id", "")).startswith("state:"):
                positions = [sample.get("position") for sample in samples]
                if not positions or any(not isinstance(p, list) or len(p) != 2 or any(not isinstance(n, (float, int)) or isinstance(n, bool) or not math.isfinite(n) for n in p) for p in positions):
                    errors.append(f"run_stride review requires finite displayed movement samples: {key}")
                else:
                    step = float(wanted[key]["run_stride_px"]) * 2 / len(positions)
                    if any(not math.isclose(p[0] - positions[0][0], i * step, abs_tol=0.001) for i, p in enumerate(positions)):
                        errors.append(f"run_stride review must cover two distance cycles: {key}")
    return errors


def make_board(sheet: Image.Image, name: str, destination: Path, spec: dict | None = None):
    spec = spec or layout({})
    board = Image.new("RGB", (528, 24 + math.ceil(spec["frame_count"] / 4) * 136), "#2d3238")
    draw = ImageDraw.Draw(board)
    draw.text((8, 6), name, fill="white")
    for index in range(spec["frame_count"]):
        x, y = 2 + index % 4 * 132, 24 + index // 4 * 136
        frame = sheet.crop(frame_box(index, spec)).convert("RGBA")
        back = Image.new("RGBA", (128, 128), "#a3a8ab")
        back.alpha_composite(frame)
        board.paste(back.convert("RGB"), (x, y))
        draw.text((x + 2, y + 125), str(index + 1), fill="white")
    board.save(destination, quality=88)


def prepare(root: Path, timeline_path: Path, output: Path, catalog: Path | None = None, scope: Path | None = None, scope_sha256: str | None = None):
    if bool(catalog) != bool(scope):
        raise ValueError("candidate review requires both --catalog and --scope")
    selection = load_selection(root, catalog, scope, scope_sha256) if catalog else None
    rows, timeline = selection["rows"] if selection else entries(root), read(timeline_path)
    errors = timeline_errors(root, timeline, rows, selection)
    if errors:
        raise ValueError("; ".join(errors))
    if (output / "motion-review.json").exists():
        raise ValueError("review already exists; use a new output directory to preserve human decisions")
    if selection and (not output.resolve().is_relative_to((root / "_workspace").resolve()) or output.resolve() == (root / "_workspace").resolve()):
        raise ValueError("candidate evidence output must stay inside project _workspace")
    output.mkdir(parents=True, exist_ok=True)
    (output / "boards").mkdir(exist_ok=True)
    (output / "sheets").mkdir(exist_ok=True)
    by_key = {(r["character_id"], r["motion"]): r for r in timeline["motions"]}
    review = {"schema_version": 1, "reviewer": "", "sources": timeline["sources"], "timeline_sha256": sha(timeline_path), "motions": []}
    if selection:
        review["candidate_selection"] = selection["candidate_selection"]
        review["reviewer_role"] = ""
        review["approval_status"] = "pending"
    cards = []
    for row in sorted(rows, key=lambda r: (r["character_id"], motion_id(r))):
        cid, motion = row["character_id"], motion_id(row)
        key = f"{cid}/{motion}"
        basename = f"{cid}__{motion}"
        board_path = f"boards/{basename}.jpg"
        sheet_path = f"sheets/{basename}.png"
        expected, source = (row["expected_action"], row["action_source"]) if selection else action(root, cid, motion)
        spec = layout(row)
        with Image.open(root / row["path"], formats=["PNG"]) as image:
            if image.size != spec["sheet_size"] or "A" not in image.getbands():
                raise ValueError(f"invalid sheet shape or alpha: {key}")
            for index in range(spec["frame_count"], spec["atlas_columns"] * spec["rows"]):
                x, y = index % spec["atlas_columns"] * 128, index // spec["atlas_columns"] * 128
                if image.crop((x,y,x+128,y+128)).getchannel("A").getbbox() is not None:
                    raise ValueError(f"unused atlas cell must be transparent: {key}")
            make_board(image, key, output / board_path, spec)
        shutil.copyfile(root / row["path"], output / sheet_path)
        variants = by_key[cid, motion]["variants"]
        timelines = [compact(v["samples"]) for v in variants]
        sprite_path = row["sprite_frames_path"].removeprefix("res://")
        material_hashes = {board_path: sha(output / board_path), sheet_path: sha(output / sheet_path)}
        review["motions"].append({
            "character_id": cid, "motion": motion, "path": row["path"], "sha256": sha(root / row["path"]),
            "sprite_frames_path": sprite_path, "sprite_frames_sha256": sha(root / sprite_path),
            "expected_action": expected, "action_source": source, "action_source_sha256": sha(root / source), "materials": material_hashes,
            "runtime_variants": [{"attack_id": v["attack_id"], "sequence": t} for v, t in zip(variants, timelines)],
            "checks": dict.fromkeys(CHECKS, False), "status": "blocked", "observations": "", "issues": [], "drafts": [],
        })
        if selection:
            review["motions"][-1]["asset_type"] = row["type"]
            review["motions"][-1]["reuse_approved_runtime"] = row.get("reuse_approved_runtime", False)
        options = "".join(f'<option value="{i}">{html.escape(v["attack_id"] or motion)}</option>' for i, v in enumerate(variants))
        cards.append(f'''<article id="{basename}" data-character="{cid}" data-columns="{spec['atlas_columns']}"><h2>{html.escape(key)}</h2>
<p>{html.escape(expected)}</p><div class="play"><canvas width="256" height="256"></canvas></div>
<label>게임 변형 <select class="variant">{options}</select></label>
<label>비교 <select class="playback-mode"><option value="runtime">게임 코드의 실제 타이밍</option><option value="authored">전체 {spec["frame_count"]}프레임 원화 FPS</option></select></label>
<button class="slow">속도 1×</button><button class="mirror">좌우 반전</button><button class="small">작게</button><button class="pause">정지</button>
<p class="time"></p><details><summary>전체 {spec["frame_count"]}프레임</summary><img class="board" src="{board_path}"></details>
<img class="sheet" src="{sheet_path}" hidden><script type="application/json">{json.dumps(timelines)}</script><script class="authored-timeline" type="application/json">{json.dumps([[i, "authored-only", motion, 1000.0 * spec["frame_durations"][i] / float(row.get("fps", 12))] for i in range(spec["frame_count"])])}</script></article>''')
    shutil.copyfile(timeline_path, output / "timeline.json")
    page = '''<!doctype html><meta charset="utf-8"><title>모션 행위 검토</title>
<style>body{background:#172128;color:#eef1f4;font:15px system-ui;margin:16px}nav{position:sticky;top:0;background:#172128;padding:12px;z-index:2}main{display:grid;grid-template-columns:repeat(3,minmax(300px,1fr));gap:12px}article{background:#293840;padding:12px;min-height:440px}h2{font-size:15px}p{min-height:36px}button,select{font:14px system-ui;margin:3px;padding:5px}.play{height:256px;display:flex;justify-content:center}canvas{image-rendering:auto;background:#94999e}.board{width:100%}body.wall main{grid-template-columns:repeat(4,minmax(0,1fr))}body.wall article{padding:4px;min-height:140px}body.wall h2{font-size:10px;overflow-wrap:anywhere}body.wall .play{height:96px}body.wall canvas{width:96px;height:96px}body.wall article>p:not(.time),body.wall article>label,body.wall article>button,body.wall details{display:none}body.wall .time{font-size:9px;min-height:20px}</style>
<h1>모션 행위 검토</h1><p>현재 표현 코드를 실행한 60Hz 검토 기록입니다. 비반복 상태는2초 강제 유지, 반복 모션은완전한2주기, 점프는 단계별 속도를 지정한 시험이며 실제 경기의 상태 수명과 구분합니다. 차지는 유지·해제 변형을 따로 선택하세요. 페이지 표시 자체가 QA 통과는 아닙니다.</p>
<nav><label>캐릭터 <select id="character"><option value="">전체</option><option>ja-hyun</option><option>myo-ryung</option><option>nabi</option><option>yu-ran</option></select></label><label>검색 <input id="search"></label><button id="allslow">전체 속도</button><button id="allmirror">전체 좌우</button><button id="allsmall">전체 크기</button><button id="wall">모아보기</button><span id="count"></span></nav><main>''' + "\n".join(cards) + '''</main>
<script>
const players=[...document.querySelectorAll('article')].map(a=>{
 const canvas=a.querySelector('canvas'),ctx=canvas.getContext('2d'),sheet=a.querySelector('.sheet'),variants=JSON.parse(a.querySelector('script').textContent);
 let elapsed=0,last=performance.now(),speed=1,mirror=false,small=false,paused=false;
 const select=a.querySelector('select'),mode=a.querySelector('.playback-mode'),authored=JSON.parse(a.querySelector('.authored-timeline').textContent);select.onchange=mode.onchange=()=>elapsed=0;
 a.querySelector('.slow').onclick=()=>{speed=speed===1?.25:1;a.querySelector('.slow').textContent='속도 '+speed+'×'};
 a.querySelector('.mirror').onclick=()=>mirror=!mirror;
 a.querySelector('.small').onclick=()=>small=!small;
 a.querySelector('.pause').onclick=()=>{paused=!paused;a.querySelector('.pause').textContent=paused?'재생':'정지'};
 function draw(now){if(!paused)elapsed+=(now-last)*speed;last=now;
 const seq=mode.value==='runtime'?variants[Number(select.value)]:authored,duration=seq.reduce((n,s)=>n+s[3],0);let t=elapsed%duration,i=0;
 while(i<seq.length-1&&t>=seq[i][3])t-=seq[i++][3];const s=seq[i];ctx.clearRect(0,0,256,256);ctx.save();ctx.translate(128,128);ctx.scale(mirror?-1:1,1);const size=small?128:256;if(sheet.complete)ctx.drawImage(sheet,(s[0]%Number(a.dataset.columns))*128,Math.floor(s[0]/Number(a.dataset.columns))*128,128,128,-size/2,-size/2,size,size);ctx.restore();
 a.querySelector('.time').textContent='frame '+(s[0]+1)+' / '+s[1]+' / '+Math.round(elapsed%duration)+' ms';requestAnimationFrame(draw)}requestAnimationFrame(draw);return a});
function filter(){let count=0;for(const a of players){a.hidden=!!((character.value&&a.dataset.character!==character.value)||!a.id.includes(search.value));if(!a.hidden)count++}document.querySelector('#count').textContent=count+' motions'}
const character=document.querySelector('#character'),search=document.querySelector('#search');character.onchange=search.oninput=filter;filter();
document.getElementById('wall').onclick=()=>document.body.classList.toggle('wall');
for(const [id,cls] of [['allslow','slow'],['allmirror','mirror'],['allsmall','small']])document.getElementById(id).onclick=()=>players.filter(a=>!a.hidden).forEach(a=>a.querySelector('.'+cls).click());
</script>'''
    (output / "index.html").write_text(page)
    if selection:
        review["evidence_sha256"] = {name: sha(output / name) for name in ("index.html", "timeline.json")}
    write(output / "motion-review.json", review)
    print(f"prepared {len(rows)} motions: {output / 'index.html'}")


def validate(root: Path, path: Path, require_pass: bool = False, catalog: Path | None = None, scope: Path | None = None, scope_sha256: str | None = None) -> list[str]:
    review = read(path)
    errors = []
    if bool(catalog) != bool(scope):
        return ["candidate review requires both --catalog and --scope"]
    try:
        selection = load_selection(root, catalog, scope, scope_sha256) if catalog else None
    except (ValueError, OSError, TypeError, KeyError) as error:
        return [str(error)]
    if selection:
        if review.get("candidate_selection") != selection["candidate_selection"]:
            errors.append("review candidate catalog or original scope changed")
        if review.get("approval_status") != "pending":
            errors.append("QA review must not claim user approval or runtime registration")
        if review.get("reviewer_role") != "qa":
            errors.append("missing independent qa reviewer role")
        evidence = review.get("evidence_sha256", {})
        if set(evidence) != {"index.html", "timeline.json"}:
            errors.append("missing candidate comparison playback evidence")
        for name, digest in evidence.items():
            if name not in {"index.html", "timeline.json"} or not (path.parent / name).is_file() or sha(path.parent / name) != digest:
                errors.append("candidate playback evidence changed: " + name)
    elif review.get("candidate_selection"):
        errors.append("candidate review requires explicit catalog and scope")
    if review.get("schema_version") != 1 or not str(review.get("reviewer", "")).strip():
        errors.append("missing schema or independent reviewer")
    wanted = {(r["character_id"], motion_id(r)): r for r in (selection["rows"] if selection else entries(root))}
    rows = review.get("motions", [])
    counts = Counter((r.get("character_id"), r.get("motion")) for r in rows)
    if set(counts) != set(wanted) or any(n != 1 for n in counts.values()):
        errors.append("missing, duplicate or unexpected motion review")
    if not review.get("sources"):
        errors.append("missing source fingerprints")
    for source, digest in review.get("sources", {}).items():
        if not (root / source).is_file() or sha(root / source) != digest:
            errors.append(f"review source changed: {source}")
    timeline_path = path.parent / "timeline.json"
    recorded_timeline = None
    if not timeline_path.is_file() or sha(timeline_path) != review.get("timeline_sha256"):
        errors.append("review timeline changed or missing")
    else:
        recorded_timeline = read(timeline_path)
        errors.extend(timeline_errors(root, recorded_timeline, list(wanted.values()), selection))
    timeline_rows = {(r["character_id"], r["motion"]): r for r in (recorded_timeline or {}).get("motions", [])}
    if require_pass and any(row.get("status") != "pass" for row in rows):
        errors.append("motion decisions are not all pass")
    for row in rows:
        key = row.get("character_id"), row.get("motion")
        if key not in wanted:
            continue
        label = "/".join(key)
        if key in timeline_rows:
            expected_variants = [{"attack_id": v["attack_id"], "sequence": compact(v["samples"])} for v in timeline_rows[key]["variants"]]
            if row.get("runtime_variants") != expected_variants:
                errors.append(f"review runtime sequence differs from recorded playback: {label}")
        expected = wanted[key]
        for pfield, hfield, expected_path in [("path", "sha256", expected["path"]), ("sprite_frames_path", "sprite_frames_sha256", expected["sprite_frames_path"].removeprefix("res://"))]:
            actual = root / str(row.get(pfield, ""))
            if row.get(pfield) != expected_path or not actual.is_file() or sha(actual) != row.get(hfield):
                errors.append(f"reviewed asset changed: {label}/{pfield}")
        if selection and (row.get("asset_type") != expected["type"] or row.get("reuse_approved_runtime") != expected.get("reuse_approved_runtime", False)):
            errors.append(f"candidate or runtime reuse identity changed: {label}")
        if selection and (row.get("expected_action") != expected["expected_action"] or row.get("action_source") != expected["action_source"]):
            errors.append(f"candidate expected action differs from fixed scope: {label}")
        action_source = root / str(row.get("action_source", ""))
        if not row.get("expected_action") or not action_source.is_file():
            errors.append(f"missing expected action or source: {label}")
        elif sha(action_source) != row.get("action_source_sha256"):
            errors.append(f"expected action source changed: {label}")
        if row.get("status") not in {"pass", "fix", "redo", "blocked"}:
            errors.append(f"invalid status: {label}")
        materials = row.get("materials", {})
        if not materials:
            errors.append(f"missing review materials: {label}")
        if selection and set(materials) != {f"boards/{key[0]}__{key[1]}.jpg", f"sheets/{key[0]}__{key[1]}.png"}:
            errors.append(f"missing candidate frame board or source sheet: {label}")
        for material, digest in materials.items():
            actual = path.parent / material
            if Path(material).is_absolute() or ".." in Path(material).parts or not actual.resolve().is_relative_to(path.parent.resolve()):
                errors.append(f"escaping review evidence path: {label}/{material}")
                continue
            if not actual.is_file() or sha(actual) != digest:
                errors.append(f"review evidence changed: {label}/{material}")
        if row.get("status") != "blocked" and not str(row.get("observations", "")).strip():
            errors.append(f"missing visual observations: {label}")
        if row.get("status") == "pass" and not all(row.get("checks", {}).get(check) is True for check in CHECKS):
            errors.append(f"incomplete visual inspection: {label}")
        if row.get("status") in {"fix", "redo"} and not row.get("issues"):
            errors.append(f"missing actionable issues: {label}")
        for issue in row.get("issues", []):
            if not issue.get("reason") or not issue.get("required_change") or not (issue.get("frames") or issue.get("time_ms")):
                errors.append(f"issue lacks frame/time or correction: {label}")
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    prepare_cmd = commands.add_parser("prepare")
    prepare_cmd.add_argument("--project-root", type=Path, required=True)
    prepare_cmd.add_argument("--timeline", type=Path, required=True)
    prepare_cmd.add_argument("--output", type=Path, required=True)
    validate_cmd = commands.add_parser("validate")
    validate_cmd.add_argument("--project-root", type=Path, required=True)
    validate_cmd.add_argument("--review", type=Path, required=True)
    validate_cmd.add_argument("--require-pass", action="store_true", help="also fail when any semantic review is not pass")
    for command in (prepare_cmd, validate_cmd):
        command.add_argument("--catalog", type=Path, help="pending candidate catalog; requires --scope")
        command.add_argument("--scope", type=Path, help="original explicit candidate motion scope JSON")
        command.add_argument("--scope-sha256", help="optional externally pinned SHA256 of the original scope bytes")
    args = parser.parse_args()
    if args.command == "prepare":
        prepare(args.project_root.resolve(), args.timeline.resolve(), args.output.resolve(), args.catalog.resolve() if args.catalog else None, args.scope.resolve() if args.scope else None, args.scope_sha256)
    else:
        errors = validate(args.project_root.resolve(), args.review.resolve(), args.require_pass, args.catalog.resolve() if args.catalog else None, args.scope.resolve() if args.scope else None, args.scope_sha256)
        for error in errors:
            print(error)
        print("Review decisions:", dict(Counter(row.get("status") for row in read(args.review)["motions"])))
        print(f"MOTION_ACTION_REVIEW: {'FAIL' if errors else 'PASS'} (record integrity only)")
        raise SystemExit(bool(errors))


if __name__ == "__main__":
    main()
