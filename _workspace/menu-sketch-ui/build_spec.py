"""Build the first approval batch; later screens remain planned."""
from pathlib import Path
import copy,json,math
P=Path(__file__).resolve().parent
C=dict(bg='#10181C',panel='#1C282C',text='#F2F3ED',muted='#BBC6C6',gold='#D9C58E',mint='#8CBFB2',line='#455455')
def elem(k,name,x,y,w,h,**kw):return dict(kind=k,name=name,x=x,y=y,w=w,h=h,**kw)
def text(name,value,x,y,w,size=32,color='text',weight='500',align='left'):return elem('text',name,x,y,w,round(size*1.45*len(value.split('\n'))),text=value,size=size,color=color,weight=weight,align=align)
def rect(name,x,y,w,h,color='panel',opacity=1,radius=12):return elem('rect',name,x,y,w,h,color=color,opacity=opacity,radius=radius)
def button(name,value,x,y,w,h,dest=None,state='default',icon=None,size=30):return elem('button',name,x,y,w,h,text=value,dest=dest,state=state,icon=icon,size=size)
def image(key,x,y,w,h,slot):return elem('image','IMG / '+key,x,y,w,h,key=key,slot=slot)
def base(key,title,canonical):
 return dict(key=key,name='MENU09 / '+canonical+' / '+key,canonical=canonical,title=title,revision='r01',w=1920,h=1080,elements=[image('character-room',0,0,1920,1080,'IMG/bg/character-room'),rect('ATMOSPHERE',0,0,1920,1080,'bg',.70,0),rect('HEADER',0,0,1920,160,'bg',.85,0),rect('FOOTER',0,880,1920,200,'bg',.95,0)])
def header(s,title,sub):
 s['elements'] += [button('BACK','←',96,48,80,80,'lobby',state='ghost',size=36),text('TITLE',title,208,48,680,52,weight='700'),text('HEADER / subtitle',sub,208,112,1100,26,'muted'),text('BRAND','FOREST ARENA',1496,64,328,28,'gold',weight='600',align='right')]
scenes=[]
s=base('lobby','메인 로비','SCR_03_Lobby');e=s['elements']
e += [button('PROFILE','묘령',96,48,104,88,'lobby-pending',icon=None,size=26),text('PLAYER','숲의 여행자',224,48,400,38,weight='700'),text('PLAYER / label','대표 캐릭터 · 묘령',224,104,400,26,'muted'),text('BRAND','FOREST ARENA',696,64,344,30,'gold',weight='600',align='center')]
e += [rect('CURRENCY / stone',1064,56,208,72,'panel',.95),text('CURRENCY / stone label','조약돌  —',1088,72,160,26),rect('CURRENCY / rainbow',1288,56,224,72,'panel',.95),text('CURRENCY / rainbow label','무지개돌  —',1304,72,192,26)]
e += [button('NOTICE','공지',1528,48,88,88,'lobby-pending',size=26),button('MAIL','우편',1632,48,88,88,'lobby-pending',size=26),button('SETTINGS','설정',1736,48,88,88,'lobby-pending',size=26)]
e += [text('LOBBY / eyebrow','FOREST ADVENTURE',96,216,344,24,'mint',weight='600'),text('LOBBY / invitation','숲에서 만나는\n새로운 한 판',96,256,400,48,weight='700'),button('STORY','스토리 모드',96,448,328,104,'lobby-pending',icon='book'),rect('LOADOUT / rule',96,616,328,2,'line',1,0),text('LOADOUT / heading','나의 편성',96,648,328,28,'gold'),text('LOADOUT / character','묘령',96,704,328,44,weight='700'),text('LOADOUT / style','고기동 공중 압박형',96,768,360,28,'muted'),text('LOADOUT / artifact','신기  ·  철갑옷',96,816,328,28)]
e += [image('myo-ryung',464,176,824,696,'IMG/char/rabbit/full')]
e += [text('PLAY / eyebrow','대전을 시작하세요',1368,256,456,28,'gold'),button('NORMAL','일반대전',1368,320,456,168,'room',state='primary',icon='play',size=48),text('NORMAL / caption','AI · 자동 매칭 · 로비',1392,504,424,28,'muted'),button('RANKED','랭킹대전',1368,584,456,120,'lobby-pending',icon='crown',size=36),text('RANKED / caption','실력을 겨루는 한 판',1392,724,424,28,'muted')]
for i,(label,icon,dest) in enumerate([('상점','leaf','lobby-pending'),('캐릭터','people','character-stats'),('신기','armor','lobby-pending'),('미션','check','lobby-pending'),('업적','crown','lobby-pending'),('친구','people','lobby-pending')]):
 e.append(button('NAV / '+label,label,96+i*288,920,272,112,dest,icon=icon,size=32))
