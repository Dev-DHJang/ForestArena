"""Premium Menu v08 editable Penpot scene input. Does not modify image originals/runtime."""
from pathlib import Path
from copy import deepcopy
import json, math, ast, csv, hashlib
TASK=Path(__file__).resolve().parent
ROOT=TASK.parents[1]
OLD=json.loads((TASK.parent/'premium-menu-v07/scene-spec.json').read_text())
# Original authored v07 glyphs are reused, never regenerated into the asset folder.
TREE=ast.parse((TASK.parent/'premium-menu-v07/build_spec.py').read_text())
PATHS=next(ast.literal_eval(n.value) for n in TREE.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='PATHS' for t in n.targets))
C=dict(OLD['palette'],black='#0B1216',soft='#26383A')
BASE=['SCR_03_Lobby']+OLD['base'];S={};cur=None
CHARS=[('ja-hyun','자현','균형','간격 유지 · 근접 압박','숲 마을의 빠른 심부름꾼.\n침착하게 거리를 재며\n동료를 위험에서 빼냅니다.'),('myo-ryung','묘령','기동','빠른 이동 · 공중 선점','숲 축제의 길잡이.\n낯선 길에도 먼저 뛰어들어\n동료가 따라올 길을 만듭니다.'),('nabi','나비','근접','빠른 진입 · 근거리 압박','숲 마을의 야간 순찰대.\n큰 실루엣으로 시선을 끌어\n동료가 빠져나갈 길을 만듭니다.'),('yu-ran','유란','견제','꼬리 쓸기 · 위치 유지','안개늪 출신의 추적자.\n접근 경로를 확인하며\n전장의 신뢰를 쌓습니다.')]
ITEMS=[('iron_armor','철갑옷','방어','무게 +5%\n지상 속도 −5%','armor'),('boxing_gloves','복싱 글러브','기술','유란 기술 목록으로 교체\n속도 보너스 없음','glove'),('thorns','균형 장신구','이동','공중 속도 +5%\n지상 속도 −5%','balance'),('explosive_gloves','도약 장갑','이동','점프 속도 +5%\n무게 −5% · 더 잘 밀려남','jump'),('ultimate_charm','집중 장신구','기술','유효 적중 시 궁극기 +4\n지상 속도 −5%','focus'),('phoenix_revive','활공 장신구','이동','중력 −5%\n공중 속도 −5%','wing')]
def nm(base,tag):return 'MENU08 / '+base+' / '+tag
def svg(k):return f'<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><g fill="#26383A" stroke="#D9C58E" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round">{PATHS[k]}</g></svg>'
def add(kind,name,x,y,w,h,**kw):
 e=dict(kind=kind,name=name,x=x,y=y,w=w,h=h,**kw);cur['elements'].append(e);return e
def rect(name,x,y,w,h,color='panel',opacity=1,r=0,stroke=None):return add('rect',name,x,y,w,h,color=C.get(color,color),opacity=opacity,r=r,stroke=C.get(stroke,stroke))
def text(name,t,x,y,w=500,size=32,color='text',weight='500',align='left'):return add('text',name,x,y,w,math.ceil(size*1.45*(t.count('\n')+1)),text=t,size=size,color=C.get(color,color),weight=weight,align=align)
def art(k,x,y,w,h,slot=None):
 slots={'ja-hyun':'IMG/char/mouse/','myo-ryung':'IMG/char/rabbit/','nabi':'IMG/char/roster/cat' if max(w,h)<=300 else 'DESIGN/char/nabi/full','yu-ran':'DESIGN/char/yu-ran/portrait' if max(w,h)<=300 else 'DESIGN/char/yu-ran/full'}
 if not slot:
  slot=slots.get(k,('IMG/bg/' if k in ['character-room','accessory-workshop'] else 'DESIGN/bg/')+k)
  if k in ['ja-hyun','myo-ryung']:slot+='face' if max(w,h)<=300 else 'full'
 return add('image','ART / '+k,x,y,w,h,key=k,slot=slot)
def icon(k,x,y,z=72):return add('svg','ICON / '+k,x,y,z,z,svg=svg(k),key=k)
def btn(t,x,y,w=240,h=80,dest=None,state='ghost',ic=None):return add('button','BUTTON / '+t,x,y,w,h,text=t,dest=dest,state=state,icon=ic,legacy='BUTTON / '+t)
def hot(t,x,y,w,h,d):return add('hotspot','SELECT / '+t,x,y,w,h,dest=d)
def line(x,y,w=1728,c='line'):rect('RULE',x,y,w,1,c,.75)
def label(t,x,y,w=700):text('EYEBROW',t,x,y,w,24,'gold')
def note(t,x=96,y=988,w=1072):text('CONTEXT / '+t,t,x,y,w,28,'muted')
def panel(t,x,y,w,h,selected=False):
 rect(t,x,y,w,h,'panel',.88,4,'gold' if selected else 'line')
 if selected:rect('SELECTED / rule',x,y,4,h,'gold')
def tabs(labels,x,y,width,active,dests):
 space=width-8*(len(labels)-1);unit=math.floor(space/len(labels)/8)*8;extra=round((space-unit*len(labels))/8);xx=x
 for i,t in enumerate(labels):
  w=unit+(8 if i<extra else 0);btn(t,xx,y,w,72,dests[i],'selected' if i==active else 'ghost');xx+=w+8
def new(name,title,bg,section,back='SCR_03_Lobby',footer=True):
 global cur
 cur=dict(name=name,title=title,background=bg,w=1920,h=1080,target=name in BASE,elements=[]);S[name]=cur
 art(bg,0,0,1920,1080);rect('ATMOSPHERE / dark',0,0,1920,1080,'bg',.52)
 rect('HEADER / scrim',0,0,1920,168,'black',.9);rect('FOOTER / scrim',0,944,1920,136,'black',.94)
 btn('뒤로',96,48,136,80,back,ic='arrow');label(section,264,48,1100);text('TITLE',title,264,88,1160,52,'text','700')
 btn('전체 메뉴',1632,48,192,80,'MENU08 / AllMenus');line(96,166)
 return cur

def lobby():
 new('SCR_03_Lobby','FOREST ARENA','character-room','숲의 아레나',footer=False)
 # Lobby hero leaves an open centre and two asymmetric information anchors.
 cur['elements']=[e for e in cur['elements'] if e['name'] not in ['BUTTON / 뒤로','BUTTON / 전체 메뉴']]
 
 for e in cur['elements']:
  if e['name'] in ['TITLE','EYEBROW']:e['w']=968
 btn('프로필',1320,48,240,80,'SCR_24_Profile',ic='people');btn('설정',1584,48,240,80,'EXT_06_GeneralSettings',ic='gear')
 label('함께 숲으로',96,240);text('LOBBY / invitation','오늘의 전투를\n준비하세요.',96,288,720,56,'text','700')
 line(96,480,400);text('LOBBY / caption','동료와 장신구를 조합해\n나만의 흐름을 만듭니다.',96,512,544,32,'muted')
 art('myo-ryung',552,176,840,732)
 rect('LOADOUT / accent',1392,304,432,4,'gold');label('현재 편성',1392,336,432)
 text('LOADOUT / name','묘령',1392,392,432,52,'text','700');text('LOADOUT / role','기동 · 공중 선점',1392,472,432,32,'gold')
 line(1392,544,432);icon('armor',1392,576,80);text('LOADOUT / item','철갑옷',1496,588,320,32);btn('편성 변경',1392,704,432,80,'SCR_08_Preset')
 btn('전체 메뉴',96,744,248,80,'MENU08 / AllMenus');text('LOBBY / browse','도감 · 랭크 · 내 기록',96,840,496,28,'muted')
 rect('LOBBY / navigation base',0,920,1920,160,'black',.97);line(96,920,1728)
 for i,(t,k,d) in enumerate([('캐릭터','people','SCR_04_CharacterCollection'),('장신구','armor','SCR_06_AccessoryCollection'),('프리셋','book','SCR_08_Preset'),('미션','leaf','SCR_21_Mission'),('친구','mail','SCR_22_Social'),('상점','balance','SCR_19_Shop')]):btn(t,96+i*208,952,192,80,d,ic=k)
 btn('플레이',1392,944,432,88,'SCR_09_ModeSelect','primary',ic='play')

