"""Next approval batch. Never rewrite the approved representative spec/boards."""
from pathlib import Path
import copy,json
P=Path(__file__).resolve().parent
old=json.loads((P.parent/'scene-spec.json').read_text());C=old['colors']
def elem(k,n,x,y,w,h,**kw):return dict(kind=k,name=n,x=x,y=y,w=w,h=h,**kw)
def text(n,v,x,y,w,size=32,color='text',weight='500',align='left'):return elem('text',n,x,y,w,round(size*1.45*len(v.split('\n'))),text=v,size=size,color=color,weight=weight,align=align)
def rect(n,x,y,w,h,color='panel',opacity=1,radius=12):return elem('rect',n,x,y,w,h,color=color,opacity=opacity,radius=radius)
def button(n,v,x,y,w,h,dest=None,state='default',icon=None,size=28):return elem('button',n,x,y,w,h,text=v,dest=dest,state=state,icon=icon,size=size)
def placeholder(n,slot,x,y,w,h):
 return [rect(n,x,y,w,h,'bg',.96,12),text(n+' / slot',slot,x+16,y+h-80,w-32,24,'muted',align='center'),text(n+' / missing','이미지 준비 중',x+16,y+h/2-24,w-32,30,'muted',align='center')]
def copyold(key,new,title=None):
 s=copy.deepcopy(next(s for s in old['scenes'] if s['key']==key));s.update(key=new,name='MENU09 / Collection-r01 / '+new,title=title or s['title'],revision='collection-r01');return s
def route(s,n,dest):
 next(e for e in s['elements'] if e['name']==n)['dest']=dest
scenes=[]
home=copyold('lobby','collection-home')
for e in home['elements']:
 if e['kind']=='button':e['dest']='collection-pending'
route(home,'NAV / 캐릭터','collection-stats');route(home,'NAV / 신기','artifact-all');scenes.append(home)
stats=copyold('character-stats','collection-stats')
for e in stats['elements']:
 if e['kind']=='button' and e.get('dest'):e['dest']='collection-pending'
route(stats,'BACK','collection-home');route(stats,'TAB / 기술','skills-light');route(stats,'TAB / 스토리','story-1');scenes.append(stats)
category=[('light','약공격','약공격 · 4타 연계','공격 버튼을 이어 눌러 연속 공격합니다.'),('heavy','강공격','강공격 · 방향과 모으기','방향을 조합하거나 모아 강하게 공격합니다.'),('jump-light','점프 약','점프 약공격','공중에서 약공격을 사용합니다.'),('jump-heavy','점프 강','점프 강공격','공중에서 강공격을 사용합니다.'),('special','특수','특수 공격 · 방향 조합','중립·좌우·위·아래 입력에 따라 달라집니다.')]
for key,label,title,desc in category:
 s=copyold('character-stats','skills-'+key,'캐릭터 기술 · '+label)
 s['elements']=[e for e in s['elements'] if not e['name'].startswith(('STATS /','STAT /'))]
 for e in s['elements']:
  if e['kind']=='button' and e.get('dest'):e['dest']='collection-pending'
  if e['name']=='TAB / 스탯':e.update(dest='collection-stats',state='default')
  if e['name']=='TAB / 기술':e.update(dest=None,state='selected')
  if e['name']=='TAB / 스토리':e.update(dest='story-1',state='default')
 route(s,'BACK','collection-home')
 s['elements'] += [rect('SKILL / panel',1080,208,744,648,'panel',.94,16),rect('VIDEO / area',1136,232,640,360,'bg',1,12),text('VIDEO / title',title,1160,256,592,30,'gold',weight='600'),button('VIDEO / play','▶',1408,344,88,88,'video-skills-'+key,'ghost',size=36),text('VIDEO / note','기술 영상 준비 중',1160,464,592,28,'muted',align='center'),text('VIDEO / slot','VIDEO/myo-ryung/'+key,1160,536,592,24,'muted',align='center'),text('SKILL / description',desc,1104,616,696,26)]
 for j,(k,l,_,_) in enumerate(category):
  pos=[(1104,688,216),(1336,688,216),(1104,776,336),(1456,776,336),(1568,688,224)][j]
  s['elements'].append(button('SKILL / '+k,l,*pos[:2],pos[2],72,None if k==key else 'skills-'+k,'selected' if k==key else 'default',size=28))
 scenes.append(s)
