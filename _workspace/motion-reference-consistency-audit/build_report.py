"""기록된 직접 관찰을 사용자 검토 목록으로 묶는다. 시각 판정은 만들지 않는다."""
import csv,hashlib,html,json
from collections import Counter
from pathlib import Path
P=Path(__file__).resolve().parent
ROOT=P.parents[1]
def read(name):return json.loads((P/name).read_text())
def write(name,data):(P/name).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
coverage=read('coverage.json');media=read('playback-index.json')
primary=read('review-ja-nabi.json');qa=read('qa-myo-yu.json')
if qa['reviewed_motion_count']!=61:raise ValueError('incomplete independent observations')
observations={(r['character_id'],r['motion_id']):r for r in primary['motions']+qa['motions']}
if len(observations)!=122:raise ValueError('need all 122 observations')
labels={'ja-hyun':'자현','myo-ryung':'묘령','nabi':'나비','yu-ran':'유란'}
categories={'appearance':'외형·장착물','proportion':'몸 비율','size':'표시 크기','palette-and-shading':'색감·명암'}
confidence_labels={'confirmed':'차이 확인','suspected':'추가 비교 후보'}
severity_labels={'major':'큼','moderate':'중간','minor':'작음'}
rows=[];issues=[];seen_shared=set()
for source in coverage['motions']:
    row=source.copy();manual=observations[row['character_id'],row['motion_id']]
    row['reviewed_frames']=manual['reviewed_frames'];row['reviewer']=manual.get('reviewer', 'reference_qa' if row['character_id'] in ['myo-ryung','yu-ran'] else primary['reviewer'])
    row['uncertainties']=manual.get('uncertainties',[]);row['excluded_natural_changes']=manual.get('excluded_natural_changes',manual.get('exclusions',''))
    notes=[]
    for n,original in enumerate(manual['observations']):
        note=original.copy()
        if note.pop('frame_notation',None)=='inclusive-range':note['frames']=list(range(note['frames'][0],note['frames'][1]+1))
        note['severity']={'low':'minor','medium':'moderate','high':'major'}.get(note['severity'],note['severity'])
        note['confidence']='confirmed' if note['confidence']=='confirmed' else 'suspected'
        note.setdefault('proposed_followup','색감 기준 검토: 조명·명암 표현과 목표 색조를 먼저 결정한 뒤 공통 조정/원화 재작업 여부 선택' if note['category']=='palette-and-shading' else '추가 대조: 대표 모델의 팔다리 길이와 포즈 원근을 겹쳐 비교하고 재작업 여부 선택')
        note['followup_type']='further-inspection' if note['confidence']=='suspected' else ('artwork' if note['category'] in ['appearance','proportion'] else 'display-or-artwork')
        note['finding_id']=note.get('shared_finding_id',f'{row["character_id"]}/{row["motion_id"]}/{n+1}')
        times=[]
        for v in row['variants']:
            hit={str(f):v['frame_times_seconds'][str(f)] for f in note['frames'] if str(f) in v['frame_times_seconds']}
            if hit:times.append({'variant':v['attack_id'],'frame_first_last_seconds':hit,'envelope_seconds':[min(t[0] for t in hit.values()),max(t[1] for t in hit.values())]})
        note['timeline_times']=times;note['unshown_frames']=[f for f in note['frames'] if f in row['unshown_authored_frames']]
        notes.append(note)
        if note['finding_id'] not in seen_shared:
            issue={'finding_id':note['finding_id'],'character_id':row['character_id'],'motion_id':row['motion_id'],'category':note['category'],'severity':note['severity'],'confidence':note['confidence'],'observation':note['observation'],'affected_motion_ids':[row['motion_id']]}
            if note.get('shared_finding_id'):issue['affected_motion_ids']=[r['motion_id'] for r in qa['motions'] if any(x.get('shared_finding_id')==note['finding_id'] for x in r['observations'])]
            issues.append(issue);seen_shared.add(note['finding_id'])
    row['observations']=notes
    row['classification']='difference-observed' if any(n['confidence']=='confirmed' for n in notes) else ('judgment-deferred' if notes else 'no-difference-observed')
    row['playback']='playback/'+row['character_id']+'--'+row['motion_id']+'.mp4'
    row['runtime_board']='runtime-boards/'+row['character_id']+'--'+row['motion_id']+'.jpg'
    rows.append(row)
