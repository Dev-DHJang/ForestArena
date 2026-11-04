from pathlib import Path
import copy,json
P=Path(__file__).resolve().parent;old=json.loads((P.parent/'scene-spec.json').read_text());scenes=[]
def el(k,n,x,y,w,h,**kw):return dict(kind=k,name=n,x=x,y=y,w=w,h=h,**kw)
def t(n,v,x,y,w,size=28,color='text',weight='500',align='left'):return el('text',n,x,y,w,round(size*1.45*len(v.split('\n'))),text=v,size=size,color=color,weight=weight,align=align)
def r(n,x,y,w,h,c='panel',o=1,rad=12):return el('rect',n,x,y,w,h,color=c,opacity=o,radius=rad)
def b(n,v,x,y,w,h,d=None,state='default',size=30):return el('button',n,x,y,w,h,text=v,dest=d,state=state,size=size,icon=None)
def add(s):scenes.append(s);return s
def base(key,title,tab=None):
 e=[el('image','IMG / character-room',0,0,1920,1080,key='character-room',slot='IMG/bg/character-room'),r('ATMOSPHERE',0,0,1920,1080,'bg',.80,0),r('HEADER',0,0,1920,160,'bg',.94,0),r('FOOTER',0,912,1920,168,'bg',.96,0),b('BACK','←',96,48,80,80,'mission-entry','ghost',36),t('TITLE',title,208,48,1120,52,weight='700'),t('HEADER / note','진행 수치는 설계 예시 · 실제 보상 지급 없음',208,112,1120,26,'muted')]
 e[-1]['text']='진행 수치는 설계 예시 · 실제 보상 지급 없음'
 if tab:
  for i,(k,l) in enumerate([('daily','일일'),('weekly','주간'),('attendance','출석')]):e.append(b('TAB / '+k,l,96,224+i*136,232,104,None if tab==k else 'mission-'+k,'selected' if tab==k else 'default',34))
  e.append(b('NAV / achievements','업적',1536,48,288,80,'achievements','default',32))
 return dict(key=key,name='MENU09 / Missions-r01 / '+key,canonical='SCR_21_Mission',title=title,revision='missions-r01',w=1920,h=1080,elements=e)
def row(e,n,title,desc,y,current,target,dest):
 e.extend([r('ROW / '+n,376,y,1448,208,'panel',.96,16),t('ROW / title '+n,title,408,y+24,960,34,weight='600'),t('ROW / desc '+n,desc,408,y+76,960,26,'muted'),r('PROGRESS / track '+n,408,y+144,944,8,'line',1,4),r('PROGRESS / fill '+n,408,y+144,max(8,944*min(current/target,1)),8,'mint',1,4),t('PROGRESS / value '+n,f'{current} / {target}',408,y+164,944,24,'mint'),b('ROW / open '+n,'달성 ✓' if current>=target else '진행 중',1400,y+64,376,96,dest,'selected' if current>=target else 'default',32)])
for k,title,period,rows in [('daily','일일 미션','한국 시간 매일 00:00 갱신',[('daily-play','정상 경기 1회 완료','AI·Solo·Team·LAN의 정상 종료 기록',1,1),('daily-win','정상 경기 1승','승리한 정상 경기만 집계',0,1)]),('weekly','주간 미션','한국 시간 월요일 00:00 갱신',[('weekly-play','정상 경기 5회 완료','이번 주 정상 종료 기록',3,5),('weekly-win','정상 경기 3승','이번 주 승리 기록',1,3)])]:
 s=base('mission-'+k,title,k);e=s['elements'];e.extend([t('PERIOD',period,376,224,1152,30,'gold'),b('RULE / info','집계 안내',1560,208,264,80,'mission-rules','ghost',28),t('SOURCE','기기 기록 · 서버 동기화 상태는 예시',376,288,1448,26,'muted')])
 for i,(id,ttl,dsc,c,total) in enumerate(rows):row(e,id,ttl,dsc,352+i*256,c,total,'mission-rules')
 e.extend([t('FOOTER / rule','연습·Story·포기 경기는 제외해요. 달성 시 별도 보상은 없어요.',376,912,1448,28,'muted'),b('FOOTER / refresh','새로고침',376,960,344,72,'mission-loading','ghost',26),t('FOOTER / example','진행 상태 예시',768,984,1056,24,'muted',align='right')]);add(s)