for idx in [1,2]:
 s=copyold('character-stats','story-'+str(idx),'캐릭터 스토리 · '+str(idx))
 s['elements']=[e for e in s['elements'] if not e['name'].startswith(('STATS /','STAT /'))]
 for e in s['elements']:
  if e['kind']=='button' and e.get('dest'):e['dest']='collection-pending'
  if e['name']=='TAB / 스탯':e.update(dest='collection-stats',state='default')
  if e['name']=='TAB / 기술':e.update(dest='skills-light',state='default')
  if e['name']=='TAB / 스토리':e.update(dest=None,state='selected')
 route(s,'BACK','collection-home')
 body=('묘령은 백평원에서 자신의 사건을\n독립적으로 추적합니다.\n\n실종과 침입 흔적을 좇던 길은\n오래된 기록회 시설로 이어지고,\n기록인장의 단서와 맞닿습니다.' if idx==1 else '자현과 묘령은 서로 다른 목적을\n가진 타지역 인물로 만납니다.\n\n처음부터 동료였던 두 사람은 아닙니다.\n경계와 필요에 따른 협력 속에서\n각자의 조사를 이어 갑니다.')
 s['elements'] += [rect('STORY / panel',1080,208,744,648,'panel',.94,16),text('STORY / title','백평원에서 온 추적자',1120,240,664,36,'gold',weight='700'),text('STORY / eyebrow','묘령 · 백평원 · 세계관 소개',1120,304,664,26,'mint'),text('STORY / body',body,1120,368,664,30),text('STORY / page',f'{idx} / 2',1120,768,240,28,'muted'),button('STORY / turn','다음 →' if idx==1 else '← 이전',1464,752,320,80,'story-'+str(3-idx),'default',size=30)]
 scenes.append(s)