counts=Counter(r['classification'] for r in rows)
summary={'motion_count':len(rows),'authored_frame_count':sum(r['frame_count'] for r in rows),'candidate_motion_count':sum(bool(r['observations']) for r in rows),'unique_finding_count':len(issues),'classifications':dict(counts),'per_character':{cid:{'motions':sum(r['character_id']==cid for r in rows),'candidate_motions':sum(r['character_id']==cid and bool(r['observations']) for r in rows),'frames':sum(r['frame_count'] for r in rows if r['character_id']==cid)} for cid in labels}}
artifacts={str(p.relative_to(P)):sha(p) for folder in ['boards','runtime-boards','playback','evidence','overview','comparisons'] for p in (P/folder).glob('*') if p.is_file()}
review={'schema_version':1,'audit_type':'appearance-consistency','basis':'approved v01 four-view references and character-appearance-v01; baseline 4221f6cc6bee607aa6f7d2f30d1d0b2230126def','status':'user-review-list','rework_approved':False,'action_quality_approval':False,'android_pass':False,'summary':summary,'method_limits':['All authored frames reviewed as ordered storyboards. Actual presentation transforms sampled at 60 Hz; effect renderer replay at 30 FPS. Normal/0.25-speed viewer provided; no blanket perceptual motion-action-quality pass.','References shown at fixed 1/8 only for comparison; not a new target game scale.','Asterisk means an authored drawing not chosen in recorded runtime samples; static display position estimated.','Frame-time envelopes record first to last appearances, possibly with gaps/repeats; video times include 0.5 second idle prefix.','Small color differences are shared style candidates; no automatic requirement to remake every affected motion.'],'findings':issues,'motions':rows,'evidence_sha256':artifacts}
write('motion-review.json',review)
# Keep full coverage classifications in sync; original metrics and hashes remain.
coverage['motions']=rows;coverage['summary']=summary;write('coverage.json',coverage)
with (P/'review-list.csv').open('w',encoding='utf-8-sig',newline='') as f:
    fields=['검토ID','캐릭터','모션ID','분류','정도','확신','프레임','게임타임라인초','관찰','다음검토','원화보드','재생영상'];w=csv.DictWriter(f,fieldnames=fields);w.writeheader()
    for r in rows:
        for note in r['observations']:
            times='; '.join(t['variant']+':'+f'{t["envelope_seconds"][0]:.3f}~{t["envelope_seconds"][1]:.3f}' for t in note['timeline_times']) or '기록된 재생에서 미선택; 원화 확인'
            w.writerow(dict(zip(fields,[note['finding_id'],labels[r['character_id']],r['motion_id'],categories[note['category']],severity_labels[note['severity']],confidence_labels[note['confidence']],','.join(map(str,note['frames'])),times,note['observation'],note['proposed_followup'],r['board'],r['playback']])))
lines=['# 모션 외형 차이 검토 목록','','2026-10-29 등록본을 승인 대표 v01과 비교했다. **재작업은 아직 적용하지 않았다.**','',f'전체 **122모션 / 2,000프레임**을 직접 비교했다. 검토 목록에 든 **{summary["candidate_motion_count"]}개 모션**에는 공통 색감 후보의 영향 범위도 포함된다. 독립된 관찰은 **{len(issues)}건**이며, 개별 중대 결함 개수와 같지 않다.','', '| 캐릭터 | 확인 모션 | 목록에 든 모션 | 원화 프레임 |','| --- | ---: | ---: | ---: |']
for cid,stat in summary['per_character'].items():lines.append(f'| {labels[cid]} | {stat["motions"]} | {stat["candidate_motions"]} | {stat["frames"]} |')
lines+=['','먼저 볼 차이는 자현 `attack_heavy_charge`의 투명하게 빠진 몸통·하의다. 크기·비율 후보는 대기 전후와 다시 대조하고, 공통 색감 후보는 목표 색조 선택부터 하는 편이 좋다.','', '[전체 비교·정상/느린 재생](index.html) · [CSV](review-list.csv) · [전체 122개 판정 JSON](motion-review.json) · [독립 관찰](qa-myo-yu.json)','', '## 읽는 방법','','- **차이 확인**은 눈에 보이는 차이를 뜻하며 재작업 승인이 아니다. **추가 비교 후보**는 작은 차이 또는 포즈·원근·해상도 영향이 남는 항목이다.','- 프레임은 1부터 센다. 보드 상단은 승인4각도를 고정1/8로 표시하며 목표 게임 크기를 새로 정하지 않는다. RAW는 원화, DISPLAY는 실제 관측 배율·몸 기준점 적용이다. `*`는 타임라인에서 미선택된 원화로, 표시 위치는 추정이다.','- 영상은 실제 표시 변환과 목도리·손톱 효과 코드를 고정 검사 화면에서 재생한다. 60Hz 기록의2틱마다30FPS이며 앞뒤 대기 각0.5초, 좌우 반전과 원래 크기를 포함한다. 실제 경기·Android 결과나 모든 행위 표현의 통과 판정은 아니다.','- CSV/JSON 시간은 각 타임라인 변형에서 최초~최종 노출 구간이다. 반복·건너뛴 구간이 포함될 수 있다. 영상에서는 앞에0.5초가 더해지며 모든 변형을 순서대로 이어 붙인다.','- 웅크림·회전·원근·가려짐·귀/꼬리/천의 자연 움직임과 표정은 별도로 구분했다. 작은 눈·장식처럼 확정하지 못한 세부는 동일하다고 보증하지 않는다.','','## 공통 색감 후보','','묘령31개, 유란30개의 색감은 각각 한 건의 공통 관찰이다. 아래 개별 목록에도 영향 범위를 표시했으며 CSV에는 모션별 행이 있다. 색조·명암의 목표를 먼저 검토하고, 전 모션 재제작을 자동 결정하지 않는다.','']
for issue in issues:
    if issue['finding_id'] in ['MYO-COLOR-01','YU-COLOR-01']:lines += [f'- **{labels[issue["character_id"]]} {len(issue["affected_motion_ids"])}모션**: {issue["observation"]}']
