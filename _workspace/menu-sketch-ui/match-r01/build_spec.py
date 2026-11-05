from pathlib import Path
import json,copy,math
P=Path(__file__).resolve().parent
C=dict(bg='#10181C',panel='#1C282C',text='#F2F3ED',muted='#BBC6C6',gold='#D9C58E',mint='#8CBFB2',line='#455455')
scenes=[]
def text(n,t,x,y,w,size=30,color='text',weight='500',align='left'):
 return dict(kind='text',name=n,text=t,x=x,y=y,w=w,h=math.ceil(size*1.45*(t.count('\n')+1)),size=size,color=color,weight=weight,align=align)
def rect(n,x,y,w,h,c='panel',o=.96,r=12):return dict(kind='rect',name=n,x=x,y=y,w=w,h=h,color=c,opacity=o,radius=r)
def button(n,t,x,y,w,h,d=None,state='default',size=30,action=None):return dict(kind='button',name=n,text=t,x=x,y=y,w=w,h=h,dest=d,state=state,size=size,icon=None,**({'action':action} if action else {}))
def image(k,x,y,w,h,slot):return dict(kind='image',name='IMG / '+k,key=k,x=x,y=y,w=w,h=h,slot=slot)
def base(k,title,canonical='EXT_MENU09_Match',back='match-entry',note='대전 준비 시안 · 실제 방 생성·참가·매칭을 실행하지 않아요'):
 s=dict(key=k,name='MENU09 / Match-r01 / '+k,title=title,canonical=canonical,revision='match-r01',w=1920,h=1080,elements=[image('character-room',0,0,1920,1080,'IMG/bg/character-room'),rect('ATMOSPHERE',0,0,1920,1080,'bg',.70,0),rect('HEADER',0,0,1920,160,'bg',.85,0),rect('FOOTER',0,880,1920,200,'bg',.95,0),button('BACK','←',96,48,80,80,back,'ghost',36),text('TITLE',title,208,48,1400,52,'text','700'),text('HEADER / subtitle',note,208,112,1500,26,'muted')]);scenes.append(s);return s
s=base('mode-select','일반대전','SCR_09_ModeSelect');e=s['elements']
for i,(k,t,d,desc) in enumerate([('ai','AI','ai-room','AI와 대전을 준비해요.\n승인된 대전방 구성을 재사용해요.'),('auto','자동 매칭','normal-match-info','매칭 조건과 온라인 운영은 미정이에요.\n현재 시안에서는 상대를 찾지 않아요.'),('lobby','로비','rooms','방 목록과 전체 초대 코드를 확인해요.\n개인전·팀전 방 구성을 살펴봐요.')]):
 x=96+i*584;e +=[button('MODE / '+k,t,x,264,560,424,d,'primary' if i==0 else 'default',48),text('MODE / description '+k,desc,x+24,728,512,28,'muted')]