s=base('mission-attendance','출석','attendance');e=s['elements'];e.extend([t('ATT / period','28칸 배치 예시 · 운영 기간·시작일 미정',376,208,1448,30,'gold'),t('ATT / rule','연속 출석·누적·초기화·보상은 아직 정하지 않았어요.',376,264,1448,26,'muted')])
for n in range(28):
 x=376+n%7*208;y=336+n//7*128;e.extend([b('ATT / day '+str(n+1),str(n+1)+(' ✓' if n<3 else ' · 오늘' if n==3 else ''),x,y,192,104,'attendance-info','selected' if n==3 else 'default',28)])
e.extend([t('ATT / example','✓는 표시 예시이며 실제 출석·보상 수령 기록이 아닙니다.',376,864,1448,26,'muted'),b('ATT / check','오늘 출석 확인 · 시안',376,944,920,88,'attendance-check','primary',32),b('ATT / policy','운영 안내',1328,944,496,88,'attendance-info','default',30)]);add(s)
s=base('achievements','업적');e=s['elements'];e.append(b('NAV / missions','미션',1536,48,288,80,'mission-daily','default',32))
for i,(k,title,sub) in enumerate([('combat','대전','실제 경기 기록과 연결 가능'),('collection','수집','조건·집계·보상 미정'),('skills','기술','조건·집계·보상 미정')]):
 x=96+i*584;e.extend([b('CATEGORY / '+k,title,x,320,560,440,'achievements-'+k,'default',48),t('CATEGORY / note '+k,sub,x,808,560,28,'mint' if k=='combat' else 'muted',align='center')])
e.append(t('FOOTER / note','업적은 누적 기록으로 분류해요. 보상은 별도 결정 대상입니다.',96,960,1728,28,'muted',align='center'));add(s)
for cat,title in [('combat','대전'),('collection','수집'),('skills','기술')]:
 s=base('achievements-'+cat,'업적 · '+title);e=s['elements'];next(x for x in e if x['name']=='BACK')['dest']='achievements'
 for i,(k,l) in enumerate([('combat','대전'),('collection','수집'),('skills','기술')]):e.append(b('CATEGORY / '+k,l,96+i*584,192,560,80,None if k==cat else 'achievements-'+k,'selected' if k==cat else 'default',32))
 if cat=='combat':
  # Same row schema shifted to full-width category content.
  for i,(id,ttl,desc,c,total) in enumerate([('first-play','첫 정상 경기 완료','처음 완료한 정상 경기',1,1),('ten-play','정상 경기 10회 완료','누적 정상 종료 경기 수',4,10),('all-characters','네 캐릭터로 각각 경기 완료','현재 플레이 가능 · 자현·나비 2종',2,4)]):
   y=312+i*192
   e.extend([r('ROW / '+id,96,y,1728,176,'panel',.96,16),t('ROW / title '+id,ttl,128,y+16,1224,30,weight='600'),t('ROW / desc '+id,desc,128,y+60,1224,24,'muted'),r('PROGRESS / track '+id,128,y+112,1224,8,'line',1,4),r('PROGRESS / fill '+id,128,y+112,1224*c/total,8,'mint',1,4),t('PROGRESS / value '+id,f'{c} / {total}',128,y+128,1224,24,'mint'),b('ROW / open '+id,'달성 ✓' if c>=total else '진행 중',1424,y+40,352,96,'achievement-info','selected' if c>=total else 'default',30)])
  e.append(t('FOOTER / note','현재 플레이 가능한 캐릭터는 자현·나비예요. 다른 캐릭터의 지원은 미정입니다.',96,952,1728,26,'muted'))
 else:
  e.extend([r('PENDING / panel',96,336,1728,520,'panel',.96,16),t('PENDING / title',title+' 업적 조건 준비 중',160,408,1600,44,'gold',weight='600'),t('PENDING / body','목록·진행 표시를 위한 설계 영역입니다.\n집계 조건·데이터 출처·기간·보상은 아직 정하지 않았어요.',160,512,1600,32,'muted'),b('PENDING / info','미정 항목 보기',160,704,760,88,'achievement-info','default',30),b('PENDING / disabled','달성 보상 · 미정',952,704,808,88,None,'disabled',30),t('FOOTER / note','현재 보유 목록·기술 입력을 자동으로 새 업적에 집계하지 않습니다.',96,952,1728,26,'muted')])
 add(s)
