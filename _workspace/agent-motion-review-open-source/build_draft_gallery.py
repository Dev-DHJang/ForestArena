"""Rebuild the unapproved draft comparison gallery without touching source images."""
from __future__ import annotations
import hashlib
import html
import json
from pathlib import Path
import re
import struct

BASE = Path(__file__).resolve().parent
DRAFTS = BASE / "drafts"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(path):
    return json.loads(path.read_text())


def build():
    review_path = BASE / "review/motion-review.json"
    review = load(review_path)
    runtime = {(r["character_id"], r["motion"]): r for r in review["motions"]}
    qa = {}
    qa_files = sorted(BASE.glob("qa-drafts-*.json"))
    for path in qa_files:
        records = load(path)
        if not isinstance(records, list):
            records = records.get("motions", [])
        for row in records:
            key = row["character_id"], row["motion"], int(row["revision"])
            qa[key] = {"record": row, "source": path.name, "source_sha256": digest(path)}
    grouped = {}
    for path in sorted(DRAFTS.glob("*/*/r*.png")):
        match = re.fullmatch(r"r(\d+)\.png", path.name)
        if not match:
            continue
        cid, motion = path.parent.parent.name, path.parent.name
        revision = int(match[1])
        key = cid, motion
        source_sha = digest(path)
        q = qa.get((cid, motion, revision))
        record = q["record"] if q else {}
        expected_hash = record.get("source_sha256") or record.get("sourcehash")
        if not expected_hash:
            expected_hash = record.get("input_hashes", {}).get(str(path))
        fresh = bool(q and expected_hash == source_sha)
        overall = record.get("status", "blocked") if fresh else "blocked"
        static = record.get("static_status", record.get("visual_status", record.get("status", "blocked"))) if fresh else "blocked"
        width, height = struct.unpack(">II", path.read_bytes()[16:24])
        grouped.setdefault(key, []).append({
            "revision": revision, "path": str(path.relative_to(DRAFTS)), "sha256": source_sha,
            "width": width, "height": height, "qa_status": overall,
            "static_art_status": static,
            "qa_scope": record.get("review_scope", "검토 기록 없음") if fresh else "일치하는 원본 해시의 QA 기록 없음",
            "observations": record.get("observations", "독립 검토 대기") if fresh else "현재 시안 해시로 독립 검토를 확인하지 못했다.",
            "issues": record.get("issues", []) if fresh else [],
            "correction_status": record.get("correction_status", "") if fresh else "",
            "qa_source": q["source"] if q else None,
            "qa_record_fresh": fresh,
            "design_approved": False, "runtime_applied": False,
        })
    motions = []
    for (cid, motion), proposals in sorted(grouped.items()):
        row = runtime.get((cid, motion))
        if row is None or not row.get("runtime_variants"):
            raise ValueError(f"missing recorded runtime sequence: {cid}/{motion}")
        motions.append({"character_id": cid, "motion": motion,
                        "expected_action": row["expected_action"],
                        "action_source": row["action_source"],
                        "runtime_variants": row["runtime_variants"],
                        "proposals": sorted(proposals, key=lambda p: p["revision"])})
    document = {"schema_version": 1, "scope": "미승인 수정 시안의 비교·검토 자료; runtime 자산 아님",
                "source_review": "../review/motion-review.json", "source_review_sha256": digest(review_path),
                "qa_sources": {p.name: digest(p) for p in qa_files},
                "motion_count": len(motions), "proposal_count": sum(len(m["proposals"]) for m in motions),
                "design_approved": False, "runtime_applied": False, "motions": motions}
    (DRAFTS / "art-proposals.json").write_text(json.dumps(document, ensure_ascii=False, indent=2) + "\n")
    data = json.dumps(document, ensure_ascii=False).replace("<", "\\u003c")
    page = PAGE.replace("__DATA__", data)
    (DRAFTS / "index.html").write_text(page)
    print(f"DRAFT_GALLERY: {len(motions)} motions / {document['proposal_count']} revisions; {DRAFTS / 'index.html'}")