e +=[text('MODE / scope','일반대전: 개인전·팀전 / AI: AI 대전 · 스토리와 연습은 기존 메뉴에서 진입',96,944,1728,28,'muted')]
# Room list with selection, full-room blocking and mode filters.
room_data=[('숲의 대기방','개인전','2 / 8','대기 중'),('가득 찬 방','개인전','8 / 8','가득 참'),('함께하는 숲','팀전','2 / 8','대기 중')]
def rooms(k='rooms',selected=None,filter='all',empty=False):
 s=base(k,'일반대전 · 방 목록','SCR_10_PartyLobby',back='mode-select',note='목록·인원은 설계 예시 · 현재 실제 LAN은 1:1 / 이 화면은 장래 최대 8인 배치');e=s['elements']
 for i,(f,t,d) in enumerate([('all','전체','rooms'),('solo','개인전','rooms-solo'),('team','팀전','rooms-team')]):e.append(button('FILTER / '+f,t,96+i*272,200,248,80,None if filter==f else d,'selected' if filter==f else 'default'))
 e +=[text('TABLE / title','제목 · 대전 방식',120,320,736,28,'muted'),text('TABLE / count','인원',880,320,176,28,'muted'),text('TABLE / state','상태',1072,320,200,28,'muted')]
 ids=[] if empty else [2] if filter=='team' else [0,1] if filter=='solo' else [0,1,2]
 for row,i in enumerate(ids):
  title,mode,count,status=room_data[i];y=384+row*136;dest=('rooms-solo-full' if i==1 else 'rooms-solo-selected') if filter=='solo' else 'rooms-full-selected' if i==1 else 'rooms-team-selected' if i==2 else 'rooms-selected';sel=selected==i
  e +=[button('ROOM ROW / '+str(i),title+' · '+mode,96,y,728,112,dest,'selected' if sel else 'default'),text('ROOM COUNT / '+str(i),count,872,y+32,176,30),text('ROOM STATE / '+str(i),status,1072,y+32,208,28,'muted')]
 if empty:e +=[rect('EMPTY / panel',96,384,1192,352),text('EMPTY / title','열린 방이 없어요',144,456,1056,40,'text','700'),text('EMPTY / body','새로고침하거나 새 방을 만들어 보세요.\n실제 조회 결과가 아닌 빈 목록 상태 예시입니다.',144,536,1056,30,'muted')]
 e +=[rect('ACTION / panel',1344,200,480,568),text('ACTION / title','초대 코드로 입장',1376,232,416,34,'gold','700'),button('CODE / open','전체 코드 입력',1376,312,416,88,'code-input'),button('ACTION / join','입장' if selected!=1 else '가득 찬 방',1376,424,416,96,('room-team' if selected==2 else 'room-solo' if filter=='solo' else 'room-normal') if selected in [0,2] else None,'primary' if selected in [0,2] else 'disabled',36),text('ACTION / hint','방을 선택한 뒤 입장해요.' if selected is None else '정원이 찬 방에는 입장할 수 없어요.' if selected==1 else '입장 화면의 배치를 살펴봅니다.\n실제 연결은 시작하지 않아요.',1376,552,416,26,'muted'),button('ACTION / create','방 만들기',1344,792,480,88,'create-room','primary',34),button('LIST / refresh','새로고침',96,944,280,88,'rooms-loading'),text('LIST / capacity','개인전 최대 8명 · 팀전 팀당 최대 4명 / 전체 최대 8명',416,964,1328,28,'muted')]
 return s
rooms();rooms('rooms-solo',filter='solo');rooms('rooms-team',filter='team');rooms('rooms-selected',0);rooms('rooms-full-selected',1);rooms('rooms-team-selected',2,filter='team');rooms('rooms-empty',empty=True);rooms('rooms-solo-selected',0,filter='solo');rooms('rooms-solo-full',1,filter='solo')
# Read-only code input demonstrates whole invite code, without inventing a new parser contract.
for filled in [False,True]:
 s=base('code-filled' if filled else 'code-input','초대 코드로 입장',back='rooms');e=s['elements'];e +=[rect('CODE / panel',288,248,1344,584),text('CODE / title','한 줄 초대 코드 전체를 입력해요',336,296,1248,40,'text','700'),text('CODE / hint','방장이 공유한 한 줄 코드를 모두 입력해 주세요.\n아래 입력은 시안 예시이며 실제 붙여넣기·연결을 실행하지 않아요.',336,384,1248,30,'muted'),button('CODE / field','FA5… (전체 코드 예시 · 축약 표시)' if filled else '전체 초대 코드 · 입력 예시 보기',336,504,1248,96,'code-filled' if not filled else None,'selected' if filled else 'default'),button('CODE / cancel','취소',336,672,584,96,'rooms'),button('CODE / enter','입장 시안 보기',944,672,640,96,'room-normal' if filled else 'code-required','primary',34),button('CODE / unavailable','참가 불가 상태 보기',336,928,584,88,'code-unavailable'),text('CODE / scope','초대 코드 전체로 입장해요.\n시안에서는 실제 연결을 시작하지 않아요.',944,952,880,26,'muted')]