scenes.append(s)
s=base('character-stats','캐릭터 스탯','SCR_05_CharacterDetail');header(s,'캐릭터','내게 맞는 전투 스타일을 찾아보세요');e=s['elements']
e += [text('CHARACTER / name','묘령',96,200,600,56,weight='700'),text('CHARACTER / role','고기동 공중 압박형',96,284,600,30,'mint'),image('myo-ryung',144,320,616,552,'IMG/char/rabbit/full')]
for i,(label,dest) in enumerate([('스탯',None),('기술','character-pending'),('스토리','character-pending')]):e.append(button('TAB / '+label,label,800,248+i*136,224,112,dest,'selected' if i==0 else 'default',size=36))
e += [rect('STATS / panel',1080,208,744,648,'panel',.94,16),text('STATS / title','기본 능력치',1120,240,600,36,weight='700'),elem('radar','STATS / radar',1224,352,448,368,values=[95/120,350/400,330/400,570/650,.85/1.2]),text('STAT / hp','체력 95',1312,304,280,28,align='center'),text('STAT / move','지상 이동 350',1544,440,256,26,align='center'),text('STAT / air','공중 이동 330',1440,720,328,26,align='center'),text('STAT / jump','점프 570',1112,720,280,26,align='center'),text('STAT / weight','무게 0.85',1096,440,224,26,align='center'),text('STATS / hint','이동과 공중 진입에 강한 캐릭터',1120,800,664,28,'muted')]
for i,(key,label) in enumerate([('ja-hyun','자현'),('myo-ryung','묘령'),('nabi','나비'),('yu-ran','유란')]):
 x=96+i*264;e += [rect('ROSTER / '+key,x,912,248,120,'panel',1,12),image(key,x+8,920,80,104,{'ja-hyun':'IMG/char/mouse/full','myo-ryung':'IMG/char/rabbit/full','nabi':'IMG/char/roster/cat','yu-ran':'DESIGN/char/yu-ran/portrait'}[key]),button('ROSTER / hit '+key,label+(' ✓' if i==1 else ''),x+88,912,160,120,None if i==1 else 'character-pending','selected' if i==1 else 'ghost',size=28)]