def character(idx=0,detail=False,tab=0,fil='전체'):
 base='SCR_05_CharacterDetail' if detail else 'SCR_04_CharacterCollection'
 if not detail and fil!='전체':idx={'균형':0,'기동':1,'근접':2,'견제':3}[fil]
 name=base if idx==0 and tab==0 and fil=='전체' else nm(base,f'char-{idx}-tab-{tab}-filter-{fil}')
 cid,n,role,trait,story=CHARS[idx]
 new(name,'캐릭터 상세' if detail else '캐릭터','character-room','동료의 방 / CHARACTER',('SCR_04_CharacterCollection' if fil=='전체' and idx==0 else nm('SCR_04_CharacterCollection',f'char-{idx}-tab-0-filter-{fil}')) if detail else 'SCR_03_Lobby')
 if detail:
  # Narrow portrait rail, large illustration, editorial right information.
  for i,it in enumerate(CHARS):
   y=216+i*168;panel('ROSTER / '+it[1],96,y,144,144,i==idx);art(it[0],104,y+8,128,128);hot(it[1],96,y,144,144,'SCR_05_CharacterDetail' if i==0 else nm(base,f'char-{i}-tab-0-filter-전체'))
  art(cid,264,184,856,744);rect('INFO / glass',1152,184,672,736,'bg',.92)
  label(role+' / CHARACTER',1192,216,592);text('CHARACTER / name',n,1192,256,592,56,'text','700');text('CHARACTER / identity',trait,1192,344,592,32,'gold')
  ds=[base if idx==0 and fil=='전체' else nm(base,f'char-{idx}-tab-0-filter-{fil}'),nm(base,f'char-{idx}-tab-1-filter-{fil}'),nm(base,f'char-{idx}-tab-2-filter-{fil}')]
  tabs(['특징','기술','이야기'],1192,416,592,tab,ds)
  if tab==0:
   text('CHARACTER / heading','전투의 방향',1192,536,592,36,'text','700');text('CHARACTER / description',trait+'을\n지향하는 동료입니다.\n\n기술 입력과 움직임은\n연습장에서 확인하세요.',1192,600,592,32,'muted')
  elif tab==1:
   text('CHARACTER / heading','입력과 연속 공격',1192,536,592,36,'text','700');text('CHARACTER / description','지상 · 공중 · 방향 입력으로\n공격을 바꿀 수 있습니다.\n\n장신구에 따라 기술 목록이\n바뀔 수 있습니다.',1192,600,592,32,'muted')
  else:text('CHARACTER / heading','숲에서 만난 동료',1192,536,592,36,'text','700');text('CHARACTER / description',story,1192,600,592,32,'muted')
  btn('연습하기',1192,952,272,80,'EXT_05_PracticeSetup');btn('편성에 넣기',1488,952,336,80,'SCR_08_Preset','primary');note('보유한 캐릭터만 편성할 수 있습니다.')
 else:
  tabs(['전체','균형','기동','근접','견제'],96,200,1008,['전체','균형','기동','근접','견제'].index(fil),[base,nm(base,'char-0-tab-0-filter-균형'),nm(base,'char-1-tab-0-filter-기동'),nm(base,'char-2-tab-0-filter-근접'),nm(base,'char-3-tab-0-filter-견제')])
  shown=[i for i in range(4) if fil=='전체' or CHARS[i][2]==fil]
  for pos,i in enumerate(shown):
   k,cn,r,tr,st=CHARS[i];x=96+(pos%2)*512;y=304+(pos//2)*312
   panel('GALLERY / '+cn,x,y,488,288,i==idx);art(k,x+8,y+8,264,272)
   text('GALLERY / name',cn,x+280,y+40,192,38,'text','700');text('GALLERY / role',r,x+280,y+108,192,30,'gold');text('GALLERY / owned','✓ 보유',x+280,y+176,192,28,'muted')
   hot(cn,x,y,488,288,base if i==0 and fil=='전체' else nm(base,f'char-{i}-tab-0-filter-{fil}'))
  label('SELECTED CHARACTER',1192,216,632);text('GALLERY / focus name',n,1192,264,632,56,'text','700');text('GALLERY / focus trait',trait,1192,352,632,32,'gold')
  art(cid,1192,392,632,416);line(1192,824,632);text('GALLERY / hint','원화와 기술을 자세히 살펴보세요.',1192,856,632,30,'muted')
  btn('상세 보기',1192,952,632,80,'SCR_05_CharacterDetail' if idx==0 and fil=='전체' else nm('SCR_05_CharacterDetail',f'char-{idx}-tab-0-filter-{fil}'),'primary');note('캐릭터 목록 / 보유 상태와 역할로 탐색')
 return name

def shop(cat='추천'):
 base='SCR_19_Shop';name=base if cat=='추천' else nm(base,'category-'+cat)
 new(name,'상점','shop-market','숲의 교역소 / SHOP')
 for i,(t,k) in enumerate([('추천','leaf'),('장신구','armor'),('캐릭터','people')]):btn(t,96,200+i*104,248,80,base if i==0 else nm(base,'category-'+t),'selected' if cat==t else 'ghost',ic=k)
 line(96,568,248);label('개발용 상점',96,600,248);text('SHOP / policy','현재 상품은\n0원에 획득합니다.',96,656,248,30,'muted');btn('보유 도감',96,824,248,80,'SCR_20_Collection')
 start=304
 if cat=='추천':
  rect('SHOP / feature',392,200,1432,296,'bg',.76);rect('SHOP / feature accent',392,200,4,296,'gold');art('myo-ryung',1200,192,536,312)
  label('FOREST COMPANIONS',424,224,800);text('SHOP / hero','새로운 동료, 새로운 움직임',424,272,1008,48,'text','700');text('SHOP / introduction','전투 방식을 살펴보고 내 편성을 넓혀보세요.',424,352,960,32,'muted');btn('캐릭터 보기',424,408,280,72,nm(base,'category-캐릭터'),'primary');start=528
 else:label('CHARACTERS' if cat=='캐릭터' else 'ACCESSORIES',392,216,1100)
 entries=CHARS if cat=='캐릭터' else ITEMS
 for i,it in enumerate(entries[:4 if cat=='추천' else 6]):
  x=392+(i%4)*364;y=start+(i//4)*296;panel('PRODUCT / '+it[1],x,y,340,272)
  if cat=='캐릭터':art(it[0],x+76,y+8,188,168)
  else:icon(it[4],x+106,y+16,128)
  text('PRODUCT / name',it[1],x+24,y+168,292,32,'text','700');text('PRODUCT / acquisition','보유 중' if cat=='캐릭터' or i==0 else '0원 · 획득 가능',x+24,y+224,292,28,'muted' if cat=='캐릭터' or i==0 else 'gold')
  dest=nm(base,('character-' if cat=='캐릭터' else 'detail-')+str(i));hot(it[1],x,y,340,272,dest)
 note('확인 창에서 상품과 보유 상태를 확인한 뒤 획득합니다.')

def settings(tab='소리',changed=False):
 base='EXT_06_GeneralSettings';name=base if tab=='소리' and not changed else nm(base,tab+('-off' if changed else ''))
 clean=base if tab=='소리' else nm(base,tab)
 new(name,'설정','archive','편안한 플레이 / SETTINGS')
 for e in cur['elements']:
  if e['name']=='BUTTON / 뒤로' and changed:e['dest']=nm(base,'discard-'+tab+'-to-로비')
 for i,(t,k) in enumerate([('소리','focus'),('화면 효과','leaf'),('접근성','people'),('미니맵','book'),('조작','gear')]):
  dest='MENU08 / ControlsFromLobby' if t=='조작' else (base if t=='소리' else nm(base,t))
  if changed and t!=tab:dest=nm(base,'discard-'+tab+'-to-'+t)
  btn(t,96,200+i*112,304,88,dest,'selected' if t==tab else 'ghost',ic=k)
 label('PREFERENCES',472,208,1200);text('SETTINGS / category',tab+' 설정',472,248,1200,48,'text','700');line(472,328,1352)
 data={'소리':[('음악 음량','숲의 분위기를 만드는 배경 음악입니다.','slider'),('효과음 음량','공격과 메뉴 동작의 소리를 조절합니다.','slider'),('전체 음소거','음악과 효과음을 함께 끕니다.','toggle')],'화면 효과':[('피격 번쩍임 줄이기','밝은 피격 효과가 불편하면 켜세요.','toggle')],'접근성':[('텍스트 크기','큰 글자는 스크롤로 모두 읽을 수 있습니다.','font'),('진동 피드백','터치와 피격의 진동을 선택합니다.','toggle')],'미니맵':[('미니맵 투명도','전투 화면과 겹치는 정도를 조절합니다.','map-slider'),('캐릭터 표시','얼굴 또는 점으로 위치를 표시합니다.','marker'),('미니맵 이름 표시','표시 아이콘 옆에 이름을 함께 보여줍니다.','toggle')]}
 dest=nm(base,tab+'-off') if not changed else clean
 for i,(t,d,kind) in enumerate(data[tab]):
  y=368+i*144;text('SETTING / '+t,t,472,y,824,34,'text','700');text('SETTING / description',d,472,y+64,872,30,'muted')
  if kind in ['slider','map-slider']:
   value=('40%' if changed else '70%') if kind=='slider' else ('50%' if changed else '20%')
   text('SETTING / value',value,1536,y-8,248,32,'gold','500','right');rect('SLIDER / track',1432,y+64,352,8,'line');rect('SLIDER / value',1432,y+64,144 if changed else 248,8,'mint');rect('SLIDER / thumb',1560 if changed else 1664,y+44,40,48,'gold',r=8);hot(t,1408,y+32,416,88,dest)
  elif kind=='font':
   tabs(['기본','크게','최대'],1376,y,448,1 if changed else 0,[clean,nm(base,tab+'-off'),nm(base,'접근성-large')])
   text('SETTING / font scales','1.0× / 1.15× / 1.3×',1376,y+88,448,26,'muted')
  elif kind=='marker':tabs(['얼굴','점'],1488,y,336,int(changed),[clean,nm(base,tab+'-off')])
  else:btn(('켬' if changed else '끔') if t in ['전체 음소거','피격 번쩍임 줄이기'] else ('끔' if changed else '켬'),1568,y,256,80,dest,'selected' if changed else 'ghost')
 if tab=='화면 효과':
  icon('leaf',1440,544,176);text('SETTINGS / effect help','피격 상태와 위험 안내는\n글자와 아이콘으로도 확인합니다.',472,600,824,32,'muted')
 line(472,832,1352);text('SETTINGS / save state','저장하지 않은 변경 사항이 있습니다.' if changed else '현재 설정이 적용되어 있습니다.',472,856,1312,30,'gold' if changed else 'muted')
 btn('기본값 복원',96,952,304,80,nm(base,'reset-'+tab));btn('취소',1320,952,224,80,nm(base,'discard-'+tab+'-to-로비') if changed else 'SCR_03_Lobby');btn('적용',1568,952,256,80,nm(base,'applied-'+tab) if changed else None,'primary' if changed else 'disabled')
 return name

# Four representative screens are built first and can be consumed independently.
lobby();character(detail=True);shop();settings()

# Remaining base scenes and variants.
for i in range(4):character(i)
for i,fil in enumerate(['균형','기동','근접','견제']):character(i,fil=fil)
for i in range(4):
 for tab in range(3):
  if not (i==0 and tab==0):character(i,True,tab)
for i,fil in enumerate(['균형','기동','근접','견제']):
 for tab in range(3):character(i,True,tab,fil)
for cat in ['장신구','캐릭터']:shop(cat)
for t in ['소리','화면 효과','접근성','미니맵']:
 for changed in [False,True]:
  if t!='소리' or changed:settings(t,changed)

def accessories(idx=0,detail=False,cat='전체'):
 base='SCR_07_AccessoryDetail' if detail else 'SCR_06_AccessoryCollection'
 name=base if idx==0 and cat=='전체' else nm(base,f'item-{idx}-filter-{cat}')
 if cat!='전체' and ITEMS[idx][2]!=cat:idx=next(i for i,it in enumerate(ITEMS) if it[2]==cat)
 iid,n,c,desc,ic=ITEMS[idx];new(name,'장신구 상세' if detail else '장신구','accessory-workshop','숲의 공방 / ACCESSORY','SCR_06_AccessoryCollection' if detail else 'SCR_03_Lobby')
 if not detail:
  tabs(['전체','이동','방어','기술'],96,200,1728,['전체','이동','방어','기술'].index(cat),[base]+[nm(base,'item-0-filter-'+t) for t in ['이동','방어','기술']])
  shown=[i for i,it in enumerate(ITEMS) if cat=='전체' or it[2]==cat]
  for pos,i in enumerate(shown):
   it=ITEMS[i];x=96+(pos%4)*440;y=304+(pos//4)*296;panel('DISPLAY / '+it[1],x,y,408,272,i==idx);icon(it[4],x+140,y+16,128)
   text('DISPLAY / name',it[1],x+24,y+160,360,34,'text','700');text('DISPLAY / state',('✓ 장착 중' if i==0 else '미보유')+' / '+it[2],x+24,y+224,360,28,'gold' if i==0 else 'muted');hot(it[1],x,y,408,272,nm(base,f'item-{i}-filter-전체') if i else base)
  note('선택한 장신구 / '+n,96,952,920);text('DISPLAY / selected effect',desc.replace('\n',' · '),96,992,1200,26,'muted');btn('상세 · 비교',1392,952,432,80,'SCR_07_AccessoryDetail' if idx==0 else nm('SCR_07_AccessoryDetail',f'item-{idx}-filter-전체'),'primary')
 else:
  rect('ITEM / exhibition',96,200,744,704,'bg',.62);label('ACCESSORY / '+c,136,232,624);icon(ic,304,328,328);text('ITEM / title',n,136,728,664,52,'text','700');text('ITEM / status','✓ 보유 · 현재 장착 중' if idx==0 else '미보유 · 상점에서 획득 가능',136,816,664,30,'gold')
  label('선택의 차이',904,216,920);text('ITEM / effects heading','효과와 장단점',904,264,920,48,'text','700');text('ITEM / effect',desc,904,352,920,34)
  line(904,496,920);text('ITEM / comparison heading','현재 장착 / 철갑옷',904,528,920,34,'text','700');text('ITEM / comparison','무게 +5% · 지상 속도 −5%',904,592,920,32,'muted')
  line(904,680,920);text('ITEM / compatibility','이동 방식과 기술에 맞춰 선택하세요.\n장신구는 강점과 제약을 함께 가집니다.',904,720,920,32,'muted')
  btn('연습하기',1192,952,272,80,'EXT_05_PracticeSetup');btn('장착 중' if idx==0 else '상점에서 획득',1488,952,336,80,'SCR_08_Preset' if idx==0 else nm('SCR_19_Shop','detail-'+str(idx)),'selected' if idx==0 else 'primary');note('보유한 장신구만 장착할 수 있습니다.')
for i in range(6):accessories(i);accessories(i,True)
for c in ['이동','방어','기술']:accessories(cat=c)

def preset(idx=0):
 base='SCR_08_Preset';name=base if idx==0 else nm(base,f'slot-{idx}');new(name,'전투 편성','character-room','나의 편성 / PRESET')
 for i in range(4):
  y=200+i*176;panel('PRESET / slot '+str(i+1),96,y,432,152,i==idx);text('PRESET / number',f'0{i+1}',120,y+24,96,44,'gold','700');text('PRESET / state','사용 중' if i==0 else '빈 슬롯',240,y+36,264,34,'text','700');text('PRESET / summary','묘령 · 철갑옷' if i==0 else '새 편성을 저장하세요.',120,y+100,376,26,'muted');hot('편성 '+str(i+1),96,y,432,152,base if i==0 else nm(base,f'slot-{i}'))
 if idx==0:art('myo-ryung',560,208,608,688)
 else:
  icon('people',752,384,208);text('PRESET / empty','동료를 기다리는 편성',568,672,584,38,'muted','500','center')
 label('LOADOUT '+f'{idx+1:02}',1216,216,608);text('PRESET / selected title','현재 사용하는 편성' if idx==0 else '새로운 전투 편성',1216,264,608,48,'text','700')
 for pos,(t,v,d,k) in enumerate([('캐릭터','묘령' if idx==0 else '선택하세요.','SCR_04_CharacterCollection','people'),('직업','기본 전투 스타일' if idx==0 else '캐릭터 선택 후 표시',None,'book'),('장신구','철갑옷' if idx==0 else '선택하세요.','SCR_06_AccessoryCollection','armor')]):
  y=392+pos*152;icon(k,1216,y+16,72);label(t,1312,y,456);text('PRESET / value',v,1312,y+48,456,34);line(1216,y+128,608)
  if d:hot('편성 편집 '+t,1216,y,608,128,d)
 btn('저장',1192,952,272,80,'MENU08 / PresetSaved' if idx==0 else 'MENU08 / SelectionRequired');btn('편성 적용',1488,952,336,80,'MENU08 / PresetApplied' if idx==0 else 'MENU08 / SelectionRequired','primary');note('저장은 슬롯에 보관하고, 적용은 현재 편성을 바꿉니다.')
for i in range(4):preset(i)

def collection(accessory=False,unowned=False):
 base='SCR_20_Collection';name=base if not accessory and not unowned else nm(base,'accessory-unowned' if accessory and unowned else 'accessory' if accessory else 'unowned')
 new(name,'도감','archive','숲의 기록실 / COLLECTION');tabs(['캐릭터','장신구'],96,200,824,int(accessory),[nm(base,'unowned') if unowned else base,nm(base,'accessory-unowned' if unowned else 'accessory')]);tabs(['보유','미보유'],1232,200,592,int(unowned),[nm(base,'accessory') if accessory else base,nm(base,'accessory-unowned' if accessory else 'unowned')])
 entries=ITEMS if accessory else CHARS
 if unowned and not accessory:
  icon('book',832,376,208);text('COLLECTION / empty','미보유 캐릭터가 없습니다.',520,648,880,44,'text','700','center');text('COLLECTION / empty note','보유 목록에서 동료의 특징을 살펴보세요.',520,728,880,32,'muted','500','center');btn('보유 목록',784,824,352,80,base,'primary')
 else:
  for pos,(i,it) in enumerate([(i,it) for i,it in enumerate(entries) if not accessory or (unowned and i>0) or (not unowned and i==0)]):
   x=96+(pos%4)*440;y=312+(pos//4)*296;panel('CODEX / '+it[1],x,y,408,272)
   if accessory:icon(it[4],x+140,y+8,144)
   else:art(it[0],x+24,y+8,184,248)
   tx=x+24 if accessory else x+224;text('CODEX / name',it[1],tx,y+164 if accessory else y+56,360 if accessory else 160,32,'text','700');text('CODEX / state','미보유' if unowned else '✓ 보유',tx,y+224 if accessory else y+128,360 if accessory else 160,28,'mint')
   d=nm(base,('accessory-' if accessory else 'character-')+str(i));hot(it[1],x,y,408,272,d)
 note('도감은 읽기 전용입니다. 편성 변경은 캐릭터·장신구 메뉴에서 진행합니다.')
collection();collection(True);collection(False,True);collection(True,True)

def mission(tab=0):
 base='SCR_21_Mission';name=base if tab==0 else nm(base,f'tab-{tab}');new(name,'미션','archive','숲의 작은 목표 / MISSION')
 tabs(['일일','주간','누적'],96,200,1040,tab,[base,nm(base,'tab-1'),nm(base,'tab-2')]);label('LOCAL RECORD / 로컬 기록',1200,208,624)
 rows=[[('하루 한 경기 완료',1),('하루 첫 승리',1)],[('한 주에 다섯 경기 완료',5),('한 주에 세 번 승리',3)],[('첫 경기 완료',1),('열 경기 완료',10),('네 캐릭터로 경기 완료',4)]][tab]
 for i,(t,goal) in enumerate(rows):
  y=312+i*192;panel('MISSION / '+t,96,y,1040,168,i==0);text('MISSION / title',t,128,y+24,816,34,'text','700');text('MISSION / progress',f'0 / {goal}',944,y+24,152,32,'gold','500','right');rect('PROGRESS / track',128,y+112,968,8,'line');hot(t,96,y,1040,168,nm(base,f'detail-{i}') if tab==0 else nm(base,f'tab-{tab}-detail-{i}'))
 text('MISSION / focus','한 판씩 쌓이는 경험',1200,272,624,48,'text','700');line(1200,360,624);text('MISSION / explanation','완료한 경기의 기록으로\n진행도를 확인합니다.\n\n연습 · Story · 포기는\n미션 진행에 포함하지 않습니다.',1200,408,624,32,'muted')
 line(1200,712,624);text('MISSION / boundary','일일 · 한국 시간 자정\n주간 · 한국 시간 월요일',1200,752,624,30,'muted');note('진행 수치는 신규 로컬 기록 예시입니다. 미션 보상은 없습니다.');btn('진행 정보',1504,952,320,80,'MENU08 / MissionHelp')
for i in range(3):mission(i)

def social(recent=False,selected=0,requests=False):
 base='SCR_22_Social';name=nm(base,'requests') if requests else base if not recent and selected==0 else nm(base,'recent' if recent else f'friend-{selected}')
 new(name,'친구','social-lodge','동료의 쉼터 / SOCIAL');tabs(['친구','받은 요청','최근 LAN'],96,200,1040,1 if requests else 2 if recent else 0,[base,nm(base,'requests'),nm(base,'recent')]);btn('친구 찾기',1200,200,624,80,nm(base,'search-empty'),ic='people')
 # Realistic empty account state; alternate populated rows are explicitly marked review samples.
 label('계정 연결 전',96,336,1008);text('FRIENDS / empty title','함께할 동료를 찾아보세요.',96,392,1008,48,'text','700');text('FRIENDS / empty description','친구 목록은 계정 연결 후 확인할 수 있습니다.\n이름을 정확하게 입력해 친구를 찾을 수 있습니다.',96,488,1008,32,'muted');btn('계정 연결',96,664,336,80,'MENU08 / AccountLink','primary');btn('다시 조회',456,664,280,80,nm(base,'connection-error'))
 rect('SOCIAL / side',1160,312,664,592,'bg',.86);icon('people',1400,352,176);text('SOCIAL / focus','친구 요청' if requests else '최근 LAN 상대' if recent else '친구와 함께',1200,584,584,44,'text','700');text('SOCIAL / explanation','요청을 수락하거나 거절하면\n목록에 결과가 표시됩니다.' if requests else '함께 완료한 LAN 경기의\n상대를 여기서 확인합니다.' if recent else '접속 상태와 선택 프로필을\n한곳에서 확인하세요.\n실제 LAN 호스트 대기방에서\n친구를 초대할 수 있습니다.',1200,672,584,32,'muted')
 if selected:label('선택 프로필 / 검토 상태 '+str(selected),96,824,1008);btn('선택 프로필 보기',1200,824,584,72,'MENU08 / FriendProfile')
 note('접속 여부·친구 요청·초대 상태는 실제 서버 응답을 표시합니다.')
for i in range(3):social(False,i)
social(True);social(requests=True)

def rank(fil=0):
 base='SCR_23_Rank';name=base if fil==0 else nm(base,'filter-'+str(fil));new(name,'랭크','observatory','숲의 전망대 / RANK')
 tabs(['전체','이번 달','친구'],96,200,1216,fil,[base,nm(base,'filter-1'),nm(base,'filter-2')]);btn('다시 조회',1504,200,320,72,'MENU08 / RankLoading')
 label('NORMAL LAN MATCHES',96,328,1200);text('RANK / headline','완료한 대전의 기록',96,384,1216,48,'text','700');line(96,480,1216)
 for t,x,w in [('순위',120,144),('플레이어',320,608),('완료 경기',1024,264)]:text('RANK / column',t,x,512,w,30,'muted')
 line(96,576,1216);icon('crown',568,632,144);text('RANK / empty','아직 표시할 순위가 없습니다.',232,816,944,38,'muted','500','center')
 rect('RANK / personal',1360,328,464,576,'bg',.86);label('MY RANK',1392,368,400);text('RANK / self','순위 없음',1392,432,400,48,'text','700');text('RANK / count','완료 경기 0',1392,520,400,32,'gold');line(1392,600,400);text('RANK / eligibility','정상 완료한 LAN 경기만\n서버가 집계합니다.\n\n오프라인 경기는\n순위에 포함하지 않습니다.',1392,640,400,30,'muted')
 note('신규 계정의 빈 순위 예시 / 이번 달은 한국 시간을 기준으로 구분합니다.')
rank();rank(1);rank(2)

def profile():
 new('SCR_24_Profile','프로필','observatory','나의 여정 / PROFILE');art('myo-ryung',96,184,680,736)
 label('PLAYER PROFILE',824,208,1000);text('PROFILE / name','숲의 여행자',824,256,704,56,'text','700');btn('닉네임 변경',1568,264,256,72,'MENU08 / NicknameEdit');text('PROFILE / binding','로컬 기록 · 계정 미연결',824,344,1000,30,'gold');line(824,416,1000)
 label('현재 편성',824,448,1000);text('PROFILE / loadout','묘령 / 기본 전투 스타일 / 철갑옷',824,496,1000,34);btn('편성 보기',1568,568,256,72,'SCR_08_Preset')
 tabs(['오프라인','LAN'],824,568,704,0,['SCR_24_Profile','MENU08 / ProfileLAN'])
 for i,(t,v) in enumerate([('완료 경기','0'),('승리','0'),('보유 캐릭터','4')]):
  x=824+i*336;text('PROFILE / stat value',v,x,696,312,52,'text','700');text('PROFILE / stat label',t,x,776,312,30,'muted')
 line(824,856,1000);text('PROFILE / record type','AI · Solo · Team별 기록과 최근 완료 기록',824,880,1000,28,'muted');note('신규 로컬 프로필 예시 / 계정 연결 전에도 기기 기록을 확인합니다.');btn('계정 연결',1504,952,320,80,'MENU08 / AccountLink','primary')
profile()

def controls(floating=False,lobby=False):
 base='CBT_08_Settings';name=('MENU08 / ControlsFloatingFromLobby' if floating else 'MENU08 / ControlsFromLobby') if lobby else nm(base,'floating') if floating else base
 back='EXT_06_GeneralSettings' if lobby else 'CBT_05_Pause';new(name,'조작 설정','archive','손에 맞는 플레이 / CONTROLS',back)
 label('TOUCH PREVIEW',96,208,944);text('CONTROLS / title','손에 익은 위치, 편안한 조작',96,256,1032,44,'text','700')
 rect('CONTROLS / preview',96,352,1032,512,'bg',.84,4,'line');text('CONTROLS / preview state','플로팅 / 첫 터치에서 시작' if floating else '고정 / 같은 위치에서 시작',128,384,968,30,'mint')
 add('circle','JOYSTICK / ring',160,536,232,232,color=C['line']);add('circle','JOYSTICK / inset',184,560,184,184,color=C['panel']);icon('leaf',240,616,72)
 for k,x,y,z in [('armor',904,504,88),('focus',992,632,88),('play',856,704,104),('jump',760,632,88)]:icon(k,x,y,z)
 rect('CONTROLS / split',1168,200,1,704,'line');label('INPUT PREFERENCES',1208,208,616);text('CONTROLS / mode title','방향 조이스틱',1208,256,616,38,'text','700')
 fixed='MENU08 / ControlsFromLobby' if lobby else base;floatdest='MENU08 / ControlsFloatingFromLobby' if lobby else nm(base,'floating');tabs(['고정','플로팅'],1208,328,616,int(floating),[fixed,floatdest])
 text('CONTROLS / mode help','왼쪽 예약 영역의 첫 터치에서 시작하며\n손을 떼면 조이스틱이 숨겨집니다.' if floating else '손을 떼면 손잡이가 중앙으로 돌아옵니다.\n조이스틱의 시작 위치는 유지됩니다.',1208,432,616,30,'muted')
 for i,(t,v) in enumerate([('버튼 크기','100%'),('버튼 투명도','0%')]):
  y=584+i*152;text('CONTROLS / parameter',t,1208,y,400,32,'text','700');text('CONTROLS / value',v,1624,y,200,32,'gold','500','right');rect('SLIDER / track',1208,y+72,616,8,'line');rect('SLIDER / thumb',1208,y+52,40,48,'gold',r=8);hot(t,1208,y+40,616,88,'MENU08 / ControlsParametersLobby' if lobby else 'MENU08 / ControlsParameters')
 btn('기본값 복원',96,952,304,80,'MENU08 / SettingsResetLobbyControls' if lobby else 'MENU08 / SettingsReset');btn('취소',1320,952,224,80,back);btn('적용',1568,952,256,80,back,'primary');note('크기 100–120% · 투명도 0–50%',432,988,848)
for fl in [False,True]:
 for lo in [False,True]:controls(fl,lo)

def overlay(name,under,title,msg,actions,ic='leaf'):
 global cur
 cur=deepcopy(S[under]);cur.update(name=name,target=False,overlay=True);S[name]=cur
 rect('MODAL / scrim',0,0,1920,1080,'black',.86);rect('MODAL / body',456,248,1008,592,'panel',1,4,'line');rect('MODAL / accent',456,248,1008,4,'gold');icon(ic,504,296,80);text('MODAL / title',title,616,304,800,44,'text','700');text('MODAL / message',msg,504,432,912,32,'muted')
 for i,(t,d,st) in enumerate(actions):btn(t,504+i*468,712,444,80,d,st)
for i,it in enumerate(ITEMS):overlay(nm('SCR_19_Shop',f'detail-{i}'),'SCR_19_Shop',it[1],it[3]+'\n\n'+('이미 보유한 상품입니다.' if i==0 else '개발용 무료 상품 · 가격 0원\n보유 목록에 추가할까요?'),[('닫기','SCR_19_Shop','ghost'),('보유 도감','SCR_20_Collection','selected') if i==0 else ('0원 · 획득 확인','MENU08 / ShopAcquired','primary')],it[4])
for i,it in enumerate(CHARS):overlay(nm('SCR_19_Shop',f'character-{i}'),nm('SCR_19_Shop','category-캐릭터'),it[1],it[3]+'\n\n보유한 캐릭터입니다.\n캐릭터 메뉴에서 편성할 수 있습니다.',[('닫기',nm('SCR_19_Shop','category-캐릭터'),'ghost'),('캐릭터 보기','SCR_04_CharacterCollection','primary')],'people')
for i,(t,g) in enumerate([('하루 한 경기 완료',1),('하루 첫 승리',1),('네 캐릭터로 경기 완료',4)]):overlay(nm('SCR_21_Mission',f'detail-{i}'),'SCR_21_Mission',t,f'진행 0 / {g} · 미완료\n\n완료한 실제 경기로 진행합니다.\n연습 · Story · 포기는 제외하며 보상은 없습니다.',[('닫기','SCR_21_Mission','ghost'),('미션 목록','SCR_21_Mission','primary')],'book')
POPUPS=[
('SettingsReset','CBT_08_Settings','조작 설정을 복원할까요?','고정 조이스틱 · 크기 100% · 투명도 0%로\n되돌립니다. 복원 후 적용 버튼으로 저장하세요.','CBT_08_Settings','복원','gear'),
('ControlsParameters','CBT_08_Settings','조작 크기와 투명도','버튼 크기는 100–120%, 투명도는 0–50%입니다.\n터치 영역도 표시 크기에 맞춰 함께 조절됩니다.','CBT_08_Settings','확인','gear'),
('SettingsResetLobbyControls','MENU08 / ControlsFromLobby','조작 설정을 복원할까요?','고정 조이스틱 · 크기 100% · 투명도 0%로\n되돌립니다. 복원 후 적용 버튼으로 저장하세요.','MENU08 / ControlsFromLobby','복원','gear'),
('ControlsParametersLobby','MENU08 / ControlsFromLobby','조작 크기와 투명도','버튼 크기는 100–120%, 투명도는 0–50%입니다.\n터치 영역도 표시 크기에 맞춰 함께 조절됩니다.','MENU08 / ControlsFromLobby','확인','gear'),
('SettingsResetGeneral','EXT_06_GeneralSettings','이 분류의 기본값을 복원할까요?','현재 설정 분류의 값을 기본값으로 되돌립니다.\n복원 후 적용 버튼으로 저장하세요.','EXT_06_GeneralSettings','복원','gear'),
('SettingsDiscard',nm('EXT_06_GeneralSettings','소리-off'),'변경 내용을 버릴까요?','아직 적용하지 않은 설정이 있습니다.\n취소하면 현재 화면에서 계속 조절할 수 있습니다.','SCR_03_Lobby','변경 버리기','gear'),
('SettingsApplied','EXT_06_GeneralSettings','설정을 적용했습니다.','선택한 분류의 설정이 저장되었습니다.\n설정 화면에서 계속 조절할 수 있습니다.','EXT_06_GeneralSettings','확인','check'),
('EmptyList','SCR_20_Collection','표시할 항목이 없습니다.','다른 분류나 보유 상태를 선택해 보세요.\n목록이 비어 있어도 뒤로 돌아갈 수 있습니다.','SCR_20_Collection','전체 보기','book'),
('SelectionRequired',nm('SCR_08_Preset','slot-1'),'캐릭터를 먼저 선택하세요.','빈 편성에는 캐릭터가 필요합니다.\n보유한 캐릭터를 선택한 뒤 저장해 주세요.','SCR_04_CharacterCollection','캐릭터 선택','people'),
('PresetSaved','SCR_08_Preset','편성을 저장했습니다.','슬롯에 편성이 저장되었습니다.\n현재 편성으로 쓰려면 적용을 선택하세요.','SCR_08_Preset','편성으로','check'),
('PresetApplied','SCR_08_Preset','현재 편성을 바꿨습니다.','선택한 편성의 캐릭터와 장신구가 적용되었습니다.\n로비에서 플레이를 준비할 수 있습니다.','SCR_03_Lobby','로비로','check'),
('ShopAcquired','SCR_19_Shop','보유 목록에 추가했습니다.','획득한 장신구를 도감에서 확인하거나\n장신구 메뉴에서 편성에 적용하세요.','SCR_06_AccessoryCollection','장신구 보기','check'),
('MissionHelp','SCR_21_Mission','진행도 안내','완료한 실제 경기의 기록을 읽습니다.\n서버 자료는 조회 시각과 연결 상태를 함께 표시합니다.\n미션 보상은 없습니다.','SCR_21_Mission','확인','book'),
('AccountLink','SCR_24_Profile','계정을 연결하세요.','연결한 서버의 계정으로 친구와 LAN 기록을 봅니다.\n다른 서비스의 계정은 자동으로 합치지 않습니다.\n진행 중인 LAN 방이 있다면 먼저 닫아 주세요.','SCR_24_Profile','프로필로','people'),
('NicknameEdit','SCR_24_Profile','닉네임 변경','현재 닉네임 / 숲의 여행자\n입력한 이름은 확인 후 저장합니다.\nLAN 방이 열려 있으면 변경할 수 없습니다.','SCR_24_Profile','변경 확인','people'),
('ProfileLAN','SCR_24_Profile','LAN 전적','정상 완료한 LAN 경기와 최근 완료 기록을 봅니다.\n계정을 연결하면 서버의 기록을 조회합니다.\n오프라인 기록과 분리해 표시합니다.','SCR_24_Profile','프로필로','book'),
('FriendProfile','SCR_22_Social','선택한 플레이어','친구 프로필은 실제 조회 응답으로 표시합니다.\n접속 상태와 최근 갱신 시각을 함께 확인하세요.\n삭제·초대는 현재 상태에서 가능한 경우에만 표시합니다.','SCR_22_Social','친구 목록','people')]
for tag,under,title,msg,dest,confirm,ic in POPUPS:overlay('MENU08 / '+tag,under,title,msg,[('취소',under,'ghost'),(confirm,dest,'primary')],ic)
overlay(nm('SCR_22_Social','connection-error'),'SCR_22_Social','연결을 확인할 수 없습니다.','친구 목록을 새로 읽지 못했습니다.\n이전 자료가 있으면 조회 시각을 함께 표시합니다.\n연결을 확인한 뒤 다시 시도하세요.',[('닫기','SCR_22_Social','ghost'),('다시 조회','MENU08 / FriendsLoading','primary')],'people')
overlay(nm('SCR_22_Social','search-empty'),'SCR_22_Social','친구 찾기','닉네임을 정확하게 입력하세요.\n검색 결과가 없으면 이름을 다시 확인해 주세요.\n계정 연결 후 검색과 요청을 사용할 수 있습니다.',[('취소','SCR_22_Social','ghost'),('계정 연결','MENU08 / AccountLink','primary')],'people')
# Dedicated menu states; no shared battle state boards are modified.
for tag,under,title,msg in [
('FriendsLoading','SCR_22_Social','친구 목록을 읽고 있습니다.','잠시 기다려 주세요.\n화면을 나가면 친구 조회를 멈춥니다.'),
('RankLoading','SCR_23_Rank','순위를 읽고 있습니다.','서버가 집계한 정상 LAN 결과를 조회합니다.\n이전 자료를 표시하면 조회 시각을 함께 보여줍니다.'),
('MissionLoading','SCR_21_Mission','미션 진행을 읽고 있습니다.','기기 기록과 연결한 계정의 진행을 확인합니다.\n완료 전에는 새 진행 수치를 확정해 표시하지 않습니다.'),
('MissionStale','SCR_21_Mission','다시 연결해 주세요.','이전에 조회한 미션을 표시하고 있습니다.\n마지막 조회 · 이전 연결 시각\n다시 조회하면 현재 기간의 진행을 확인합니다.'),
('RankError','SCR_23_Rank','순위를 읽지 못했습니다.','연결 상태를 확인한 뒤 다시 조회해 주세요.\n연결이 돌아오면 최신 순위를 확인할 수 있습니다.'),
('EmptyFriends','SCR_22_Social','아직 등록한 친구가 없습니다.','친구의 닉네임을 정확하게 검색해 요청해 보세요.\n요청 수락 후 목록에 표시됩니다.')]:overlay('MENU08 / '+tag,under,title,msg,[('닫기',under,'ghost'),('돌아가기',under,'primary')],'book')
# Additional current-feature states. Example identities are visibly labeled; no runtime data is fabricated.
for tab in ['소리','화면 효과','접근성','미니맵']:
 base='EXT_06_GeneralSettings';clean=base if tab=='소리' else nm(base,tab);dirty=nm(base,tab+'-off')
 overlay(nm(base,'reset-'+tab),clean,tab+' 설정을 복원할까요?','이 분류의 값을 기본값으로 되돌립니다.\n복원한 값은 적용 버튼으로 저장합니다.',[('취소',clean,'ghost'),('기본값 복원',dirty,'primary')],'gear')
 overlay(nm(base,'applied-'+tab),clean,'설정을 적용했습니다.',tab+' 설정을 이 기기에 저장했습니다.',[('닫기',clean,'ghost'),('설정으로',clean,'primary')],'check')
 for target in ['로비','소리','화면 효과','접근성','미니맵','조작']:
  if target==tab:continue
  dest='SCR_03_Lobby' if target=='로비' else 'MENU08 / ControlsFromLobby' if target=='조작' else base if target=='소리' else nm(base,target)
  overlay(nm(base,'discard-'+tab+'-to-'+target),dirty,'변경 내용을 버릴까요?','아직 적용하지 않은 설정이 있습니다.\n계속 조절하려면 취소를 선택하세요.',[('취소',dirty,'ghost'),('변경 버리기',dest,'primary')],'gear')
cur=deepcopy(S[nm('EXT_06_GeneralSettings','접근성-off')]);cur.update(name=nm('EXT_06_GeneralSettings','접근성-large'));S[cur['name']]=cur
for e in cur['elements']:
 if e.get('text')=='크게':e['state']='ghost'
 if e.get('text')=='최대':e['state']='selected'
# Codex uses dedicated read-only details, never an equip button.
for accessory,entries in [(False,CHARS),(True,ITEMS)]:
 for i,it in enumerate(entries):
  under=nm('SCR_20_Collection','accessory') if accessory else 'SCR_20_Collection'
  overlay(nm('SCR_20_Collection',('accessory-' if accessory else 'character-')+str(i)),under,it[1],(it[3] if accessory else it[2]+' · '+it[3])+'\n\n'+('미보유 항목입니다.' if accessory and i>0 else '✓ 보유한 항목입니다.')+'\n편성 변경은 캐릭터·장신구 메뉴에서 진행하세요.',[('목록으로',under,'ghost'),('닫기',under,'primary')],it[4] if accessory else 'people')
for tab,rows in [(1,[('한 주에 다섯 경기 완료',5),('한 주에 세 번 승리',3)]),(2,[('첫 경기 완료',1),('열 경기 완료',10),('네 캐릭터로 경기 완료',4)])]:
 for i,(t,g) in enumerate(rows):
  under=nm('SCR_21_Mission',f'tab-{tab}')
  overlay(nm('SCR_21_Mission',f'tab-{tab}-detail-{i}'),under,t,f'진행 0 / {g} · 미완료\n\n완료한 실제 경기로 진행합니다.\n연습 · Story · 포기는 제외하며 보상은 없습니다.',[('닫기',under,'ghost'),('미션 목록',under,'primary')],'book')
# Preserve legacy detail-2 as an achievement detail with an accurate parent.
S[nm('SCR_21_Mission','detail-2')]=deepcopy(S[nm('SCR_21_Mission','tab-2-detail-2')]);S[nm('SCR_21_Mission','detail-2')]['name']=nm('SCR_21_Mission','detail-2')
for i in [1,2]:
 name=nm('SCR_22_Social',f'friend-{i}');new(name,'친구','social-lodge','동료의 쉼터 / SOCIAL')
 tabs(['친구','받은 요청','최근 LAN'],96,200,1040,0,['SCR_22_Social',nm('SCR_22_Social','requests'),nm('SCR_22_Social','recent')]);btn('친구 찾기',1200,200,624,80,nm('SCR_22_Social','search-empty'),ic='people')
 for j,(n,state) in enumerate([('동료 A · 예시','● 접속 중'),('동료 B · 예시','○ 오프라인')]):
  y=328+j*200;panel('FRIEND / row',96,y,1040,168,j==i-1);icon('people',128,y+40,88);text('FRIEND / name',n,256,y+24,720,36,'text','700');text('FRIEND / presence',state,256,y+96,720,30,'mint' if j==0 else 'muted');hot(n,96,y,1040,168,nm('SCR_22_Social',f'friend-{j+1}'))
 label('SELECTED PROFILE',1200,328,624);text('FRIEND / focus',f'동료 {"A" if i==1 else "B"} · 예시',1200,384,624,48,'text','700');text('FRIEND / status','● 접속 중' if i==1 else '○ 오프라인',1200,472,624,32,'mint' if i==1 else 'muted');line(1200,544,624);text('FRIEND / context','최근 확인 · 방금 전\n\nLAN 호스트 대기방에서\n친구를 초대할 수 있습니다.',1200,584,624,32,'muted');btn('프로필 보기',1200,792,296,80,'MENU08 / FriendProfile');btn('친구 삭제',1520,792,304,80,'MENU08 / FriendDelete');note('시안용 예시 계정입니다. 실제 친구·접속 자료가 아닙니다.')
 btn('LAN 초대',1504,952,320,80,'MENU08 / FriendInviteUnavailable')
overlay('MENU08 / FriendDelete',nm('SCR_22_Social','friend-1'),'친구에서 삭제할까요?','동료 A · 예시를 친구 목록에서 삭제합니다.\n삭제한 뒤 다시 요청을 보낼 수 있습니다.',[('취소',nm('SCR_22_Social','friend-1'),'ghost'),('삭제','MENU08 / EmptyFriends','primary')],'people')
overlay('MENU08 / FriendInviteUnavailable',nm('SCR_22_Social','friend-1'),'대기 중인 LAN 방이 필요합니다.','먼저 LAN 호스트 대기방을 열어 주세요.\n대기 중인 방에서만 친구를 초대할 수 있습니다.',[('닫기',nm('SCR_22_Social','friend-1'),'ghost'),('친구로',nm('SCR_22_Social','friend-1'),'primary')],'people')
overlay('MENU08 / FriendRequestResult','SCR_22_Social','친구 요청을 보낼까요?','닉네임 · 동료 A (시안 예시)\n이 플레이어에게 친구 요청을 보냅니다.',[('취소','SCR_22_Social','ghost'),('요청 보내기','MENU08 / FriendRequestSent','primary')],'people')
overlay('MENU08 / FriendRequestSent','SCR_22_Social','친구 요청을 보냈습니다.','상대가 수락하면 친구 목록에 표시됩니다.\n요청은 취소할 수 있습니다.',[('요청 취소','SCR_22_Social','ghost'),('친구 목록','SCR_22_Social','primary')],'check')
# Search fields stay editable Penpot text; the prototype uses a named result example.
cur=S[nm('SCR_22_Social','search-empty')];cur['elements']=[e for e in cur['elements'] if e['name']!='MODAL / message']
rect('INPUT / nickname',504,424,912,96,'bg',1,4,'line');text('INPUT / value','닉네임을 정확히 입력하세요.',536,448,848,32,'muted');text('SEARCH / hint','계정 연결 후 검색과 요청을 사용할 수 있습니다.',504,560,912,30,'muted')
for e in cur['elements']:
 if e.get('text')=='계정 연결':e.update(text='검색 예시 보기',dest='MENU08 / FriendRequestResult')
# The review surface links connected examples without implying real server state.

# Global menu preserves the requested lobby six-item navigation and exposes records.
new('MENU08 / AllMenus','전체 메뉴','archive','FOREST ARENA / MENU')
for gi,(group,entries) in enumerate([('전투 준비',[('캐릭터','people','SCR_04_CharacterCollection'),('장신구','armor','SCR_06_AccessoryCollection'),('프리셋','book','SCR_08_Preset')]),('활동과 기록',[('미션','leaf','SCR_21_Mission'),('도감','book','SCR_20_Collection'),('랭크','crown','SCR_23_Rank')]),('교류와 내 정보',[('친구','people','SCR_22_Social'),('프로필','people','SCR_24_Profile'),('상점','balance','SCR_19_Shop')])]):
 x=96+gi*584;label(group,x,224,552);line(x,280,552)
 for i,(t,k,d) in enumerate(entries):btn(t,x,320+i*160,552,120,d,ic=k)
btn('설정',1392,952,432,80,'EXT_06_GeneralSettings',ic='gear');note('메뉴를 선택하면 같은 위치의 뒤로 버튼으로 돌아올 수 있습니다.')
new('MENU08 / Review','메뉴 상태 검토','archive','검토용 / REVIEW')
for i,(t,d) in enumerate([('빈 목록','MENU08 / EmptyList'),('선택 누락','MENU08 / SelectionRequired'),('연결 실패',nm('SCR_22_Social','connection-error')),('설정 복원','MENU08 / SettingsReset'),('조회 중','MENU08 / FriendsLoading'),('이전 자료','MENU08 / MissionStale'),('빈 친구 목록','MENU08 / EmptyFriends'),('조회 실패','MENU08 / RankError')]):btn(t,96+(i%4)*440,280+(i//4)*256,408,184,d)
note('검토용 보드입니다. 실제 게임 메뉴에는 추가하지 않습니다.')
# Review pages are prototype inspection entry points, outside the real menu navigation.
def reachable(start):
 seen=set();queue=[start]
 while queue:
  name=queue.pop()
  if name in seen or name not in S:continue
  seen.add(name);queue += [e['dest'] for e in S[name]['elements'] if e.get('dest') in S]
 return seen
lobbyReachable=reachable('SCR_03_Lobby')
reviewOnly=sorted(set(S)-lobbyReachable-{'MENU08 / Review'})
reviewPages=max(1,math.ceil(len(reviewOnly)/8))
for page in range(reviewPages):
 name='MENU08 / Review' if page==0 else 'MENU08 / Review / page-'+str(page+1)
 new(name,'메뉴 상태 검토','archive','검토용 / REVIEW')
 for i,d in enumerate(reviewOnly[page*8:(page+1)*8]):
  title=S[d]['title'];labelText=f'{page*8+i+1:02} · '+title
  btn(labelText,96+(i%4)*440,256+(i//4)*256,408,184,d)
 if page>0:btn('이전 검토',96,952,304,80,'MENU08 / Review' if page==1 else 'MENU08 / Review / page-'+str(page))
 if page+1<reviewPages:btn('다음 검토',1504,952,320,80,'MENU08 / Review / page-'+str(page+2),'primary')
 text('REVIEW / page',f'{page+1} / {reviewPages}',864,968,192,32,'gold','500','center')
 text('REVIEW / guidance','검토용 예시입니다. 실제 게임 메뉴에는 추가하지 않습니다.',96,840,1728,30,'muted')
if set(S)-reachable('SCR_03_Lobby')-reachable('MENU08 / Review'):raise ValueError('Unreachable review states')
# Preserve selected character through editable preset/save/apply and result preview paths.
CHAR_FULL={'ja-hyun':'IMG/char/mouse/full','myo-ryung':'IMG/char/rabbit/full','nabi':'DESIGN/char/nabi/full','yu-ran':'DESIGN/char/yu-ran/full'}
def selection_name(cid,stage):return nm('SCR_08_Preset',stage+'-'+cid)
def change_hero(scene,cid):
 for e in scene['elements']:
  if e['kind']=='image' and e.get('key')=='myo-ryung':e.update(key=cid,slot=CHAR_FULL[cid],name='ART / '+cid)
for i,(cid,cn,role,trait,story) in enumerate(CHARS):
 draft=selection_name(cid,'draft');saved=selection_name(cid,'saved');applied=selection_name(cid,'applied');saveconfirm=selection_name(cid,'save-confirm');applyconfirm=selection_name(cid,'apply-confirm');applysavedconfirm=selection_name(cid,'apply-saved-confirm')
 lobby=nm('SCR_03_Lobby','applied-'+cid);prof=nm('SCR_24_Profile','applied-'+cid)
 detail='SCR_05_CharacterDetail' if i==0 else nm('SCR_05_CharacterDetail',f'char-{i}-tab-0-filter-전체')
 for stage,name in [('draft',draft),('saved',saved),('applied',applied)]:
  cur=deepcopy(S['SCR_08_Preset']);cur.update(name=name,target=False,selection={'character':cid,'accessory':'iron_armor','presetSlot':0,'stage':stage});S[name]=cur;change_hero(cur,cid)
  for e in cur['elements']:
   if e.get('text')=='묘령':e['text']=cn
   if e.get('text')=='묘령 · 철갑옷':e['text']=cn+' · 철갑옷'
   if e['name']=='PRESET / selected title':e['text']= {'draft':'편집 중인 편성','saved':'저장한 편성','applied':'현재 사용하는 편성'}[stage]
   if e['name']=='PRESET / state' and e.get('text')=='사용 중':e['text']={'draft':'편집 중','saved':'저장됨','applied':'사용 중'}[stage]
   if e['name']=='BUTTON / 뒤로':e['dest']=lobby if stage=='applied' else detail
   if e['name']=='SELECT / 편성 1':e['dest']=name
   if e['name']=='SELECT / 편성 편집 캐릭터':e['dest']='SCR_04_CharacterCollection' if i==0 else nm('SCR_04_CharacterCollection',f'char-{i}-tab-0-filter-전체')
   if e['name'].startswith('CONTEXT /'):e.update(text='선택한 편성입니다. 저장과 적용은 별개입니다.' if stage!='applied' else cn+' · 철갑옷을 현재 편성에 적용했습니다.',w=736)
   if e['name']=='BUTTON / 저장':
    if stage=='draft':e.update(dest=saveconfirm)
    elif stage=='saved':e.update(text='저장됨',dest=None,state='disabled')
    else:e.update(text='프로필',dest=prof,state='ghost')
   if e['name']=='BUTTON / 편성 적용':e.update(text='로비로' if stage=='applied' else '편성 적용',dest=lobby if stage=='applied' else applysavedconfirm if stage=='saved' else applyconfirm)
  if stage!='applied':btn('취소',888,952,280,80,detail,'ghost')
 overlay(saveconfirm,draft,'이 편성을 저장할까요?',cn+' · 철갑옷\n슬롯 01에 저장합니다.\n현재 사용하는 편성은 적용할 때 바뀝니다.',[('취소',draft,'ghost'),('저장 확인',saved,'primary')],'book')
 overlay(applyconfirm,draft,'현재 편성으로 적용할까요?',cn+' · 철갑옷\n이 조합을 현재 사용하는 편성으로 바꿉니다.',[('취소',draft,'ghost'),('적용 확인',applied,'primary')],'check')
 overlay(applysavedconfirm,saved,'저장한 편성을 적용할까요?',cn+' · 철갑옷\n저장한 조합을 현재 편성으로 바꿉니다.',[('취소',saved,'ghost'),('적용 확인',applied,'primary')],'check')
 cur=deepcopy(S['SCR_03_Lobby']);cur.update(name=lobby,target=False,selection={'character':cid,'accessory':'iron_armor','stage':'applied'});S[lobby]=cur;change_hero(cur,cid)
 for e in cur['elements']:
  if e['name']=='LOADOUT / name':e['text']=cn
  if e['name']=='LOADOUT / role':e['text']=role+' · '+trait.split(' · ')[-1]
  if e.get('dest')=='SCR_08_Preset':e['dest']=applied
  if e.get('dest')=='SCR_24_Profile':e['dest']=prof
 cur=deepcopy(S['SCR_24_Profile']);cur.update(name=prof,target=False,selection={'character':cid,'accessory':'iron_armor','stage':'applied'});S[prof]=cur;change_hero(cur,cid)
 for e in cur['elements']:
  if e['name']=='PROFILE / loadout':e['text']=cn+' / 기본 전투 스타일 / 철갑옷'
  if e.get('dest')=='SCR_08_Preset':e['dest']=applied
  if e['name']=='BUTTON / 뒤로':e['dest']=lobby
 for scene in list(S.values()):
  if (scene['name']=='SCR_05_CharacterDetail' and i==0) or scene['name'].startswith(nm('SCR_05_CharacterDetail',f'char-{i}-')):
   for e in scene['elements']:
    if e['name']=='BUTTON / 편성에 넣기':e['dest']=draft
# Keep old first-filter scene names as aliases; additional selected rows and details retain category.
def accessory_list_name(i,cat):
 if cat=='전체':return 'SCR_06_AccessoryCollection' if i==0 else nm('SCR_06_AccessoryCollection',f'item-{i}-filter-전체')
 first=next(j for j,it in enumerate(ITEMS) if it[2]==cat)
 return nm('SCR_06_AccessoryCollection',f'item-{0 if i==first else i}-filter-{cat}')
for cat in ['이동','방어','기술']:
 ids=[i for i,it in enumerate(ITEMS) if it[2]==cat]
 for pos,i in enumerate(ids):
  if pos:accessories(i,False,cat)
  accessories(i,True,cat)
for scene in list(S.values()):
 name=scene['name']
 if not name.startswith('MENU08 / SCR_0') or '-filter-' not in name:continue
 cat=name.split('-filter-',1)[1]
 if cat=='전체' or not any(n in name for n in ['SCR_06_AccessoryCollection','SCR_07_AccessoryDetail']):continue
 idx=int(name.split(' / item-',1)[1].split('-filter-',1)[0]);idx=idx if ITEMS[idx][2]==cat else next(i for i,it in enumerate(ITEMS) if it[2]==cat)
 if 'SCR_06_AccessoryCollection' in name:
  for e in scene['elements']:
   if e['kind']=='hotspot' and e['name'].startswith('SELECT / '):
    selected=next(i for i,it in enumerate(ITEMS) if e['name']=='SELECT / '+it[1]);e['dest']=accessory_list_name(selected,cat)
   if e['name']=='BUTTON / 상세 · 비교':e['dest']=nm('SCR_07_AccessoryDetail',f'item-{idx}-filter-{cat}')
 else:
  for e in scene['elements']:
   if e['name']=='BUTTON / 뒤로':e['dest']=accessory_list_name(idx,cat)
# Original production order stays stable; only appended states require new native boards.
SELECTION_BASELINE=json.loads((TASK/'selection-fix-baseline.json').read_text())
oldOrder=[row['name'] for row in SELECTION_BASELINE['scenes']]
S={name:S[name] for name in oldOrder}|{name:scene for name,scene in S.items() if name not in oldOrder}
lobbyReachable=reachable('SCR_03_Lobby');reviewOnly=sorted(set(S)-lobbyReachable-{s for s in S if s=='MENU08 / Review' or s.startswith('MENU08 / Review /')})
if set(S)-reachable('SCR_03_Lobby')-reachable('MENU08 / Review'):raise ValueError('Selection states unreachable')

# Provide complete old-state traceability while preserving original MENU07 boards.
oldnames={s['name'] for s in OLD['scenes']};legacy=[]
for old in sorted(oldnames):
 newname=old.replace('MENU07 /','MENU08 /',1)
 if old=='MENU07 / SCR_04_CharacterCollection / char-1-tab-0-filter-근접':newname=nm('SCR_04_CharacterCollection','char-2-tab-0-filter-근접')
 if newname not in S:raise ValueError('Unmapped v07 scene: '+old)
 S[newname]['legacyName']=old;legacy.append({'legacy':old,'current':newname})
for scene in S.values():
 scene['transitionMs']=200
 for e in scene['elements']:
  if e['kind'] in ['button','hotspot'] and (e['w']<72 or e['h']<72):raise ValueError('Small control '+scene['name'])
  if e['kind']=='text' and e['y']+e['h']>1056:raise ValueError('Text exceeds bottom '+scene['name']+' '+e['name'])
internal=set(S);external=sorted({e['dest'] for s in S.values() for e in s['elements'] if e.get('dest') and e['dest'] not in internal})
payload=dict(version=8,palette=C,base=BASE,scenes=list(S.values()),legacyMapping=legacy,externalDestinations=external,sourceAssets='premium-menu-v07',transitionMs=200,lobbyReachable=sorted(lobbyReachable),reviewOnly=reviewOnly,reviewPages=reviewPages)
(TASK/'scene-spec.json').write_text(json.dumps(payload,ensure_ascii=False,indent=2))
def scene_hash(scene):return hashlib.sha256(json.dumps(scene,ensure_ascii=False,sort_keys=True,separators=(',',':')).encode()).hexdigest()
before={row['name']:row['sha256'] for row in SELECTION_BASELINE['scenes']}
changed=[{'name':name,'beforeSha256':before[name],'afterSha256':scene_hash(scene)} for name,scene in S.items() if name in before and before[name]!=scene_hash(scene)]
added=[{'name':name,'beforeSha256':None,'afterSha256':scene_hash(scene)} for name,scene in S.items() if name not in before]
(TASK/'changed-scenes.json').write_text(json.dumps({'basis':SELECTION_BASELINE['basis'],'algorithm':SELECTION_BASELINE['algorithm'],'originalOrderPreserved':list(S)[:len(oldOrder)]==oldOrder,'beforeScenes':len(before),'afterScenes':len(S),'changedExisting':changed,'added':added,'unchangedExisting':len(before)-len(changed)},ensure_ascii=False,indent=2)+'\n')
with (TASK/'state-table.csv').open('w') as f:
 w=csv.writer(f);w.writerow(['scene','kind','legacy_scene','background','control_count','purpose'])
 for s in S.values():w.writerow([s['name'],'base' if s['target'] else 'popup' if s.get('overlay') else 'variant',s.get('legacyName',''),s['background'],sum(e['kind'] in ['button','hotspot'] for e in s['elements']),s['title']])
print(json.dumps({'base':len(BASE),'scenes':len(S),'variants':len(S)-len(BASE),'legacy':len(legacy),'external':external},ensure_ascii=False))