for team in [False,True]:
 key='create-team' if team else 'create-room';s=base(key,'방 만들기',back='rooms');e=s['elements'];e +=[rect('CREATE / panel',288,224,1344,640),text('CREATE / title','대기방 설정 · 설계 예시',336,264,1248,40,'gold','700'),text('CREATE / name label','제목',336,360,224,30,'muted'),button('CREATE / name','함께하는 숲' if team else '숲의 대기방',600,344,984,88,'room-name-info'),text('CREATE / mode label','대전 방식',336,488,224,30,'muted'),button('CREATE / solo','개인전',600,472,472,88,'create-room' if team else None,'default' if team else 'selected'),button('CREATE / team','팀전',1096,472,488,88,None if team else 'create-team','selected' if team else 'default'),text('CREATE / capacity','전체 최대 8명 · 팀전은 팀당 최대 4명\n현재 LAN 1:1 기능과 장래 다인원 방 설계는 별도입니다.',336,608,1248,30,'muted'),button('CREATE / cancel','취소',336,744,584,88,'rooms'),button('CREATE / preview','대기방 시안 보기',944,744,640,88,'room-team' if team else 'room-normal','primary',34)]
# Rank lobby: preserve sketch tier only as a clearly labelled example. No new economy/rating rules.
s=base('rank-lobby','랭킹대전','SCR_23_Rank',note='실버 3은 손그림의 설계 예시 · 시즌·점수·승급·보상·매칭 운영은 미정');e=s['elements'];e +=[rect('RANK / panel',96,208,824,664),rect('MISSING / rank emblem',304,264,408,304,'bg',.7,16),text('MISSING / rank slot','IMG/rank/emblem/silver-3\n승인 원화 미수록',328,352,360,26,'muted','500','center'),text('RANK / tier','실버 3 · 예시',144,624,728,52,'gold','700','center'),text('RANK / details','실제 내 등급이나 확정된 시즌 정보가 아닙니다.\n등급·점수·배치·승급·보상 조건은 미정입니다.',144,720,728,28,'muted','500','center'),button('RANK / party','파티 찾기',1008,248,816,152,'rank-party-info','default',42),button('RANK / friends','친구 초대',1008,440,816,152,'rank-friends','default',42),button('RANK / match','자동 매칭',1008,632,816,152,'rank-match-info','primary',42),text('RANK / scope','현재 LAN 승패 순위와 장래 시즌 랭크는 별도입니다. 실제 매칭·파티·초대는 실행하지 않아요.',96,944,1728,28,'muted')]
s=base('rank-friends','랭킹대전 · 친구 초대',back='rank-lobby',note='이름·접속 상태는 예시 · 랭크 파티 초대의 자격·인원·유효 시간·참가 조건 미정');e=s['elements'];e +=[text('FRIENDS / title','초대할 친구',96,216,1400,40,'gold','700')]
for i,(name,status) in enumerate([('솔잎','접속 중 · 예시'),('느티','오프라인 · 예시')]):
 y=320+i*176;e +=[rect('FRIENDS / row '+str(i),96,y,1728,144),text('FRIENDS / name '+str(i),name,128,y+32,640,36),text('FRIENDS / status '+str(i),status,816,y+40,560,28,'muted'),button('FRIENDS / invite '+str(i),'초대 검토',1440,y+24,352,96,'rank-invite-info')]