def artifact(key,selected='all',item='armor',equipped=False):
 s=copyold('character-stats',key,'신기 상세')
 s['canonical']='SCR_07_AccessoryDetail';s['elements']=s['elements'][:4] # shared backdrop / header / footer only
 e=s['elements'];e += [button('BACK','←',96,48,80,80,'collection-home','ghost',size=36),text('TITLE','신기',208,48,800,52,weight='700'),text('HEADER / subtitle','나만의 전투 방식을 만들어 보세요',208,112,1100,26,'muted'),text('EXAMPLE','설계용 보유 예시',1456,72,368,28,'gold',align='right')]
 if item:
  name='철갑옷' if item=='armor' else '조약돌 요요';slot='IMG/accessory/iron-armor' if item=='armor' else 'IMG/accessory/pebble-yoyo'
  e += [text('ARTIFACT / name',name,96,208,592,52,weight='700')]
  if item=='armor':e += placeholder('ARTIFACT / image',slot,168,304,416,416)
  else:e += [elem('image','IMG / pebble-yoyo',144,304,464,416,key='pebble-yoyo',slot='IMG/accessory/pebble-yoyo')]
  e += [text('ARTIFACT / kind','방어 신기' if item=='armor' else '공격 신기',696,224,400,28,'mint'),text('ARTIFACT / heading','장착 효과',696,288,400,36,'gold',weight='600'),text('ARTIFACT / effect','무게 +5%\n지상 이동 속도 -5%' if item=='armor' else '요요를 던져 상대를 견제합니다.\n재사용 대기시간 10초',696,352,424,28),text('ARTIFACT / hint','단단하게 버티는 전투에 어울립니다.' if item=='armor' else '사용 가능 · 자현 / 나비',696,464,424,26,'muted'),button('ARTIFACT / equip','장착 중 ✓' if item=='armor' or equipped else '장착하기',696,568,400,96,None if item=='armor' or equipped else 'artifact-equip-confirm','disabled' if item=='armor' or equipped else 'primary',size=32),text('ARTIFACT / loadout','현재 장착 · '+('조약돌 요요' if equipped else '철갑옷'),696,696,400,26,'muted'),rect('VIDEO / area',1168,208,656,368,'bg',1,12),button('VIDEO / play','▶',1456,304,88,88,'video-artifact-yoyo' if item=='yoyo' else 'video-artifact-armor','ghost',size=36),text('VIDEO / note','신기 영상 준비 중',1192,432,608,28,'muted',align='center'),text('VIDEO / slot','VIDEO/accessory/'+('iron-armor' if item=='armor' else 'pebble-yoyo'),1192,504,608,24,'muted',align='center')]
 else:
  e += [text('EMPTY / title','특수 신기가 없습니다',480,280,960,44,weight='700',align='center'),text('EMPTY / body','다른 분류에서 보유한 신기를 살펴보세요.',480,384,960,32,'muted',align='center'),button('EMPTY / reset','전체 보기',704,480,512,96,'artifact-all','primary',size=32)]
 for j,(k,l,d) in enumerate([('all','전체','artifact-all'),('attack','공격','artifact-attack'),('defense','방어','artifact-defense'),('special','특수','artifact-empty')]):e.append(button('FILTER / '+k,l,1168+j*168,624,152,80,None if k==selected else d,'selected' if k==selected else 'default',size=30))
 e += [text('INVENTORY / label','보유 신기' if item else '보유 신기 · 0개',96,784,960,28,'gold')]
 if selected!='special':
  items= [('armor','철갑옷','방어','artifact-all'),('yoyo','조약돌 요요','공격','artifact-attack')]
  for j,(k,n,kind,d) in enumerate(items):
   if selected=='attack' and k!='yoyo' or selected=='defense' and k!='armor':continue
   x=96+(j*440 if selected=='all' else 0)
   e += [button('INVENTORY / '+k,n+(' ✓' if k==item else ''),x,856,416,120,None if k==item else d,'selected' if k==item else 'default',size=32),text('INVENTORY / kind '+k,kind,x+16,992,384,24,'muted')]
 scenes.append(s);return s
artifact('artifact-all');artifact('artifact-defense','defense');artifact('artifact-attack','attack','yoyo');artifact('artifact-equipped','attack','yoyo',True);artifact('artifact-empty','special',None)
def modal(origin,key,title,body,confirm=None):
 s=copy.deepcopy(next(s for s in scenes if s['key']==origin));s.update(key=key,name='MENU09 / Collection-r01 / '+key,title=title,modal=True)
 for e in s['elements']:
  if e['kind']=='button':e['dest']=None
 s['elements'] += [rect('MODAL / scrim',0,0,1920,1080,'bg',.85,0),rect('MODAL / panel',464,304,992,472,'panel',1,20),text('MODAL / eyebrow','FOREST ARENA',512,344,864,24,'gold'),text('MODAL / title',title,512,392,864,44,weight='700'),text('MODAL / body',body,512,472,864,30,'muted')]
 if confirm:s['elements'] += [button('MODAL / cancel','취소',512,648,424,80,origin),button('MODAL / confirm','장착하기',960,648,448,80,confirm,'primary',size=32)]
 else:s['elements'].append(button('MODAL / close','닫기',512,648,896,80,origin,'primary',size=32))
 scenes.append(s)
