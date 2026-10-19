"""Review-only sequence proposals. Reads approved art, never writes runtime files."""
from pathlib import Path
import copy
import hashlib
import html
import json

BASE = Path(__file__).resolve().parent
review = json.loads((BASE / "review/motion-review.json").read_text())
by_key = {(r["character_id"], r["motion"]): r for r in review["motions"]}
proposals = []


def expand(sequence):
    return [(frame, phase, shown, 1000 / 60) for frame, phase, shown, duration in sequence for _ in range(round(duration * 60 / 1000))]


def compress(samples):
    result = []
    for frame, phase, shown, duration in samples:
        if result and result[-1][:3] == [frame, phase, shown]: result[-1][3] += duration
        else: result.append([frame, phase, shown, duration])
    return result


def phase_remap(sequence, mapping):
    samples = expand(sequence)
    for phase, frames in mapping.items():
        indices = [i for i, s in enumerate(samples) if s[1] == phase]
        for j, i in enumerate(indices):
            frame, p, shown, duration = samples[i]
            samples[i] = (frames[round(j / max(len(indices) - 1, 1) * (len(frames) - 1))] - 1, p, shown, duration)
    return compress(samples)


def propose(cid, motion, description, transform, only_state=False):
    row = by_key[cid, motion]
    variants = []
    for variant in row["runtime_variants"]:
        if only_state and not variant["attack_id"].startswith("state:"): continue
        sequence = transform(copy.deepcopy(variant["sequence"]))
        assert abs(sum(s[3] for s in sequence) - sum(s[3] for s in variant["sequence"])) < .01
        variants.append({"context": variant["attack_id"], "sheet": f"../review/sheets/{cid}__{motion}.png", "sequence": sequence})
    proposals.append({"character_id": cid, "motion": motion, "description": description, "source_sha256": row["sha256"], "approval": "not-approved", "status": "review-pending", "variants": variants})


for cid in ("ja-hyun", "myo-ryung", "nabi", "yu-ran"):
    propose(cid, "jump", "하강에서 착지 압축13을 제외하고12를 유지. 지상 착지14~16과 모든 시간은 그대로.", lambda seq: [[11 if f == 12 and p == "descent" else f, p, shown, ms] for f, p, shown, ms in seq])

for cid, hold in [("myo-ryung", 7), ("nabi", 6)]:
    propose(cid, "guard", f"비공격 방어의 끝 자세를{hold}에 유지. 사용자 승인 뒤 state_hold_frame 적용 후보.", lambda seq, hold=hold: [[min(f, hold - 1), p, shown, ms] for f, p, shown, ms in seq])

propose("myo-ryung", "attack_light_combo_01", "준비는1, 적중은2~5의 손 뻗기, 회복은6~16에 대응. 공격 tick은 그대로.", lambda seq: phase_remap(seq, {"startup": [1], "active": [2, 3, 4, 5], "recovery": list(range(6, 17))}))
propose("yu-ran", "attack_light_combo_03", "활성 전체에 펼친 꼬리7~10, 회복에11~16을 대응. 공격 tick은 그대로.", lambda seq: phase_remap(seq, {"active": [7, 8, 9, 10], "recovery": list(range(11, 17))}))
propose("yu-ran", "special_down", "활성 전체에 낮은 꼬리 쓸기6~8, 회복에9~16 대응. 공격 tick은 그대로.", lambda seq: phase_remap(seq, {"active": [6, 7, 8], "recovery": list(range(9, 17))}))