for issue in issues:
    if issue['finding_id'] in ['MYO-COLOR-01','YU-COLOR-01']:
        lines += ['', f'**{labels[issue["character_id"]]} 영향 모션 전체**: '+', '.join(f'[`{mid}`](boards/{issue["character_id"]}--{mid}.jpg)' for mid in issue['affected_motion_ids'])]
lines += ['','## 모션별 개별 후보','','| 캐릭터·모션 | 차이 / 정도 / 확신 | 문제 프레임 | 관찰·다음 검토 | 근거 |','| --- | --- | --- | --- | --- |']
rank={'major':0,'moderate':1,'minor':2}
individual=[(r,n) for r in rows for n in r['observations'] if not n.get('shared_finding_id')]
individual.sort(key=lambda pair:(pair[1]['confidence']!='confirmed',rank[pair[1]['severity']],pair[0]['character_id'],pair[0]['motion_id']))
for r,note in individual:
        frames=note['frames'];span=f'F{frames[0]}~{frames[-1]}' if frames==list(range(frames[0],frames[-1]+1)) else ','.join(f'F{f}' for f in frames)
        text=note['observation']+' '+note['proposed_followup']
        lines.append(f'| {labels[r["character_id"]]} `{r["motion_id"]}` | {categories[note["category"]]} / {severity_labels[note["severity"]]} / {confidence_labels[note["confidence"]]} | {span} | {text} | [고정 비교](comparisons/{note["finding_id"].replace("/","--")}.jpg) · [전체 프레임]({r["board"]}) · [재생]({r["playback"]}) |')
lines+=['','## 목록에 들지 않은 모션','','이번 전체 프레임 비교에서 뚜렷한 차이를 관찰하지 못했다는 뜻이다. 보이지 않는 세부나 다른 카메라·실기기 환경까지 통과했다는 뜻은 아니다.','']
for cid in labels:
    normal=[r for r in rows if r['character_id']==cid and not r['observations']]
    if normal:lines.append(f'- **{labels[cid]}**: '+', '.join('`'+r['motion_id']+'`' for r in normal))
lines+=['','## 등록·재생 확인 메모','','나비18개의 과거 `unapproved-workspace-only` 상태 필드는 현재 런타임 소비와 별도로 기록했다. PR112 승인 기록의 PNG 해시와 일치하므로 해당 문자열만으로 미승인 모션이라 판정하지 않았다. 원래 상태 필드는 변경하지 않았다.','', '유란 `attack_light_combo_03`은 active 단계 그림 수가 표시 틱 수보다 많다는 기존 타임라인 경고가 있다. 이번 외형 검토는 원화16장 전체를 포함하며, 건너뛴 그림은 `*`와 JSON에 기록했다. 타이밍 재작업은 이 목록의 외형 차이와 별도다.','', '검증과 재현 방법은 [작업 종료 기록](04_closeout.md)에 남긴다.']
(P/'review-list.md').write_text('\n'.join(lines)+'\n')
# Add finding text/filtering to the media page without changing render evidence.
page=(P/'index.html').read_text();prefix='<nav style="position:sticky;top:0;background:#192430;padding:12px;z-index:2"><label>검색 <input id="search" placeholder="캐릭터·모션·차이"></label> <label><input id="only" type="checkbox" checked> 검토 후보만</label> <span id="count"></span></nav>'
# Page is generated by package tool. Remove previous injected report UI on repeat.
if '<!-- audit-review-ui -->' in page:page=page.split('<!-- audit-review-ui -->')[0]+'</html>'
page=page.removesuffix('</html>').rstrip()
page += '<!-- audit-review-ui -->'+prefix
lookup={r['character_id']+'--'+r['motion_id']:{'candidate':bool(r['observations']),'text':labels[r['character_id']]+' '+r['motion_id']+' '+' '.join(categories[n['category']]+' '+n['observation'] for n in r['observations']),'html':'<p>'+html.escape(' / '.join(n['observation'] for n in r['observations']) or '이번 비교에서 뚜렷한 차이를 관찰하지 못함')+'</p>'} for r in rows}
page += '<script>const audit='+json.dumps(lookup,ensure_ascii=False).replace('</','<\\/')+';const nav=document.querySelector("nav");document.body.prepend(nav);for(const el of document.querySelectorAll("article")){el.querySelector("h2").insertAdjacentHTML("afterend",audit[el.id].html)}function filter(){let n=0;for(const el of document.querySelectorAll("article")){let r=audit[el.id];el.hidden=(document.querySelector("#only").checked&&!r.candidate)||!r.text.toLowerCase().includes(document.querySelector("#search").value.toLowerCase());if(!el.hidden)n++}document.querySelector("#count").textContent=n+" / 122"}document.querySelector("#search").oninput=filter;document.querySelector("#only").onchange=filter;filter();</script></html>'
(P/'index.html').write_text(page)
print(json.dumps(summary,ensure_ascii=False))