e +=[text('FRIENDS / scope','기존 친구의 LAN 대기방 초대를 랭크 파티 초대로 전환하지 않습니다.',96,944,1728,28,'muted')]
# Reuse approved 8-slot room structure in new review copies; originals remain untouched.
old=json.loads((P.parent/'scene-spec.json').read_text());src=next(s for s in old['scenes'] if s['key']=='room')
for kind in ['ai','normal','solo','team']:
 k='ai-room' if kind=='ai' else 'room-'+kind;s=copy.deepcopy(src);s.update(key=k,name='MENU09 / Match-r01 / '+k,revision='match-r01',reused_from='approved representative-r01 room');scenes.append(s)
 for x in s['elements']:
  if x['kind']=='button':
   x['dest']=k+'-leave' if x['name'] in ['BACK','ROOM / leave'] else k+'-ready' if x['name']=='ROOM / ready' else 'room-functions-info'
  if x['name']=='HEADER / subtitle':x['text']='AI 대전 · 승인 대전방 재사용' if kind=='ai' else '장래 다인원 방 배치 예시 · 현재 실제 LAN은 1:1'
  if x['name']=='TITLE':x['text']='숲의 연습방' if kind=='ai' else '함께하는 숲' if kind=='team' else '숲의 대기방'
  if x['name']=='ROOM / 대전 방식 value':x['text']='AI · 개인전' if kind=='ai' else '팀전 · A/B팀 각 최대 4명' if kind=='team' else '개인전 · 최대 8명';x['size']=28;x['h']=41
  if x['name']=='PARTY / badge 1' and kind!='ai':x['text']='참가자 · 예시'
  if x['name']=='PARTY / name 1' and kind!='ai':x['text']='솔잎'
  if x['name']=='ROOM / slots' and kind=='team':x['text']='A팀 1 / 4 · B팀 1 / 4'
  if x['name']=='ROOM / AI' and kind!='ai':x.update(text='친구 초대',dest='room-functions-info')
 # Team rows explicitly carry A/B membership; move the second occupied slot to row2.
 if kind=='team':
  for x in s['elements']:
   if x['name'] in ['PARTY / badge 1','IMG / ja-hyun','PARTY / name 1']:x['x']-=304;x['y']+=280
   if x['name'] in ['PARTY / plus 4','PARTY / empty 4']:x['x']+=304;x['y']-=280
   if x['name']=='PARTY / badge 0':x['text']='A팀 · 방장 · 나'
   if x['name']=='PARTY / badge 1':x['text']='B팀 · 참가자 · 예시'
   if x['name'].startswith('PARTY / empty '):
    idx=int(x['name'].split()[-1]);x['text']=('A팀' if idx in [2,3,4] else 'B팀')+' 빈 자리'
 if kind=='team':
  moved=[x for x in s['elements'] if x['name'] in ['PARTY / badge 1','IMG / ja-hyun','PARTY / name 1']]
  s['elements']=[x for x in s['elements'] if x not in moved]
  pos=next(i for i,x in enumerate(s['elements']) if x['name']=='PARTY / slot 5')+1
  s['elements'][pos:pos]=moved
 ready=copy.deepcopy(s);ready.update(key=k+'-ready',name='MENU09 / Match-r01 / '+k+'-ready');scenes.append(ready)
 for x in ready['elements']:
  if x['name']=='ROOM / ready':x.update(text='대전 시작 · 시안',dest='start-info',icon=None,size=30)
  if x['name'] in ['BACK','ROOM / leave']:x['dest']=k+'-ready-leave'
  if x['name']=='ROOM / status':x['text']='준비 완료 표시 예시 · 실제 연결 없음'
 ready['elements'].append(button('ROOM / cancel ready','준비 취소',1008,816,304,80,k,'ghost',28))
 for state in ['', '-ready']:
  origin=k+state;dest='mode-select' if kind=='ai' else 'rooms-solo-selected' if kind=='solo' else 'rooms-team-selected' if kind=='team' else 'rooms-selected';m=copy.deepcopy(s if not state else ready);m.update(key=origin+'-leave',name='MENU09 / Match-r01 / '+origin+'-leave',modal=True)
  for x in m['elements']:
   if x['kind']=='button':x['dest']=None;x['state']='disabled'
  m['elements'] +=[rect('MODAL / scrim',0,0,1920,1080,'bg',.86,0),rect('MODAL / panel',400,280,1120,504),text('MODAL / title','대기방에서 나갈까요?',448,336,1024,42,'text','700'),text('MODAL / body','현재 방을 나가는 동선을 검토합니다.\n실제 연결이나 방 상태를 변경하지 않습니다.',448,432,1024,32,'muted'),button('MODAL / cancel','계속 머무르기',448,656,496,88,origin),button('MODAL / leave','나가기',976,656,496,88,dest,'primary',34)];scenes.append(m)
# Shared review-only overlays preserve the actual origin and do not fabricate service success.
def overlay(k,title,body,disabled=None):
 s=dict(key=k,name='MENU09 / Match-r01 / '+k,title=title,canonical='EXT_MENU09_Match',revision='match-r01',w=1920,h=1080,overlay=True,elements=[rect('MODAL / scrim',0,0,1920,1080,'bg',.86,0),rect('MODAL / panel',400,248,1120,584),text('MODAL / eyebrow','FOREST ARENA · 설계 검토',448,288,1024,24,'gold'),text('MODAL / title',title,448,344,1024,42,'text','700'),text('MODAL / body',body,448,440,1024,30,'muted'),button('MODAL / close','닫기',448,712,496 if disabled else 1024,80,None,'primary',30,'close-overlay')])
 if disabled:s['elements'].append(button('MODAL / unavailable',disabled,976,712,496,80,None,'disabled',28))
 scenes.append(s);return s