for k,_,_,_ in category:modal('skills-'+k,'video-skills-'+k,'영상 준비 중','아직 준비된 기술 영상이 없습니다.\n공격 설명과 분류를 먼저 살펴보세요.')
modal('artifact-all','video-artifact-armor','영상 준비 중','아직 준비된 신기 영상이 없습니다.\n장착 효과를 먼저 살펴보세요.')
modal('artifact-attack','video-artifact-yoyo','영상 준비 중','아직 준비된 신기 영상이 없습니다.\n장착 효과를 먼저 살펴보세요.')
modal('artifact-attack','artifact-equip-confirm','조약돌 요요를 장착할까요?','현재 장착한 철갑옷을 조약돌 요요로 교체합니다.\n이 프로토타입에서는 예시 상태만 바뀝니다.','artifact-equipped')
modal('collection-home','collection-pending','다음 설계 묶음','상점·미션·생활 메뉴·대전 준비는 이어서 제작합니다.\n이번에는 캐릭터·신기 화면을 검토합니다.')
# Defense and equipped states need their own modal return paths.
for src,k in [('artifact-defense','armor-defense'),('artifact-equipped','yoyo-equipped')]:
 route(next(s for s in scenes if s['key']==src),'VIDEO / play','video-artifact-'+k)
 modal(src,'video-artifact-'+k,'영상 준비 중','아직 준비된 신기 영상이 없습니다.\n장착 효과를 먼저 살펴보세요.')
# Context-specific pending dialog closes to the exact stats/skill/story source.
for src in ['collection-stats']+['skills-'+x[0] for x in category]+['story-1','story-2']:
 s=next(s for s in scenes if s['key']==src)
 for e in s['elements']:
  if e.get('dest')=='collection-pending':e['dest']=src+'-pending'
 modal(src,src+'-pending','다음 설계 묶음','다른 캐릭터와 AI 연습 연결은 후속으로 검토합니다.\n현재는 묘령의 기술·스토리 탭을 확인할 수 있습니다.')
# Preserve the equipment preview when browsing categories after confirmation.
for source,key in [('artifact-all','artifact-all-yoyo'),('artifact-defense','artifact-defense-yoyo'),('artifact-empty','artifact-empty-yoyo')]:
 s=copy.deepcopy(next(s for s in scenes if s['key']==source));s.update(key=key,name='MENU09 / Collection-r01 / '+key)
 for e in s['elements']:
  if e['name']=='ARTIFACT / equip':e.update(text='장착하기',dest=key+'-confirm',state='primary')
  if e['name']=='ARTIFACT / loadout':e['text']='현재 장착 · 조약돌 요요'
  if e['name']=='INVENTORY / yoyo':e['dest']='artifact-equipped'
  if e['name']=='VIDEO / play':e['dest']=key+'-video'
 scenes.append(s)
 if source!='artifact-empty':
  modal(key,key+'-confirm','철갑옷을 장착할까요?','현재 장착한 조약돌 요요를 철갑옷으로 교체합니다.\n이 프로토타입에서는 예시 상태만 바뀝니다.',source)
  modal(key,key+'-video','영상 준비 중','아직 준비된 신기 영상이 없습니다.\n장착 효과를 먼저 살펴보세요.')
for s in scenes:
 if s.get('modal') or s['key'] not in ['artifact-equipped','artifact-all-yoyo','artifact-defense-yoyo','artifact-empty-yoyo']:continue
 for e in s['elements']:
  if e['name']=='FILTER / all' and e.get('dest'):e['dest']='artifact-all-yoyo'
  if e['name']=='FILTER / attack' and e.get('dest'):e['dest']='artifact-equipped'
  if e['name']=='FILTER / defense' and e.get('dest'):e['dest']='artifact-defense-yoyo'
  if e['name']=='FILTER / special' and e.get('dest'):e['dest']='artifact-empty-yoyo'
  if e['name']=='EMPTY / reset':e['dest']='artifact-all-yoyo'
# Refresh modal underlay copies to match the final filter destinations.
for s in scenes:
 if not s.get('modal'):continue
 close=next(e for e in s['elements'] if e['name'] in ['MODAL / close','MODAL / cancel']);origin=next(b for b in scenes if b['key']==close['dest'])
 tail=s['elements'][len(origin['elements']):];s['elements']=copy.deepcopy(origin['elements'])+tail
 for e in s['elements'][:len(origin['elements'])]:
  if e['kind']=='button':e['dest']=None