# Useful state coverage without inventing rewards or writes.
for key,title,body,mode in [('mission-empty','진행 기록이 없어요','정상 경기를 완료하면 진행 내역을 확인할 수 있어요.','empty'),('mission-complete','일일 미션을 모두 달성했어요','달성 표시 예시 · 별도 보상 수령은 없어요.','complete'),('mission-error','기록을 불러오지 못했어요','조회 실패는 기록 없음과 구분해 표시해요.\n실제 저장·동기화 성공으로 표시하지 않습니다.','error')]:
 s=base(key,'일일 미션','daily');e=s['elements'];e.extend([r('STATE / panel',376,320,1448,504,'panel',.96,16),t('STATE / title',title,424,384,1352,42,'gold',weight='600'),t('STATE / body',body,424,488,1352,30,'muted'),b('STATE / action','다시 시도' if mode=='error' else '일일로 돌아가기',424,688,856,88,'mission-daily','primary',32),b('STATE / info','집계 안내',1312,688,464,88,'mission-rules','default',28),t('FOOTER / note','검토용 상태 · 실제 진행 데이터는 변경하지 않습니다.',376,952,1448,26,'muted')]);add(s)
def overlay(key,title,body,blocked=None):
 s=dict(key=key,name='MENU09 / Missions-r01 / '+key,canonical='SCR_21_Mission',title=title,revision='missions-r01',w=1920,h=1080,overlay=True,elements=[r('MODAL / scrim',0,0,1920,1080,'bg',.86,0),r('MODAL / panel',400,248,1120,584,'panel',1,20),t('MODAL / eyebrow','FOREST ARENA · 설계 검토',448,288,1024,24,'gold'),t('MODAL / title',title,448,336,1024,42,weight='700'),t('MODAL / body',body,448,424,1024,30,'muted')]);e=s['elements'];e.append(b('MODAL / close','닫기',448,704,496 if blocked else 1024,80,None,'primary',30));e[-1]['action']='close-overlay'
 if blocked:e.append(b('MODAL / blocked',blocked,976,704,496,80,None,'disabled',28))
 add(s)
overlay('mission-rules','미션 집계 안내','정상 AI·Solo·Team·LAN 기록만 집계해요.\n연습·Story·포기 경기는 제외해요.\n일일은 한국 시간 자정, 주간은 월요일 자정 기준입니다.\n현재 기능은 보상 지급 없이 진행 기록만 표시합니다.')
overlay('attendance-info','출석 운영은 미정이에요','28칸은 배치 예시이며 실제 운영 달력이 아닙니다.\n운영 기간·시작일·연속/누적·초기화 규칙을 정해야 해요.\n보상 종류·수량·수령·중복 처리도 미정입니다.')
overlay('attendance-check','출석 확인 동작 미리보기','확인 화면의 배치와 닫기 동작만 검토해요.\n실제 출석 저장과 보상 지급은 진행하지 않습니다.\n운영 규칙이 정해진 뒤 기능을 연결합니다.','보상 수령 · 미정')
overlay('achievement-info','업적의 연결 범위','대전은 기존 누적 기록 3종과 연결할 수 있어요.\n수집·기술 조건과 보상은 별도 제품 결정이 필요해요.\n현재는 보상 수령 없이 기록만 확인해요.')
overlay('entry-pending','후속 설계 항목','이번 흐름은 미션·출석·업적을 검토합니다.\n다른 메뉴는 기존 승인 영역과 후속 묶음에서 확인해요.')
# Loading is a full state whose dismissal returns to daily, with inactive background.
s=copy.deepcopy(next(s for s in scenes if s['key']=='mission-daily'));s.update(key='mission-loading',name='MENU09 / Missions-r01 / mission-loading',modal=True)
for x in s['elements']:
 if x['kind']=='button':x['dest']=None