for args in [('normal-match-info','자동 매칭 준비 중','매칭 조건·지역·대기 시간·실패 복구 규칙은 미정입니다.\n이 시안은 검색을 시작하거나 상대를 확정하지 않습니다.','매칭 시작 · 미정'),('rank-party-info','파티 찾기 준비 중','파티 자격·인원·공개 범위·역할·파티장 권한은 미정입니다.\n현재 제공되는 LAN 1:1 기능과 별도입니다.','파티 찾기 · 미정'),('rank-match-info','랭킹 자동 매칭 준비 중','시즌·등급·점수·팀 구성·매칭 조건은 미정입니다.\n검색·완료·취소·실패의 실제 온라인 규칙은 별도 결정합니다.','매칭 시작 · 미정'),('rank-invite-info','랭크 파티 초대 조건 미정','선택한 친구에게 파티 초대를 보내는 배치를 검토해요.\n현재 친구 LAN 초대와 별도이며 실제 초대를 보내지 않습니다.','초대 보내기 · 미정'),('code-required','전체 초대 코드를 입력해 주세요','한 줄 초대 코드 전체가 필요해요.\n시안의 입력 예시로 이동해 형식과 동선을 확인해 주세요.',None),('code-unavailable','방에 참가할 수 없어요','형식 오류·호환되지 않는 버전·만료·닫힌 방·정원 초과를\n구분해야 합니다. 이 화면은 실패 안내 배치 예시입니다.',None),('room-name-info','방 제목 입력 시안','제목은 편집 가능한 텍스트 예시입니다.\n실제 입력·길이·중복·노출 규칙은 후속 제품 결정입니다.',None),('room-functions-info','승인된 방 구성 재사용','캐릭터·신기·AI 추가·친구 초대는 기존 승인 시안과 연결할\n대상입니다. 실제 편성·선택·초대 데이터는 바꾸지 않습니다.',None),('start-info','대전 준비 흐름 검토','준비 완료→시작 버튼의 위계를 검토합니다.\n이 시안에서는 실제 경기를 시작하지 않습니다.','시작 · 시안')]:overlay(*args)
# Loading/empty/error states are reachable from guide; real services are not invoked.
s=overlay('rooms-loading','방 목록을 불러오는 중','조회·취소 상태의 배치 예시입니다.\n실제 방 조회를 호출하지 않아요.');s['elements'][-1]['text']='조회 시안 닫기'
for k,t,b,d in [('rooms-error','방 목록을 불러오지 못했어요','빈 목록과 연결 오류를 구분합니다.\n현재 표시할 수 있는 방 정보는 설계 예시입니다.','rooms'),('rank-error','랭크 정보를 불러오지 못했어요','실패한 조회를 등급 없음이나 새 시즌 초기화로 표시하지 않아요.\n현재 시안의 실버 3은 손그림의 예시입니다.','rank-lobby')]:
 s=base(k,t,back=d);s['elements'] +=[rect('ERROR / panel',96,248,1728,568),text('ERROR / body',b,144,360,1632,34,'muted'),button('ERROR / retry','다시 시도 · 시안',144,648,1632,88,d,'primary',34)]
overlay('rank-loading','랭크 정보를 불러오는 중','로딩 상태의 배치 예시입니다.\n실제 시즌이나 등급을 조회하지 않습니다.')
# New navigation copies of approved lobby; approved source remains untouched.
src=next(s for s in old['scenes'] if s['key']=='lobby');s=copy.deepcopy(src);s.update(key='match-entry',name='MENU09 / Match-r01 / match-entry',revision='match-r01',reused_from='approved lobby r01')
for e in s['elements']:
 if e['kind']=='button':e['dest']='mode-select' if e['name']=='NORMAL' else 'rank-lobby' if e['name']=='RANKED' else 'match-other-info'