for cid, hold in [("ja-hyun", 16), ("myo-ryung", 4), ("nabi", 5), ("yu-ran", 7)]:
    propose(cid, "attack_heavy_charge", f"준비는 현 차지{hold} 유지, 해제는 방향별 기존 강공격 원화를 선택하는 맥락 분리 제안. 아직 게임에 적용하지 않음.", lambda seq, hold=hold: [[min(f, hold - 1), p, shown, ms] for f, p, shown, ms in seq], only_state=True)
    row = by_key[cid, "attack_heavy_charge"]
    for variant in row["runtime_variants"]:
        if variant["attack_id"].startswith("state:"): continue
        direction = next(d for d in ["side", "up", "down"] if f"heavy-{d}#" in variant["attack_id"])
        target = by_key[cid, "attack_heavy_" + direction]
        mapping = {}
        for f, p, shown, ms in target["runtime_variants"][0]["sequence"]:
            if f + 1 not in mapping.setdefault(p, []): mapping[p].append(f + 1)
        seq = phase_remap(variant["sequence"], mapping)
        proposals[-1]["variants"].append({"context": variant["attack_id"], "sheet": f"../review/sheets/{cid}__attack_heavy_{direction}.png", "sheet_sha256": target["sha256"], "sequence": seq})
    if cid == "yu-ran": proposals[-1]["limitation"] = "위 강공격 원화의 꼬리 대신 무릎 문제는 별도 이미지 시안으로 다룸. 이 재생 분리만으로 해당 원화 문제를 해결했다고 보지 않음."

destination = BASE / "drafts"
destination.mkdir(exist_ok=True)
(destination / "sequence-proposals.json").write_text(json.dumps({"schema_version": 1, "proposals": proposals}, ensure_ascii=False, indent=2) + "\n")
cards = []
for row in proposals:
    options = "".join(f'<option value="{i}">{html.escape(v["context"])}</option>' for i, v in enumerate(row["variants"]))
    cards.append(f'<article><h2>{row["character_id"]}/{row["motion"]}</h2><p>{html.escape(row["description"])}</p><p>{html.escape(row.get("limitation", ""))}</p><canvas width="256" height="256"></canvas><br><select>{options}</select><p class="phase"></p><script type="application/json">{json.dumps(row["variants"])}</script></article>')
page = '''<!doctype html><meta charset="utf-8"><title>재생 수정 시안</title><style>body{background:#172128;color:#eef3f7;font:14px system-ui}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(290px,1fr));gap:12px}article{background:#293840;padding:12px}h2{font-size:16px}canvas{background:#94999e}button,select{padding:7px;max-width:100%}nav{position:sticky;top:0;background:#172128;padding:10px}</style>
<h1>기존 승인 원화의 재생 수정 시안13종</h1><p>사용자 미승인 제안. 게임·manifest·전투 데이터는 변경하지 않았습니다. 시간은 원본 게임 기록과 같고 표시 프레임 또는 사용하는 원화만 제안한 것입니다.</p><nav><button id="speed">속도1×</button><button id="mirror">좌우 반전</button><button id="size">작게</button></nav><main>''' + "".join(cards) + '''</main><script>
let speed=1,mirror=false,small=false;document.querySelector('#speed').onclick=()=>{speed=speed===1?.25:1;document.querySelector('#speed').textContent='속도'+speed+'×'};document.querySelector('#mirror').onclick=()=>mirror=!mirror;document.querySelector('#size').onclick=()=>small=!small;
for(const a of document.querySelectorAll('article')){const variants=JSON.parse(a.querySelector('script').textContent),canvas=a.querySelector('canvas'),ctx=canvas.getContext('2d'),select=a.querySelector('select');const images=variants.map(v=>{let i=new Image();i.src=v.sheet;return i});let elapsed=0,last=performance.now();select.onchange=()=>elapsed=0;function frame(now){elapsed+=(now-last)*speed;last=now;const n=Number(select.value),seq=variants[n].sequence,total=seq.reduce((t,s)=>t+s[3],0);let at=elapsed%total,j=0;while(j<seq.length-1&&at>=seq[j][3])at-=seq[j++][3];const s=seq[j],size=small?128:256;ctx.clearRect(0,0,256,256);ctx.save();ctx.translate(128,128);ctx.scale(mirror?-1:1,1);if(images[n].complete)ctx.drawImage(images[n],s[0]*128,0,128,128,-size/2,-size/2,size,size);ctx.restore();a.querySelector('.phase').textContent='frame '+(s[0]+1)+' / '+s[1]+' / '+Math.round(elapsed%total)+'ms';requestAnimationFrame(frame)}requestAnimationFrame(frame)}
</script>'''
(destination / "sequence-proposals.html").write_text(page)
print(f"prepared {len(proposals)} proposals; runtime files unchanged")
