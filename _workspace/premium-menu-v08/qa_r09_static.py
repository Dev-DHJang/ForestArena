"""Independent semantic checks and executable manual plan update. No Penpot access."""
import json,hashlib,datetime
from pathlib import Path
P=Path(__file__).resolve().parent
raw=(P/'scene-spec.json').read_bytes();spec=json.loads(raw);sc={s['name']:s for s in spec['scenes']};sha=hashlib.sha256(raw).hexdigest();errors=[];checks=[]
def check(ok,note):
 checks.append({'check':note,'pass':bool(ok)})
 if not ok:errors.append(note)
def visible(s):
 es=sc[s]['elements'];z=max((i for i,e in enumerate(es)if e['name']=='MODAL / scrim'),default=-1);return es[z+1:]
def controls(s):return [e for e in visible(s)if e['kind']in ['button','hotspot']and e.get('dest')and e.get('state')!='disabled']
def action(s,label):
 a=[e for e in controls(s)if e.get('text')==label or e['name']==label or e['name'].split(' / ',1)[-1]==label]
 if len(a)!=1:raise ValueError((s,label,len(a)))
 return a[0]
def follow(s,label):return action(s,label)['dest']
def values(s):return sc[s].get('settingsState',{}).get('values')
def canonical(s):return hashlib.sha256(json.dumps(s,ensure_ascii=False,sort_keys=True,separators=(',',':')).encode()).hexdigest()
b=json.loads((P/'semantic-fix-baseline.json').read_text())['scenes'];before={x['name']:x['sha256']for x in b};changed=[n for n in before if n in sc and canonical(sc[n])!=before[n]];added=[n for n in sc if n not in before]
check(sha=='62cbef087faf9a3c3a00dc52b001ba3243d2a4f82943e87ee33a43e02fc26ffd','final spec SHA256')
check(len(sc)==263 and len(spec['scenes'])==263,'263 unique scene names')
check(list(sc)[:214]==list(before),'214 baseline names and order preserved')
check(len(changed)==23 and len(added)==49,'23 existing changes +49 additions;191 unchanged')
diff=json.loads((P/'semantic-changed-scenes.json').read_text());check(set(changed)=={x['name']for x in diff['changedExisting']}and set(added)=={x['name']for x in diff['added']},'independent canonical hash diff matches producer diff')
for n,s in sc.items():
 for e in controls(n):
  check(e['dest']in sc or e['dest']in spec['externalDestinations'],n+' / destination / '+e['name'])
  check(min(e['w'],e['h'])>=72,n+' / minimum touch / '+e['name'])
 check(s.get('transitionMs')==200,n+' /200ms')
def sn(tag):return 'MENU08 / EXT_06_GeneralSettings / '+tag
expected=[('소리',{'music':40,'effects':40,'muted':True},{'music':60,'effects':80,'muted':False}),('화면 효과',{'reduce_visual_effects':True},{'reduce_visual_effects':False}),('접근성',{'text_scale':1.15,'haptics_enabled':False},{'text_scale':1.0,'haptics_enabled':True}),('미니맵',{'transparency':50,'marker_style':'dot','show_names':False},{'transparency':30,'marker_style':'face','show_names':True}),('접근성-large',{'text_scale':1.3,'haptics_enabled':False},{'text_scale':1.0,'haptics_enabled':True})]
for tag,new,default in expected:
 dirty=sn(tag if tag.endswith('-large')else tag+'-off');applied=follow(dirty,'적용');saved=follow(applied,'닫기');reset=follow(saved,'기본값 복원');restored=follow(reset,'기본값 복원');discard=follow(restored,'취소');defaultsaved=follow(follow(restored,'적용'),'닫기')
 check(values(applied)==new and values(saved)==new,tag+' applied -> close retains new values')
 check(sc[saved]['settingsState']['stage']=='saved'and not any(e.get('text')=='적용'for e in controls(saved)),tag+' saved clean and Apply disabled')
 check(follow(reset,'취소')==saved,tag+' restore cancel retains saved state')
 check(values(restored)==default and sc[restored]['settingsState']['savedValues']==new,tag+' restored draft values match runtime defaults; previous values retained')
 check(follow(discard,'취소')==restored and follow(discard,'변경 버리기')==saved,tag+' draft cancel/keep/discard contexts')
 check(values(defaultsaved)==default and sc[defaultsaved]['settingsState']['stage']=='saved',tag+' default Apply -> close persists defaults')