e += [button('PRACTICE','AI 연습 준비',1368,920,456,112,'room','primary',icon='play',size=36)]
scenes.append(s)
s=base('room','일반·AI 대전방','SCR_10_PartyLobby');header(s,'숲의 연습방','AI 대전 · 개인전');e=s['elements']
e += [text('ROOM / slots','참가자 2 / 8',96,192,600,32,weight='600'),text('ROOM / capacity','개인전 최대 8명 · 팀전 팀당 1~4명',672,200,640,26,'muted',align='right')]
for i in range(8):
 x=96+(i%4)*304;y=264+(i//4)*280
 e.append(rect('PARTY / slot '+str(i+1),x,y,280,248,'panel',.96,16))
 if i<2:
  key='myo-ryung' if i==0 else 'ja-hyun';e += [text('PARTY / badge '+str(i), '방장 · 나' if i==0 else 'AI',x+20,y+16,240,24,'gold' if i==0 else 'mint'),image(key,x+80,y+56,120,128,'IMG/char/rabbit/full' if i==0 else 'IMG/char/mouse/full'),text('PARTY / name '+str(i),'숲의 여행자' if i==0 else '연습 AI',x+16,y+192,248,28,align='center')]
 else:e += [text('PARTY / plus '+str(i),'+',x+104,y+56,72,56,'line',align='center'),text('PARTY / empty '+str(i),'빈 자리',x+24,y+168,232,28,'muted',align='center')]
e += [rect('ROOM / settings',1368,192,456,544,'panel',.97,16),text('ROOM / settings heading','경기 설정',1400,224,384,36,weight='700'),rect('ROOM / settings rule',1400,288,392,2,'line',1,0)]
for label,value,y in [('대전 방식','AI · 개인전',320),('경기장','기본 경기장',416),('내 캐릭터','묘령',512),('장착 신기','철갑옷',608)]:e += [text('ROOM / '+label,label,1400,y,384,26,'muted'),text('ROOM / '+label+' value',value,1400,y+40,384,32)]
e += [button('ROOM / character','캐릭터 변경',96,920,432,112,'character-stats',icon='people'),button('ROOM / artifact','신기 변경',552,920,432,112,'room-pending',icon='armor'),button('ROOM / AI','AI 추가',1008,920,304,112,'room-pending'),text('ROOM / status','준비 후 대전을 시작할 수 있어요',1368,768,456,26,'muted'),button('ROOM / ready','준비하기',1368,816,456,112,'room-ready','primary',icon='check',size=36),button('ROOM / leave','나가기',1368,952,456,80,'room-leave','ghost')]
scenes.append(s)
# Explicit representative states, preserving the origin when closed.
ready=copy.deepcopy(s);ready.update(key='room-ready',name='MENU09 / SCR_10_PartyLobby / room-ready',title='대전방 준비 완료')
for x in ready['elements']:
 if x['name']=='ROOM / ready':x.update(text='대전 시작',dest='room-ready-pending',icon='play')
 if x['name']=='ROOM / status':x.update(text='✓ 준비 완료 · AI는 자동으로 준비해요',color='mint')
 if x['name']=='ROOM / leave':x['dest']='room-ready-leave'
 if x['name'] in ['ROOM / AI','ROOM / artifact']:x['dest']='room-ready-pending'
 if x['name']=='PARTY / badge 0':x.update(text='방장 · 나 · 준비 ✓',color='mint')
ready['elements'].append(button('ROOM / cancel ready','준비 취소',1008,816,304,80,'room','ghost',size=28))
scenes.append(ready)
def modal(origin,key,title,body,confirm=None):
 s=copy.deepcopy(next(x for x in scenes if x['key']==origin));s.update(key=key,name='MENU09 / Review / '+key,title=title,modal=True)
 for x in s['elements']:
  if x['kind']=='button':x['dest']=None
 s['elements'] += [rect('MODAL / scrim',0,0,1920,1080,'bg',.80,0),rect('MODAL / panel',464,304,992,472,'panel',1,20),text('MODAL / eyebrow','FOREST ARENA',512,344,800,24,'gold'),text('MODAL / title',title,512,392,864,44,weight='700'),text('MODAL / body',body,512,472,864,30,'muted')]
 if confirm:
  s['elements'] += [button('MODAL / cancel','취소',512,648,424,80,origin),button('MODAL / confirm','나가기',960,648,448,80,confirm,'primary')]
 else:s['elements'].append(button('MODAL / close','닫기',512,648,896,80,origin,'primary'))
 scenes.append(s)
modal('lobby','lobby-pending','다음 설계 묶음','이 메뉴는 대표 화면 검토 후 이어서 제작합니다.\n가격·보상·온라인 서비스 규칙은 별도 확인합니다.')
modal('character-stats','character-pending','캐릭터 화면 확장 예정','기술·스토리와 다른 캐릭터의 상세 화면은\n대표 화면의 방향을 확인한 뒤 제작합니다.')
modal('room','room-pending','대전 준비 화면 확장 예정','신기 선택과 AI 추가 흐름은 다음 묶음에서 검토합니다.\n현재 화면은 대전방 구성을 확인하는 시안입니다.')
modal('room-ready','room-ready-pending','대전방 구성 검토','이 프로토타입에서는 실제 경기를 시작하지 않습니다.\n준비 상태와 화면 흐름을 확인할 수 있습니다.')
modal('room','room-leave','대전방에서 나갈까요?','현재 방을 나가고 메인 로비로 돌아갑니다.','lobby')
modal('room-ready','room-ready-leave','대전방에서 나갈까요?','현재 방을 나가고 메인 로비로 돌아갑니다.','lobby')
# Preserve room entry context through read-only character review and exit confirmation.
for source in scenes:
 if source['key'] in ['room','room-ready']:
  for e in source['elements']:
   if e['name']=='BACK':e['dest']='room-leave' if source['key']=='room' else 'room-ready-leave'
   if e['name']=='ROOM / character':e['dest']='character-from-'+source['key']
for origin in ['room','room-ready']:
 detail=copy.deepcopy(next(x for x in scenes if x['key']=='character-stats'))
 detail.update(key='character-from-'+origin,name='MENU09 / Review / character-from-'+origin,title='대전방에서 연 캐릭터 스탯')
 for e in detail['elements']:
  if e['name']=='BACK':e['dest']=origin
  elif e['name']=='PRACTICE':e.update(text='대전방으로 돌아가기',dest=origin,size=30)
  elif e.get('dest')=='character-pending':e['dest']='character-from-'+origin+'-pending'
 scenes.append(detail)
 modal(detail['key'],detail['key']+'-pending','캐릭터 화면 확장 예정','기술·스토리와 다른 캐릭터의 상세 화면은\n대표 화면의 방향을 확인한 뒤 제작합니다.')

# 20:9 compares a centered, unchanged safe layout, with extended forest scenery.
for source in list(scenes[:3]):
 s=copy.deepcopy(source);s.update(key=source['key']+'-wide',name='MENU09 / Compare20x9 / '+source['key'],title=source['title']+' 20:9',w=2400,comparison_of=source['key'])
 for e in s['elements']:
  if e['name'] in ['IMG / character-room','ATMOSPHERE','HEADER','FOOTER']:e['w']=2400
  else:e['x']+=240
  if e['kind']=='button':e['dest']=None
 scenes.append(s)
spec=dict(version=1,approval_batch='representative-r01',base_keys=['lobby','character-stats','room'],colors=C,scenes=scenes)
(P/'scene-spec.json').write_text(json.dumps(spec,ensure_ascii=False,indent=2)+'\n')
(P/'load-spec.js').write_text('storage.menu09.spec='+json.dumps(spec,ensure_ascii=False,separators=(',',':'))+'; return {scenes:storage.menu09.spec.scenes.length};\n')
print('spec',len(scenes),'boards / 3 representatives / 3 wide comparisons')