s['elements'].extend([r('MODAL / scrim',0,0,1920,1080,'bg',.86,0),r('MODAL / panel',464,336,992,416,'panel',1,20),t('MODAL / title','기록을 불러오는 중',512,392,896,40,weight='600'),t('MODAL / body','로딩 표시 예시 · 진행 데이터는 변경하지 않아요.',512,488,896,28,'muted'),b('MODAL / close','검토 닫기',512,616,896,80,'mission-daily','primary',30)]);add(s)
s=copy.deepcopy(next(s for s in old['scenes'] if s['key']=='lobby'));s.update(key='mission-entry',name='MENU09 / Missions-r01 / mission-entry',revision='missions-r01')
for x in s['elements']:
 if x['kind']=='button':x['dest']='mission-daily' if x['name']=='NAV / 미션' else 'entry-pending'
add(s)
# Native documentation / state launcher.
s=base('mission-handoff','미션·출석·업적 · 검토 안내');e=s['elements'];next(x for x in e if x['name']=='BACK')['dest']='mission-entry'
e.extend([t('GUIDE / title','missions-r01 · 3종 검토 대기',96,208,1728,42,'gold',weight='600'),t('GUIDE / body','참조04 일일/주간 · 참조05 출석 · 참조13 업적\n기존 미션은 보상 없음 · 출석/수집/기술 규칙은 미정\n1920×1080 / 8px / 안전 여백96·48 / 터치72 이상\n실제 Android 확인·게임 개발은 별도입니다.',96,296,1728,32,'muted')])
for i,(k,l) in enumerate([('mission-daily','일일'),('mission-weekly','주간'),('mission-attendance','출석'),('achievements','업적'),('mission-empty','빈 목록'),('mission-complete','모두 달성'),('mission-loading','로딩'),('mission-error','오류')]):e.append(b('GUIDE / '+k,l,96+(i%4)*440,600+(i//4)*128,408,96,k,'primary' if i==0 else 'default',30))
e.append(t('GUIDE / assets','MISSING ASSETS · 새 필수 이미지 없음 / 기존 배경·네이티브 요소 재사용',96,928,1728,28,'muted'));add(s)
for key in ['mission-daily','mission-attendance','achievements']:
 s=copy.deepcopy(next(s for s in scenes if s['key']==key));s.update(key=key+'-wide',name='MENU09 / Missions-r01 / '+key+'-wide',comparison_of=key,w=2400)
 for x in s['elements']:
  if x['name'] in ['IMG / character-room','ATMOSPHERE','HEADER','FOOTER']:x['w']=2400
  else:x['x']+=240
  if x['kind']=='button':x['dest']=None
 add(s)
j=dict(revision='missions-r01',colors=old['colors'],base_keys=['mission-daily','mission-attendance','achievements'],sources=['04.jpeg','05.jpeg','13.jpeg'],missing_assets=[],runtime_approved=False,scenes=scenes)
(P/'scene-spec.json').write_text(json.dumps(j,ensure_ascii=False,indent=2)+'\n');print('scenes',len(scenes))