# Metadata alone cannot establish the visible labels. Independently check all setting rows.
for n,s in sc.items():
 st=s.get('settingsState')
 if not st:continue
 v=st['values'];cat=st['category'];es=s['elements'];texts=[e['text']for e in es if e['name']=='SETTING / value']
 expectedText=[str(v['music'])+'%',str(v['effects'])+'%']if cat=='소리'else[str(v['transparency'])+'%']if cat=='미니맵'else[]
 check(texts==expectedText,n+' / visible slider values')
 toggle={'소리':('muted',656),'화면 효과':('reduce_visual_effects',368),'접근성':('haptics_enabled',512),'미니맵':('show_names',656)}[cat]
 row=[e for e in es if e['kind']=='button'and e['x']==1568 and e['y']==toggle[1]]
 check(len(row)==1 and row[0]['text']==('켬'if v[toggle[0]]else'끔'),n+' / visible toggle value')
 if cat=='접근성':
  selected=[e['text']for e in es if e['kind']=='button'and e['y']==368 and e.get('state')=='selected']
  check(selected==[{1:'기본',1.15:'크게',1.3:'최대'}[v['text_scale']]],n+' / visible text-scale choice')
for flo,info,reset,fixed in [('MENU08 / ControlsFloatingFromLobby','MENU08 / ControlsParametersFloatingLobby','MENU08 / SettingsResetFloatingLobby','MENU08 / ControlsFromLobby'),('MENU08 / CBT_08_Settings / floating','MENU08 / ControlsParametersFloating','MENU08 / SettingsResetFloating','CBT_08_Settings')]:
 check(follow(flo,'버튼 크기')==info and follow(flo,'버튼 투명도')==info,flo+' size/opacity same-context info')
 check(follow(info,'취소')==flo and follow(info,'확인')==flo,flo+' info cancel/confirm preserves floating')
 check(follow(flo,'기본값 복원')==reset and follow(reset,'취소')==flo and follow(reset,'복원')==fixed,flo+' reset cancel preserves floating; confirm fixed')
nick='MENU08 / NicknameEdit';res=follow(nick,'변경 확인');prof=follow(res,'프로필로')
check(any(e['kind']=='rect'and e['name']=='INPUT / nickname'for e in visible(nick))and any(e['kind']=='text'and e['name']=='INPUT / value'and e['text']=='숲빛 여행자'for e in visible(nick)),'nickname editable text example field exists')
check(any('실제 입력은 앱' in e.get('text','')for e in visible(nick))and any('시안' in e.get('text','')for e in visible(res)),'nickname prototype limitation explicit')
check(any(e['name']=='PROFILE / name'and e.get('text')=='숲빛 여행자'for e in sc[prof]['elements']),'nickname confirm -> result -> changed profile')
# Rebuild all prior routes from current active controls, never preserving obsolete destinations.
plan=json.loads((P/'manual-click-plan.json').read_text());plan['cases']=[c for c in plan['cases']if c['id']not in ['STATE-07','STATE-08']];plan['specSha256']=sha;plan['specScenes']=len(sc);plan['knownFindings']=[{'id':'KNOWN-01','status':'STATIC_FIXED_ACTUAL_NOT_RUN','finding':'한 분류의 적용·복원·취소 값과 이전 저장값 보존 검사 통과'},{'id':'KNOWN-02','status':'STATIC_FIXED_ACTUAL_NOT_RUN','finding':'플로팅 안내/복원 취소의 출발 컨텍스트 보존 검사 통과'},{'id':'FIX-08-01','status':'STATIC_FIXED_ACTUAL_NOT_RUN','finding':'닉네임 입력 예시와 확인 결과·바뀐 프로필 경로 검사 통과'}]
for c in plan['cases']:
 labels=[x['clickLabel']for x in c['steps']]
 if c['id']=='STATE-04':c['note']='40%/40%/켬 적용 뒤 닫아도 값을 유지한다. 복원 취소도 유지한다. 복원 확인은 실제 기본값60%/80%/끔의 미적용 상태이며 적용 뒤 같은 값이 남아야 한다.'
 if c['id']=='STATE-05':
  labels=['설정','조작','플로팅','버튼 크기','취소','버튼 투명도','확인','기본값 복원','취소','기본값 복원','복원','적용','뒤로'];c['note']='안내 취소/확인과 복원 취소는 플로팅을 유지한다. 복원 확인만 고정100%/0%로 돌아간다. 이전 임시 플로팅 재클릭을 제거했다.'
 c['qaClickLabels']=labels