scenes.append(s);overlay('match-other-info','다른 메뉴 안내','다른 메뉴는 앞서 승인한 MENU09 영역에서 검토합니다.\n이 묶음은 대전 준비3종과 복제 진입 동선을 검토합니다.')
s=base('match-handoff','대전 준비 · 검토 안내',note='참조17·16·02 대응 · 기존 승인 대전방 재사용 · 실제 개발 없음');e=s['elements'];e +=[text('GUIDE / summary','match-r01 · 일반대전 선택 / 방 목록 / 랭킹대전 로비\nAI·자동 매칭·로비는 진입 방식이며 새 게임 모드가 아닙니다.\nStory·Solo·Team·AI·Practice 계약과 최대 8명·팀당 최대 4명 유지\n현재 LAN 1:1과 장래 인터넷·다인원·시즌 랭크는 별도입니다.',96,200,1728,34,'gold')]
for i,(t,d) in enumerate([('일반대전 선택','mode-select'),('방 목록','rooms'),('랭킹 로비','rank-lobby'),('빈 방 목록','rooms-empty'),('방 목록 오류','rooms-error'),('랭크 로딩','rank-loading'),('랭크 조회 오류','rank-error'),('전체 코드 입력','code-input'),('방 만들기','create-room')]):
 e.append(button('GUIDE / '+d,t,96+(i%3)*584,480+(i//3)*128,560,96,d,'primary' if i<3 else 'default',32))
e +=[text('GUIDE / missing','MISSING ASSETS · IMG/rank/emblem/silver-3 승인 원화 1종 미수록',96,944,1728,28,'muted')]
for k in ['mode-select','rooms','rank-lobby']:
 s=copy.deepcopy(next(s for s in scenes if s['key']==k));s.update(key=k+'-wide',name='MENU09 / Match-r01 / '+k+'-wide',w=2400,comparison_of=k)
 for e in s['elements']:
  if e['name'] in ['IMG / character-room','ATMOSPHERE','HEADER','FOOTER']:e['w']=2400
  else:e['x']+=240
  if e['kind']=='button':e['dest']=None;e.pop('action',None)
 scenes.append(s)
for s in scenes:
 for e in s['elements']:
  if e.get('dest')==s['key']:e['dest']=None
reuse_refs={'rooms-solo-selected': 'rooms-solo', 'rooms-solo-full': 'rooms-solo-selected', 'code-filled': 'code-input', 'create-team': 'create-room', 'ai-room': 'approved-room', 'ai-room-ready': 'ai-room', 'ai-room-leave': 'ai-room', 'ai-room-ready-leave': 'ai-room-ready', 'room-normal': 'ai-room', 'room-normal-ready': 'room-normal', 'room-normal-leave': 'room-normal', 'room-normal-ready-leave': 'room-normal-ready', 'room-solo': 'room-normal', 'room-solo-ready': 'room-solo', 'room-solo-leave': 'room-solo', 'room-solo-ready-leave': 'room-solo-ready', 'room-team': 'room-normal', 'room-team-ready': 'room-team', 'room-team-leave': 'room-team', 'room-team-ready-leave': 'room-team-ready', 'match-entry': 'approved-lobby'}
for s in scenes:
 if s["key"] in reuse_refs:s["clone_of"]=reuse_refs[s["key"]]
# Fullscreen overlays keep the actual list/selection behind shared forms and rooms.
context_keys={'code-input','code-filled','create-room','create-team'}|{s['key'] for s in scenes if s['key'].startswith(('ai-room','room-normal','room-solo','room-team'))}
for s in scenes:
 if s['key'] not in context_keys:continue
 s['overlay']=True
 for e in s['elements']:
  if e['kind']!='button' or e['state']=='disabled':continue
  close_form=s['key'] in ['code-input','code-filled','create-room','create-team'] and e['name'] in ['BACK','CODE / cancel','CREATE / cancel']
  close_room=s['key'].endswith('-leave') and e['name']=='MODAL / leave'
  if close_form or close_room:e['dest']=None;e['action']='close-overlay'
  elif e.get('dest') in context_keys:e['action']='replace-overlay'
j=dict(revision='match-r01',colors=C,base_keys=['mode-select','rooms','rank-lobby'],missing_assets=['IMG/rank/emblem/silver-3'],runtime_approved=False,scenes=scenes)
(P/'scene-spec.json').write_text(json.dumps(j,ensure_ascii=False,indent=2)+'\n');print('boards',len(scenes))