# Unavailable media differs from loading and transport failure.
modal('skills-light','video-loading','영상을 불러오는 중','잠시만 기다려 주세요.\n영상 연결이 완료되면 재생됩니다.')
modal('skills-light','video-error','영상을 불러오지 못했습니다','연결 상태를 확인한 뒤 다시 시도해 주세요.')
err=next(s for s in scenes if s['key']=='video-error');err['elements'][-1]=button('MODAL / close','닫기',512,648,424,80,'skills-light','default',size=32);err['elements'].append(button('MODAL / retry','다시 시도',960,648,448,80,'video-loading','primary',size=32))

# 20:9 comparisons preserve content width and safe area.
for src in ['skills-light','story-1','artifact-all']:
 s=copy.deepcopy(next(s for s in scenes if s['key']==src));s.update(key=src+'-wide',name='MENU09 / Collection-r01 / '+src+'-wide',w=2400,comparison_of=src)
 for e in s['elements']:
  if e['name'] in ['IMG / character-room','ATMOSPHERE','HEADER','FOOTER']:e['w']=2400
  else:e['x']+=240
  if e['kind']=='button':e['dest']=None
 scenes.append(s)
guide=dict(key='collection-handoff',name='MENU09 / Collection-r01 / handoff',canonical='MENU09_HANDOFF',title='캐릭터·신기 검토 안내',revision='collection-r01',w=1920,h=1080,elements=[rect('BACKGROUND',0,0,1920,1080,'bg',1,0),text('TITLE','MENU09 · 캐릭터·신기 r01',96,64,1728,48,'gold',weight='700'),text('STATUS','대표 3장 r01 승인 완료 · 이번 묶음은 승인 대기',96,152,1728,30,'mint'),rect('LEFT',96,224,832,624,'panel'),rect('RIGHT',960,224,864,624,'panel'),text('MISSING / title','MISSING ASSETS · 8개',128,256,768,36,'gold',weight='700'),text('MISSING / list','IMG/accessory/iron-armor  ·  1:1\nVIDEO/myo-ryung/light  ·  16:9\nVIDEO/myo-ryung/heavy  ·  16:9\nVIDEO/myo-ryung/jump-light  ·  16:9\nVIDEO/myo-ryung/jump-heavy  ·  16:9\nVIDEO/myo-ryung/special  ·  16:9\nVIDEO/accessory/iron-armor  ·  16:9\nVIDEO/accessory/pebble-yoyo  ·  16:9',128,336,768,28,'muted'),text('HANDOFF / title','설계와 개발 경계',992,256,800,36,'gold',weight='700'),text('HANDOFF / body','묘령 기술 · 스토리 / 신기 상세 검토\n기존 대표 3장 원본과 연결은 보존\n신규 로비·스탯 복제본은 진입 시연용\n\n철갑옷: 설계용 예시 · 현재 게임 비활성\n요요: 기존 승인 이미지 · 자현/나비 적용\n이 장착 시연은 묘령 전투 규칙을 바꾸지 않음\n\n영상 미수록 / 로딩 / 연결 오류는 별도 상태\n가격·경제·온라인·실제 개발 승인과 구분',992,336,800,28),button('GUIDE / skills','기술 화면',96,920,416,112,'skills-light','primary',size=32),button('GUIDE / artifact','신기 화면',536,920,416,112,'artifact-all',size=32),button('GUIDE / loading','영상 로딩 상태',976,920,408,112,'video-loading',size=30),button('GUIDE / error','영상 오류 상태',1408,920,416,112,'video-error',size=30)])
scenes.append(guide)
for s in scenes:
 for e in s['elements']:
  if e['name']=='IMG / myo-ryung':e['name']+=' hero' if e['y']<880 else ' roster'
spec=dict(version=1,approval_batch='collection-r01',base_keys=['skills-light','story-1','artifact-all'],colors=C,scenes=scenes)
(P/'scene-spec.json').write_text(json.dumps(spec,ensure_ascii=False,indent=2)+'\n');print(len(scenes),'boards')