plan['cases'].extend([{'id':'STATE-07','title':'닉네임 입력 예시·변경 결과·프로필 반영','startScene':'SCR_03_Lobby','coverage':['FIX-08-01'],'executionStatus':'NOT_RUN','qaClickLabels':['프로필','닉네임 변경','변경 확인','프로필로','뒤로'],'note':'Penpot에서 키보드 입력을 구현했다고 판단하지 않는다. 편집 가능한 입력 예시 숲빛 여행자와 실제 입력은 앱에서 진행한다는 안내를 확인한다. 확인 뒤 결과와 프로필에 같은 예시 이름이 보여야 한다.'},{'id':'STATE-08','title':'일시정지 출발 플로팅 안내·복원 취소','startScene':'CBT_08_Settings','coverage':['KNOWN-02'],'executionStatus':'NOT_RUN','qaClickLabels':['플로팅','버튼 크기','취소','버튼 투명도','확인','기본값 복원','취소','기본값 복원','복원'],'note':'로비 출발 경로와 별개다. 안내와 복원 취소는 일시정지 출발 플로팅을 유지하고 복원 확인은 CBT_08_Settings 고정 상태로 돌아간다.'}])
def visible_text(n):
 if n not in sc:return ['범위 밖 기존 화면: '+n]
 es=visible(n);wanted=[e.get('text')for e in es if e['kind']=='text'and (e['name'].startswith(('MODAL /','INPUT /','NICKNAME /','SETTING / value','SETTINGS / save state','PROFILE / name','CONTROLS /'))or e.get('size',0)>=48)]
 wanted +=[e['text']+' 선택'for e in es if e['kind']=='button'and e.get('state')=='selected']
 return list(dict.fromkeys(wanted))[:12]or[sc[n]['title']]
for c in plan['cases']:
 n=c['startScene'];steps=[]
 for i,label in enumerate(c.pop('qaClickLabels'),1):
  e=action(n,label);dest=e['dest'];xy=[e['x']+e['w']/2,e['y']+e['h']/2]
  steps.append({'step':i,'fromScene':n,'clickLabel':label,'controlName':e['name'],'center1920':xy,'center1280':[round(v*2/3,3)for v in xy],'centerNormalized':[round(xy[0]/1920,6),round(xy[1]/1080,6)],'expectedArrivalScene':dest,'visibleTextToCheck':visible_text(dest),'executionStatus':'NOT_RUN'})
  n=dest
 c.update(steps=steps,endScene=n,executionStatus='NOT_RUN')
plan['executionRules']=[x for x in plan['executionRules']if not x.startswith('KNOWN 항목')]+['설정은 한 분류의 대표 값 변경·저장·복원 흐름을 검사한다. 여러 분류 저장 조합과 재진입은 유한 시안 한계로 런타임 동작을 대신하지 않는다.','KNOWN 항목은 정적 수정만 확인했다. 실제 저장 PNG와 프로토타입 클릭 후에만 실행 결과를 기록한다.']
(P/'manual-click-plan.json').write_text(json.dumps(plan,ensure_ascii=False,indent=2)+'\n')
lines=['# 메뉴 v08 실제 클릭 수동 검사 경로표','','**실행 계획만 작성했다. 전 항목 NOT_RUN이며 PASS 결과가 아니다.**','',f'기준 scene-spec: `{sha}` · {len(sc)}개 장면 · {len(plan["cases"])}개 경로.','','좌표는 보드 내부 중심이다. 1920 설계/1280 출력 좌표이며 브라우저 절대 좌표가 아니다. 보드 원점과 배율을 맞춘 뒤 각 클릭 후200ms와 도착 문구를 직접 확인한다.','','설정 적용·복원/플로팅 반환/닉네임 입력 표현은 정적 수정만 확인했다. 새 PNG·실제 Penpot 저장·클릭은 아직 확인하지 않았다. 설정은 한 분류 대표 값 흐름이며 분류 간 저장 조합은 유한 시안 한계다.']
for c in plan['cases']:
 lines+=['',f'## {c["id"]} · {c["title"]}','',f'시작: `{c["startScene"]}` · 실행 상태: **NOT_RUN**','',c.get('note',''),'','| 순서 | 클릭 | 중심1920 / 중심1280 | 예상 도착 장면 | 눈으로 확인할 문구 |','| --- | --- | --- | --- | --- |']
 for step in c['steps']:
  fmt=lambda xy:', '.join(str(v)for v in xy)
  text=' / '.join(step['visibleTextToCheck']).replace('\n',' · ').replace('|','/')
  lines.append(f'| {step["step"]} | {step["clickLabel"]} | {fmt(step["center1920"])} / {fmt(step["center1280"])} | `{step["expectedArrivalScene"]}` | {text} |')
(P/'manual-click-plan.md').write_text('\n'.join(lines)+'\n')
report={'checkedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'status':'STATIC_PASS'if not errors else'FIX','specSha256':sha,'scenes':len(sc),'baseline':214,'changedExisting':len(changed),'added':len(added),'unchanged':214-len(changed),'scope':'Independent local spec/hash/representative semantics only; actual Penpot/PNG/click/device NOT_RUN','manualCases':len(plan['cases']),'manualSteps':sum(len(c['steps'])for c in plan['cases']),'checks':checks,'errors':errors}
(P/'qa-r09-static-check.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items()if k!='checks'},ensure_ascii=False));print('checks',len(checks));raise SystemExit(bool(errors))