PAGE = r'''<!doctype html><html lang="ko"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>미승인 모션 수정 시안</title>
<style>
*{box-sizing:border-box}body{margin:0;background:#172128;color:#eff4f7;font:15px/1.5 system-ui,sans-serif}header,nav{padding:16px 24px}header{max-width:1080px}h1{font-size:24px;margin:0 0 8px}p{margin:8px 0}.notice{color:#ffdc93}nav{position:sticky;top:0;z-index:3;background:#172128f5;border-block:1px solid #50616d;display:flex;gap:8px;flex-wrap:wrap;align-items:center}button,select,input{font:inherit;padding:6px;border-radius:5px}button{cursor:pointer}main{padding:20px;display:grid;grid-template-columns:repeat(auto-fit,minmax(530px,1fr));gap:18px}article{background:#293840;padding:16px;border-radius:10px}article[hidden]{display:none}h2{font-size:19px;margin:0}.controls{display:flex;flex-wrap:wrap;gap:5px;margin-block:10px}.sides{display:grid;grid-template-columns:1fr 1fr;gap:12px}.sides.single{grid-template-columns:1fr}.slot{min-width:0}.slot canvas{display:block;background:#a3a8ab;width:256px;height:256px;max-width:100%;margin:auto}.slot select{max-width:100%;margin-bottom:8px}.badge{display:inline-block;padding:3px 8px;background:#43515b;border-radius:8px}.fix,.redo{background:#793f43}.pass{background:#245b53}.blocked{background:#5c5334}.meta{color:#c8d1d8;font-size:13px}.observation,.issues{font-size:13px;white-space:pre-wrap;overflow-wrap:anywhere}.sheet{display:block;width:100%;background:#a3a8ab}.time{font-variant-numeric:tabular-nums}.pending{color:#ffdc93}summary{cursor:pointer}a{color:#9bd4ff}@media(max-width:620px){main{display:block;padding:10px}article{margin-bottom:12px}.sides{grid-template-columns:1fr}.slot canvas{width:256px;height:256px}nav,header{padding:12px}}
</style>
<header><h1>미승인 모션 수정 시안</h1><p class="notice">최종 적용 가능 상태: 전체19개 시안 모두 확인 대기(runtime-ready=false). 이 페이지의 PNG는 게임 원본이 아닌 수정 제안입니다. 그림 QA·설계 승인·게임 적용은 각각 별도 상태입니다. 정적 그림 검토가 통과해도 사용자 승인이나 게임 적용을 뜻하지 않습니다. 균등 셀 자르기에서 이웃 프레임 조각이 보인 사례가 있어 정규화·재검사가 필요합니다. <a href="../qa-drafts-final.json">최종 재생 검토와 잔여 문제</a>를 함께 확인하세요.</p><p>4×4 시안에서 프레임을 잘라, 현재 <a href="../review/motion-review.json">검토 기록</a>의 실제 frame·phase·시간 순서로 재생합니다. 적용 전 128×128 셀·2048×128 시트로 준비하고 다시 확인해야 합니다. 비공격 상태의 강제 유지 시험은 실제 경기 상태 수명과 다릅니다.</p><p class="meta">r01·r02 원본은 모두 보존합니다. 같은 모션의 두 시안을 나란히 선택해 비교할 수 있습니다. 기록된 반복이 보강되면 빌더를 다시 실행해 갱신합니다.</p></header>
<nav><label>캐릭터 <select id="character"><option value="">전체</option></select></label><label>검색 <input id="search" type="search"></label><button id="speed">전체 속도 0.25×</button><button id="mirror">전체 좌우 반전</button><button id="small">전체 절반 크기</button><button id="pause">전체 정지/재생</button><span id="count"></span></nav><main id="main"></main>
<script id="data" type="application/json">__DATA__</script><script>
'use strict';
const data=JSON.parse(document.getElementById('data').textContent),players=[];
const main=document.getElementById('main'),character=document.getElementById('character'),search=document.getElementById('search');
function el(tag,text,cls){const n=document.createElement(tag);if(text!==undefined)n.textContent=text;if(cls)n.className=cls;return n}
function labelStatus(v){return {pass:'정적 검토 통과',fix:'수정 필요',redo:'설계 재검토',blocked:'확인 대기'}[v]||'확인 대기'}
for(const cid of [...new Set(data.motions.map(m=>m.character_id))]){const o=el('option',cid);o.value=cid;character.append(o)}
for(const motion of data.motions){
 const article=el('article');article.id=motion.character_id+'__'+motion.motion;article.dataset.character=motion.character_id;article.append(el('h2',motion.character_id+' / '+motion.motion),el('p',motion.expected_action),el('p','설계 승인: 미승인 · 게임 적용: 미적용','pending'));
 const controls=el('div',undefined,'controls'),variant=document.createElement('select');
 motion.runtime_variants.forEach((v,i)=>{const o=el('option',v.attack_id||motion.motion);o.value=i;variant.append(o)});controls.append(variant);
 const slow=el('button','속도 1×'),mirror=el('button','좌우 반전'),small=el('button','절반 크기'),pause=el('button','정지'),compare=el('button','비교 켜기/끄기');controls.append(slow,mirror,small,pause,compare);article.append(controls);
 const time=el('p','','time meta');article.append(time);const sides=el('div',undefined,'sides');article.append(sides);
 const player={article,motion,variant,elapsed:0,speed:1,mirror:false,small:false,paused:false,slots:[]};
 function makeSlot(initial){
  const container=el('section',undefined,'slot'),select=document.createElement('select');
  motion.proposals.forEach((p,i)=>{const o=el('option','r'+String(p.revision).padStart(2,'0'));o.value=i;select.append(o)});select.value=initial;
  const canvas=document.createElement('canvas');canvas.width=canvas.height=256;
  const badge=el('span','','badge'),scope=el('p','','meta'),obs=el('p','','observation'),issues=el('p','','issues'),details=el('details'),summary=el('summary','전체 16프레임 보기'),sheet=el('img',undefined,'sheet'),link=el('a','원본 PNG 열기');link.target='_blank';link.rel='noopener';sheet.alt='미승인 시안의 전체16프레임';details.append(summary,sheet);container.append(select,canvas,badge,scope,obs,issues,details,link);sides.append(container);
  const slot={container,select,canvas,ctx:canvas.getContext('2d'),image:new Image()};
  function choose(){const p=motion.proposals[Number(select.value)];slot.image=new Image();slot.image.src=p.path;sheet.src=p.path;link.href=p.path;badge.textContent=labelStatus(p.static_art_status)+' · 전체 QA '+p.qa_status;badge.className='badge '+p.static_art_status;scope.textContent=p.qa_scope+(p.qa_source?' / '+p.qa_source:'');obs.textContent=p.observations;issues.textContent=p.issues.map(i=>'프레임 '+(i.frames||[]).join(', ')+': '+i.reason+' → '+i.required_change).join('\n');player.elapsed=0}
  select.onchange=choose;choose();player.slots.push(slot);return slot;
 }
 makeSlot(0);const second=makeSlot(motion.proposals.length-1);let compared=motion.proposals.length>1;function updateCompare(){second.container.hidden=!compared;sides.classList.toggle('single',!compared)}updateCompare();compare.onclick=()=>{compared=!compared;updateCompare()};
 variant.onchange=()=>player.elapsed=0;slow.onclick=()=>{player.speed=player.speed===1?.25:1;slow.textContent='속도 '+player.speed+'×'};mirror.onclick=()=>player.mirror=!player.mirror;small.onclick=()=>player.small=!player.small;pause.onclick=()=>{player.paused=!player.paused;pause.textContent=player.paused?'재생':'정지'};
 player.buttons={slow,mirror,small,pause};players.push(player);main.append(article);
}
function filter(){let n=0;for(const p of players){p.article.hidden=Boolean((character.value&&p.motion.character_id!==character.value)||!p.article.id.includes(search.value));if(!p.article.hidden)n++}document.getElementById('count').textContent=n+'개 모션 / 전체 '+data.proposal_count+'개 시안'}character.onchange=search.oninput=filter;filter();
for(const [id,name]of [['speed','slow'],['mirror','mirror'],['small','small'],['pause','pause']])document.getElementById(id).onclick=()=>players.filter(p=>!p.article.hidden).forEach(p=>p.buttons[name].click());
let last=performance.now();function draw(now){const dt=Math.min(now-last,250);last=now;for(const p of players){if(p.article.hidden)continue;if(!p.paused)p.elapsed+=dt*p.speed;const seq=p.motion.runtime_variants[Number(p.variant.value)].sequence,total=seq.reduce((n,s)=>n+s[3],0);let t=p.elapsed%total,i=0;while(i<seq.length-1&&t>=seq[i][3])t-=seq[i++][3];const s=seq[i];timeLabel(p,s,total);for(const slot of p.slots){if(slot.container.hidden)continue;const ctx=slot.ctx,img=slot.image;ctx.clearRect(0,0,256,256);if(!img.complete||!img.naturalWidth)continue;const col=s[0]%4,row=Math.floor(s[0]/4),x0=Math.round(col*img.naturalWidth/4),x1=Math.round((col+1)*img.naturalWidth/4),y0=Math.round(row*img.naturalHeight/4),y1=Math.round((row+1)*img.naturalHeight/4),size=p.small?128:256;ctx.save();ctx.translate(128,128);ctx.scale(p.mirror?-1:1,1);ctx.drawImage(img,x0,y0,x1-x0,y1-y0,-size/2,-size/2,size,size);ctx.restore()}}requestAnimationFrame(draw)}
function timeLabel(p,s,total){p.article.querySelector('.time').textContent='프레임 '+(s[0]+1)+' / '+s[1]+' / '+Math.round(p.elapsed%total)+' ms / 기록 '+Math.round(total)+' ms · '+p.speed+'×'}requestAnimationFrame(draw);
</script></html>'''

if __name__ == "__main__":
    build()
