"""Editable scene specifications for Penpot premium menus; no runtime changes."""
from pathlib import Path
import json, math
ROOT=Path(__file__).resolve().parents[2];TASK=Path(__file__).resolve().parent
C={'bg':'#10181C','panel':'#1C282C','text':'#F2F3ED','muted':'#BBC6C6','gold':'#D9C58E','mint':'#8CBFB2','line':'#455455','danger':'#DD9B92'}
S={};cur=None
CHARS=[('ja-hyun','자현','균형 · 간격 조절','짧은 연속 공격과 거리 조절'),('myo-ryung','묘령','빠른 이동 · 근접 압박','빠른 발놀림으로 기회를 만드는 동료'),('nabi','나비','공중 이동 · 유연한 공격','위치를 바꾸며 흐름을 이어가는 동료'),('yu-ran','유란','복싱 · 근접 연계','가까운 거리에서 연속 공격을 잇는 동료')]
ITEMS=[('iron_armor','철갑옷','방어','무게를 더하는 대신 지상 이동이 느려집니다.','armor'),('boxing_gloves','복싱 글러브','기술','유란의 기술 목록으로 전투 방식을 바꿉니다.','glove'),('thorns','균형 장신구','이동','공중 이동과 지상 이동의 균형을 바꿉니다.','balance'),('explosive_gloves','도약 장갑','이동','점프를 높이는 대신 밀려나기 쉬워집니다.','jump'),('ultimate_charm','집중 장신구','기술','적중으로 궁극기를 준비하는 대신 지상 이동이 느려집니다.','focus'),('phoenix_revive','활공 장신구','이동','낮은 중력과 느린 공중 이동으로 궤적을 바꿉니다.','wing')]
# Hand authored original glyph illustrations, independent of commercial reference assets.
PATHS={
'armor':'<path d="M48 24L72 36L90 28L114 52L100 72L94 66L94 113Q64 126 34 113L34 66L28 72L14 52L38 28L56 36Z"/><path d="M48 24Q64 40 80 24M64 45V110M40 65H88M40 89H88"/>',
'glove':'<path d="M32 99V73Q16 50 32 36Q43 25 51 39V26Q51 15 63 18Q72 18 72 30V27Q85 16 92 28L103 50Q110 69 94 89V101Z"/><path d="M32 100H94V118H32ZM45 65Q63 44 86 57M60 38V49"/>',
'balance':'<path d="M64 18V108M29 109H99M21 44H107M25 44L11 80Q28 97 45 80L31 44M96 44L82 80Q99 97 116 80L102 44"/><circle cx="64" cy="29" r="12"/>',
'jump':'<path d="M25 109Q42 55 106 18Q106 70 50 95Z"/><path d="M25 109L92 35M57 77L54 52M74 61L97 66M43 91L41 74"/>',
'focus':'<circle cx="64" cy="64" r="40"/><circle cx="64" cy="64" r="21"/><path d="M64 8V30M64 98V120M8 64H30M98 64H120M32 32L47 47M81 81L96 96M32 96L47 81M81 47L96 32"/>',
'wing':'<path d="M61 96Q9 104 16 26Q27 62 53 67L64 96L75 67Q101 62 112 26Q119 104 67 96ZM16 52L45 74M24 81L54 86M112 52L83 74M104 81L74 86"/>',
'leaf':'<path d="M25 106Q4 22 110 17Q116 96 25 106ZM25 106L86 39M50 82L46 51M68 63L98 68"/>',
'book':'<path d="M14 22Q42 14 64 30Q86 14 114 22V104Q86 96 64 112Q42 96 14 104ZM64 30V112M27 40H48M80 40H101M27 57H48M80 57H101"/>',
'people':'<circle cx="48" cy="36" r="20"/><circle cx="92" cy="48" r="16"/><path d="M13 112V98Q13 67 48 67Q83 67 83 98V112ZM83 79Q114 74 119 109"/>',
'crown':'<path d="M20 100L10 38L42 62L64 23L86 62L118 38L108 100ZM25 114H103M24 86H104"/>',
'gear':'<path d="M52 12H76L82 30L98 34L114 48L103 63L110 84L93 99L73 96L64 118L43 108L40 87L20 81L17 60L31 46L29 26L50 25Z"/><circle cx="64" cy="64" r="23"/>',
'arrow':'<path d="M108 64H20M53 27L17 64L53 101"/>',
'play':'<path d="M38 18L109 64L38 110Z"/>',
'check':'<path d="M20 65L50 94L110 29"/>',
'close':'<path d="M25 25L103 103M103 25L25 103"/>',
'mail':'<path d="M12 30H116V99H12ZM12 30L64 70L116 30"/>'}
def svg(name):
 return f'<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><circle cx="64" cy="64" r="60" fill="#172326" stroke="#455455" stroke-width="1"/><g fill="#26383A" stroke="#D9C58E" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round">{PATHS[name]}</g><circle cx="64" cy="64" r="54" fill="none" stroke="#8CBFB2" stroke-opacity=".2"/></svg>'

def add(kind,name,x,y,w,h,**kw):cur['elements'].append(dict(kind=kind,name=name,x=x,y=y,w=w,h=h,**kw))
def rect(name,x,y,w,h,color='panel',opacity=1,r=8,stroke=None):add('rect',name,x,y,w,h,color=C.get(color,color),opacity=opacity,r=r,stroke=C.get(stroke,stroke))
def text(name,t,x,y,w=500,size=32,color='text',weight='500',align='left'):
 lines=t.count('\n')+1;add('text',name,x,y,w,math.ceil(size*1.45*lines),text=t,size=size,color=C.get(color,color),weight=weight,align=align)
def art(key,x,y,w,h,slot=None):add('image','ART / '+key,x,y,w,h,key=key,slot=slot)
def icon(key,x,y,size=64):add('svg','ICON / '+key,x,y,size,size,svg=svg(key),key=key)
def surface(name,x,y,w,h,state='default'):add('surface',name,x,y,w,h,state=state)
def btn(t,x,y,w=280,h=80,dest=None,state='default',legacy=None,iconkey=None):add('button','BUTTON / '+t,x,y,w,h,text=t,state=state,dest=dest,legacy=legacy or 'BUTTON / '+t,icon=iconkey)
def line(x,y,w=1000):rect('Divider',x,y,w,1,'line',.65,r=0)
def note(t,x,y,w=600):text('Note',t,x,y,w,28,'muted')
def new(name,title,bg,section='FOREST ARENA',future=False):
 global cur
 cur={'name':name,'title':title,'background':bg,'w':1920,'h':1080,'elements':[],'target':name in BASE,'future':future};S[name]=cur
 art(bg,0,0,1920,1080)
 rect('Background veil',0,0,1920,1080,'bg',.38,0)
 rect('Header scrim',0,0,1920,176,'bg',.86,0)
 rect('Footer scrim',0,944,1920,136,'bg',.88,0)
 btn('뒤로',96,48,136,80,'SCR_03_Lobby',iconkey='arrow')
 text('Section',section,264,50,740,24,'gold','500')
 text('Title',title,264,88,1100,52,'text','700')
 text('Page mark',title,1648,65,176,28,'muted','500','right')
 line(96,166,1728)
 if future:note('미래 기능 · 설계안',1450,978,374)
 return cur
BASE=['SCR_04_CharacterCollection','SCR_05_CharacterDetail','SCR_06_AccessoryCollection','SCR_07_AccessoryDetail','SCR_08_Preset','SCR_19_Shop','SCR_20_Collection','SCR_21_Mission','SCR_22_Social','SCR_23_Rank','SCR_24_Profile','EXT_06_GeneralSettings','CBT_08_Settings']
def suffix(base,tag):return 'MENU07 / '+base+' / '+tag

def tabs(labels,x,y,width=760,active=0,dests=None):
 w=(width-(len(labels)-1)*8)/len(labels)
 for i,l in enumerate(labels):btn(l,x+i*(w+8),y,w,72,(dests or [None]*len(labels))[i],'selected' if i==active else 'ghost')

def chars(base,idx=0,detail=False,tab=0,role_filter='전체'):
 name=base if idx==0 and tab==0 and role_filter=='전체' else suffix(base,f'char-{idx}-tab-{tab}-filter-{role_filter}')
 new(name,'캐릭터 상세' if detail else '캐릭터', 'character-room',section='동료의 방 / CHARACTER')
 cid,label,role,trait=CHARS[idx]
 filterbase='SCR_04_CharacterCollection' if detail else base
 tabs(['전체','균형','근접'],96,206,384, ['전체','균형','근접'].index(role_filter),[filterbase,suffix(filterbase,'char-0-tab-0-filter-균형'),suffix(filterbase,'char-1-tab-0-filter-근접')])
 for i,(k,n,r,d) in enumerate(CHARS):
  if role_filter=='균형' and i!=0:continue
  if role_filter=='근접' and i not in [1,3]:continue
  yy=320+i*144
  surface('Character row / '+n,96,yy,384,128,'selected' if i==idx else 'default')
  art(k,110,yy+8,112,112,'IMG/char/'+{'ja-hyun':'mouse','myo-ryung':'rabbit','nabi':'cat-theme','yu-ran':'yu-ran'}[k]+'/full')
  text('Roster name',n,238,yy+26,220,34,weight='700');text('Roster state','✓ 선택' if i==idx else '동료',238,yy+77,220,26,'gold' if i==idx else 'muted')
  add('hotspot','SELECT / '+n,96,yy,384,128,dest=base if i==0 else suffix(base,f'char-{i}-tab-0-filter-전체'))
 art(cid,496,194,690,744,'IMG/char/'+{'ja-hyun':'mouse','myo-ryung':'rabbit','nabi':'cat-theme','yu-ran':'yu-ran'}[cid]+'/full')
 surface('Character detail surface',1216,206,608,698)
 text('Character name',label,1256,244,528,56,'text','700');text('Role',role,1256,324,528,32,'gold')
 if detail:
  dests=[base if idx==0 else suffix(base,f'char-{idx}-tab-0-filter-전체'),suffix(base,f'char-{idx}-tab-1-filter-전체'),suffix(base,f'char-{idx}-tab-2-filter-전체')]
  tabs(['기술','연계','이야기'],1256,398,528,tab,dests)
  if tab==0:
   text('Skill title','전투의 특징',1256,510,528,36,weight='700');text('Skill description',trait+'\n\n기술과 공격 방향은\n연습장에서 확인하세요.',1256,576,528,32)
  elif tab==1:
   text('Combo title','연속 공격의 흐름',1256,510,528,36,weight='700');text('Combo description','공격을 맞힌 뒤 다음 행동으로\n흐름을 이어갑니다.\n\n세부 연계는 연습에서 확인하세요.',1256,576,528,32)
  else:
   text('Story title','숲의 동료',1256,510,528,36,weight='700');text('Story description','캐릭터 이야기는 준비 중입니다.\n\n새로운 이야기와 대화는\n확정된 콘텐츠 이후 제공됩니다.',1256,576,528,32)
 else:
  line(1256,402,528);text('Trait',trait+'\n\n큰 원화로 모습을 살펴보고\n기술과 전투 특징을 확인하세요.',1256,440,528,32)
  btn('기술 살펴보기',1256,784,528,80,'SCR_05_CharacterDetail',state='ghost')
 btn('연습하기' if detail else '상세 보기',1216,968,280,80,'EXT_05_PracticeSetup' if detail else 'SCR_05_CharacterDetail',state='ghost')
 btn('편성에 넣기' if detail else '이 캐릭터 선택',1520,968,304,80,'SCR_08_Preset','primary')
 note('캐릭터 선택 / 원화와 전투 특징',96,990,1000)
 return name
for i in range(4):chars('SCR_04_CharacterCollection',i)
chars('SCR_04_CharacterCollection',0,role_filter='균형');chars('SCR_04_CharacterCollection',1,role_filter='근접')
for i in range(4):
 for t in range(3):chars('SCR_05_CharacterDetail',i,True,t)

def accessories(base,idx=0,category='전체',detail=False):
 name=base if idx==0 and category=='전체' else suffix(base,f'item-{idx}-filter-{category}')
 new(name,'장신구 상세' if detail else '장신구','accessory-workshop',section='숲의 공방 / ACCESSORY')
 item=ITEMS[idx];iid,n,cat,desc,ik=item
 filterbase='SCR_06_AccessoryCollection' if detail else base
 tabs(['전체','이동','방어','기술'],96,206,1088,['전체','이동','방어','기술'].index(category),[filterbase,suffix(filterbase,'item-0-filter-이동'),suffix(filterbase,'item-0-filter-방어'),suffix(filterbase,'item-0-filter-기술')])
 for pos,(j,it) in enumerate((j,it) for j,it in enumerate(ITEMS) if category=='전체' or it[2]==category):
  x=96+(pos%4)*272;y=322+(pos//4)*288
  surface('Accessory card / '+it[1],x,y,248,256,'selected' if j==idx else 'default');icon(it[4],x+60,y+20,128)
  text('Accessory name',it[1],x+16,y+166,216,30,weight='700');text('Accessory category','✓ 장착' if j==idx else it[2],x+16,y+212,216,26,'gold' if j==idx else 'muted')
  add('hotspot','SELECT / '+it[1],x,y,248,256,dest=base if j==0 else suffix(base,f'item-{j}-filter-전체'))
 surface('Accessory detail surface',1216,206,608,698);icon(ik,1432,242,176)
 text('Selected accessory',n,1256,448,528,48,weight='700');text('Functional category','기능 / '+cat,1256,526,528,30,'gold');line(1256,590,528)
 text('Accessory effect',desc.replace(' 대신','\n대신')+'\n\n효과와 선택의 차이를\n연습장에서 비교하세요.',1256,624,528,30)
 if detail:btn('연습하기',96,968,288,80,'EXT_05_PracticeSetup',state='ghost')
 else:btn('상세 보기',1216,968,280,80,'SCR_07_AccessoryDetail',state='ghost')
 btn('장착하기' if detail else '이 장신구 선택',1520,968,304,80,'SCR_08_Preset','primary')
 note('기능과 조작 방식으로 선택하세요.',96 if not detail else 420,990,740)
 return name
for i in range(6):accessories('SCR_06_AccessoryCollection',i);accessories('SCR_07_AccessoryDetail',i,detail=True)
for c in ['이동','방어','기술']:accessories('SCR_06_AccessoryCollection',0,c)

def presets(idx=0):
 name='SCR_08_Preset' if idx==0 else suffix('SCR_08_Preset',f'slot-{idx}')
 new(name,'전투 편성','character-room',section='나의 편성 / PRESET');tabs(['프리셋 1','프리셋 2','프리셋 3','프리셋 4'],96,206,1728,idx,['SCR_08_Preset']+[suffix('SCR_08_Preset',f'slot-{i}') for i in [1,2,3]])
 art('ja-hyun',168,306,620,630,'IMG/char/mouse/full');text('Preset number',f'0{idx+1}',832,326,180,90,'gold','700');text('Preset title','숲으로 향하는 동료',1048,344,744,48,weight='700')
 for pos,(l,t,d,ic) in enumerate([('캐릭터','자현 · 균형','SCR_04_CharacterCollection','people'),('직업','시험 직업 · 추가 직업 준비 중',None,'book'),('장신구','철갑옷 · 방어','SCR_06_AccessoryCollection','armor')]):
  y=464+pos*144;surface('Preset row / '+l,832,y,992,128);icon(ic,856,y+26,72);text('Slot label',l,952,y+14,800,26,'muted');text('Slot value',t,952,y+56,800,34,weight='700')
  if d:add('hotspot','EDIT / '+l,832,y,992,128,dest=d)
 btn('편성으로 플레이',1472,968,352,80,'SCR_09_ModeSelect','primary');note('캐릭터와 장신구를 한 판의 편성으로 준비하세요.',96,990,1200)
for i in range(4):presets(i)

def shop(category='추천'):
 base='SCR_19_Shop';name=base if category=='추천' else suffix(base,'category-'+category)
 new(name,'상점','shop-market',section='숲의 교역소 / SHOP',future=True)
 for i,(l,ic) in enumerate([('추천','leaf'),('장신구','armor'),('캐릭터','people')]):btn(l,96,214+i*112,272,88,base if i==0 else suffix(base,'category-'+l),'selected' if l==category else 'ghost',iconkey=ic)
 surface('Shop invitation',96,586,272,318);icon('leaf',180,614,96);text('Shop philosophy','먼저 연습하고\n내게 맞는 동료를\n선택하세요.',120,744,224,28)
 text('Shop section','새로운 전투의 가능성' if category=='추천' else category+' 살펴보기',408,208,1384,42,weight='700')
 if category=='추천':
  surface('Featured set',408,286,1416,232);art('ja-hyun',432,282,256,242,'IMG/char/mouse/full');text('Featured headline','함께할 동료, 새로운 방식',728,318,1008,44,weight='700');text('Featured description','캐릭터와 장신구를 살펴보고 연습장에서 경험하세요.',728,386,1040,30,'muted');btn('캐릭터 살펴보기',1464,426,320,72,'SCR_04_CharacterCollection','primary');start=552
 else:start=300
 entries=ITEMS if category!='캐릭터' else CHARS
 for i,it in enumerate(entries[:4 if category=='추천' else 6]):
  x=408+i%4*360;y=start+i//4*288
  surface('Product / '+it[1],x,y,336,256)
  if category=='캐릭터':art(it[0],x+96,y+10,144,144,'IMG/char/roster/'+it[0])
  else:icon(it[4],x+104,y+16,128)
  text('Product name',it[1],x+20,y+164,296,32,weight='700');text('Product descriptor',it[2],x+20,y+212,296,26,'muted')
  add('hotspot','PRODUCT / '+it[1],x,y,336,256,dest='SCR_05_CharacterDetail' if category=='캐릭터' else suffix(base,f'detail-{i}'))
 note('획득 방식·가격은 확정된 정책에 따라 표시합니다.',96,978,1296)
 return name
for c in ['추천','장신구','캐릭터']:shop(c)

def collection(accessory=False,unowned=False):
 base='SCR_20_Collection';name=base if not accessory and not unowned else suffix(base,'accessory' if accessory else 'unowned')
 new(name,'도감','archive',section='숲의 기록실 / COLLECTION',future=True)
 tabs(['캐릭터','장신구'],96,206,520,int(accessory),[base,suffix(base,'accessory')]);tabs(['보유','미보유'],1320,206,504,int(unowned),[base,suffix(base,'unowned')])
 entries=ITEMS if accessory else CHARS
 for i,it in enumerate(entries):
  x=96+i%4*288;y=322+i//4*276;surface('Collection card / '+it[1],x,y,264,244,'disabled' if unowned else 'default')
  if accessory:icon(it[4],x+72,y+16,120)
  else:art(it[0],x+64,y+8,136,152,'IMG/char/roster/'+it[0])
  text('Collection name',it[1],x+20,y+162,224,30,weight='700');text('Owned state','미보유 예시' if unowned else '보유 예시',x+20,y+206,224,24,'muted')
  add('hotspot','ENTRY / '+it[1],x,y,264,244,dest='SCR_07_AccessoryDetail' if accessory else 'SCR_05_CharacterDetail')
 surface('Collection summary',1304,322,520,556);icon('book',1480,360,152);text('Collection introduction','동료들의 기록',1344,566,440,42,weight='700');text('Collection description','캐릭터와 장신구의\n특징을 한곳에서 살펴보세요.\n\n보유 목록과 진행 정보는\n설계 예시입니다.',1344,638,440,30)
 note('보유·미보유는 글자와 상태 표시로 구분합니다.',96,990,1180)
collection();collection(True);collection(False,True)

def missions(tab=0):
 base='SCR_21_Mission';name=base if tab==0 else suffix(base,f'tab-{tab}')
 new(name,'미션','archive',section='숲의 작은 목표 / MISSION',future=True);tabs(['일일','주간','업적'],96,206,1040,tab,[base,suffix(base,'tab-1'),suffix(base,'tab-2')])
 rows=[('연습장에서 한 판','이동과 공격을 편안하게 익혀 보세요.'),('새로운 동료 알아보기','다른 전투 방식을 살펴보세요.'),('끝까지 도전하기','한 판의 경험을 기록하는 목표입니다.')]
 for i,(l,d) in enumerate(rows):
  y=326+i*172;surface('Mission row',96,y,1040,148,'selected' if i==0 else 'default');icon('leaf',120,y+36,72);text('Mission title',l,224,y+24,848,34,weight='700');text('Mission subtitle',d,224,y+82,848,30,'muted');add('hotspot','MISSION / '+l,96,y,1040,148,dest=suffix(base,f'detail-{i}'))
 surface('Mission detail',1184,206,640,698);text('Mission focus','가볍게 이어가는 여정',1224,260,560,46,weight='700');icon('book',1400,372,208);text('Mission information','일일·주간·업적 분류의 설계입니다.\n\n목표·보상·갱신 주기는\n아직 확정되지 않았습니다.',1224,646,560,30)
 note('미션 보상과 진행 수치는 표시하지 않습니다.',96,990,1200)
for i in range(3):missions(i)

def social(recent=False,selected=0):
 base='SCR_22_Social';name=base if not recent and selected==0 else suffix(base,'recent' if recent else f'friend-{selected}')
 new(name,'친구','social-lodge',section='동료의 쉼터 / SOCIAL',future=True);tabs(['친구','최근 플레이어'],96,206,1008,int(recent),[base,suffix(base,'recent')])
 for i,(l,status) in enumerate([('숲길친구','접속 중 · 로비'),('푸른바람','접속 중 · 로비'),('나뭇잎','오프라인')]):
  y=326+i*168;surface('Friend row / '+l,96,y,1008,144,'selected' if i==selected else 'default');icon('people',120,y+28,88);text('Friend name',l,240,y+22,792,36,weight='700');text('Presence',('● ' if i<2 else '○ ')+status+' · 설계 예시',240,y+84,792,28,'mint' if i<2 else 'muted');add('hotspot','FRIEND / '+l,96,y,1008,144,dest=base if i==0 else suffix(base,f'friend-{i}'))
 surface('Selected friend',1152,206,672,698);art(CHARS[selected][0],1320,230,320,400,'IMG/char/roster/'+CHARS[selected][0]);text('Friend hero',['숲길친구','푸른바람','나뭇잎'][selected],1192,666,592,44,weight='700');text('Friend actions note','초대·관전은 온라인 기능 이후 제공됩니다.',1192,742,592,30,'muted');btn('초대 준비 중',1192,808,280,72,suffix(base,'connection-error'),'disabled');btn('관전 준비 중',1500,808,280,72,suffix(base,'connection-error'),'disabled')
 btn('친구 찾기',96,968,272,80,suffix(base,'search-empty'),state='ghost');note('접속 정보와 플레이어 이름은 설계 예시입니다.',408,990,960)
for i in range(3):social(False,i)
social(True)

new('SCR_23_Rank','랭크','observatory',section='숲의 전망대 / RANK',future=True)
icon('crown',272,310,328);text('Rank season','다음 시즌의 숲',96,720,680,60,weight='700');text('Rank status','시즌과 랭크 정책 준비 중',96,814,680,32,'gold')
surface('Rank description',824,206,1000,698);text('Rank introduction','도전의 기록',872,260,904,48,weight='700');line(872,352,904)
for i,(l,d) in enumerate([('시즌','시즌 일정은 아직 정하지 않았습니다.'),('진행','등급과 진행 규칙은 준비 중입니다.'),('보상','시즌 보상 정책은 미확정입니다.')]):text('Rank label',l,872,398+i*150,904,32,'gold');text('Rank value',d,872,450+i*150,904,32)
btn('랭크 대전 준비 중',1472,968,352,80,None,'disabled');note('현재는 랭크 대전을 시작할 수 없습니다.',96,990,1200)

new('SCR_24_Profile','프로필','observatory',section='나의 여정 / PROFILE',future=True)
art('ja-hyun',120,210,656,722,'IMG/char/mouse/full');surface('Profile summary',824,206,1000,698);text('Profile name','숲의 여행자',872,260,904,56,weight='700');text('Profile subtitle','대표 파이터 · 자현',872,344,904,32,'gold');line(872,424,904)
text('Loadout heading','즐겨 쓰는 편성',872,464,904,36,weight='700');text('Loadout composition','자현 / 시험 직업 / 철갑옷',872,528,904,34);icon('armor',1648,472,96)
text('Record heading','플레이어 기록',872,644,904,36,weight='700');text('Record note','누적 전적과 진행은 저장 기능 이후 제공됩니다.',872,716,904,32,'muted');btn('편성 살펴보기',872,808,392,72,'SCR_08_Preset',state='ghost')
note('프로필은 미래 기능 설계입니다.',96,990,1180)

def settings(tab='소리',toggle=False):
 base='EXT_06_GeneralSettings';name=base if tab=='소리' and not toggle else suffix(base,tab+('-off' if toggle else ''))
 new(name,'설정','archive',section='편안한 플레이 / SETTINGS')
 for i,(l,ic,d) in enumerate([('소리','focus',base),('화면 효과','leaf',suffix(base,'화면 효과')),('접근성','people',suffix(base,'접근성')),('조작','gear','CBT_08_Settings')]):btn(l,96,214+i*112,312,88,d,'selected' if l==tab else 'ghost',iconkey=ic)
 surface('Settings content',456,206,1368,698);text('Settings category',tab+' 설정',504,244,1272,44,weight='700');line(504,326,1272)
 rows={'소리':['음악','효과음'],'화면 효과':['화면 흔들림','번쩍임 효과'],'접근성':['진동','큰 글자']}[tab]
 for i,l in enumerate(rows):
  y=384+i*186;text('Setting label',l,504,y,840,36,weight='700');text('Setting description',{'음악':'배경 음악을 편안한 크기로 조절합니다.','효과음':'공격과 메뉴 동작의 소리를 조절합니다.','화면 흔들림':'움직임에 민감하면 흔들림을 줄이세요.','번쩍임 효과':'밝은 화면 효과의 강도를 줄이세요.','진동':'터치와 피격의 진동을 선택합니다.','큰 글자':'중요한 설명을 더 크게 표시합니다.'}[l],504,y+70,896,30,'muted')
  if tab=='소리':
   rect('Slider track',1488,y+12,248,8,'line');rect('Slider fill',1488,y+12,88 if toggle else 176,8,'mint');rect('Slider thumb',1564 if toggle else 1652,y-8,40,48,'gold',r=12);add('hotspot','ADJUST / '+l,1440,y-12,336,88,dest=suffix(base,'소리-off') if not toggle else base)
  else:btn('끔' if toggle else '켬',1552,y-8,224,80,suffix(base,tab+'-off') if not toggle else suffix(base,tab),'ghost' if toggle else 'selected')
 note('변경 내용을 확인한 뒤 적용하세요.',504,808,1250)
 btn('기본값 복원',96,968,312,80,'MENU07 / SettingsReset','ghost',legacy='BUTTON / 조작 기본값 복원');btn('취소',1320,968,224,80,'SCR_03_Lobby','ghost');btn('적용',1568,968,256,80,'SCR_03_Lobby','primary')
for t in ['소리','화면 효과','접근성']:settings(t);settings(t,True)

def controls(floating=False):
 base='CBT_08_Settings';name=base if not floating else suffix(base,'floating')
 new(name,'조작 설정','archive',section='손에 맞는 플레이 / CONTROLS');btn('일반 설정',96,214,312,88,'EXT_06_GeneralSettings','ghost',iconkey='leaf');btn('조작',96,326,312,88,base,'selected',iconkey='gear')
 surface('Controls preview',456,206,792,698);text('Preview title','조작 미리보기',496,244,712,42,weight='700');note('플로팅 · 첫 터치에서 시작' if floating else '고정 · 같은 위치에서 시작',496,322,712)
 rect('Preview field',496,414,712,336,'bg',.68,8)
 add('circle','Joystick ring',528,520,192,192,color=C['line']);add('circle','Joystick inner',552,544,144,144,color=C['panel']);icon('leaf',600 if floating else 592,584,64)
 for key,x,y,size in [('armor',990,488,88),('focus',1094,568,88),('play',942,624,104),('jump',854,592,80)]:icon(key,x,y,size)
 note('배치 예시 · 전투 입력 위치는 유지합니다.',496,812,712)
 surface('Controls parameters',1288,206,536,698);text('Joystick mode','방향 조이스틱',1328,244,456,38,weight='700');tabs(['고정','플로팅'],1328,328,456,int(floating),[base,suffix(base,'floating')]);text('Mode description','첫 터치에 생성되고\n손을 떼면 숨깁니다.' if floating else '손을 떼면 손잡이가\n중앙으로 돌아옵니다.',1328,448,456,30,'muted')
 for i,(l,t) in enumerate([('버튼 크기','100%'),('버튼 투명도','85%')]):
  yy=590+i*142;text('Control parameter',l+' '+t,1328,yy,456,32,weight='700');rect('Parameter track',1328,yy+76,440,8,'line');rect('Parameter fill',1328,yy+76,304,8,'mint');rect('Parameter thumb',1616,yy+58,40,48,'gold',r=12);add('hotspot','ADJUST / '+l,1328,yy+48,440,72,dest='MENU07 / ControlsParameters')
 btn('기본값 복원',96,968,312,80,'MENU07 / SettingsReset','ghost');btn('취소',1320,968,224,80,'EXT_06_GeneralSettings','ghost');btn('적용',1568,968,256,80,'EXT_06_GeneralSettings','primary')
controls();controls(True)

def overlay(name,under,title,message,actions,ic='leaf'):
 global cur
 source=S[under];cur=json.loads(json.dumps(source));cur.update(name=name,target=False,overlay=True);S[name]=cur
 rect('Modal shade',0,0,1920,1080,'bg',.82,0);surface('Modal',488,254,944,572);icon(ic,536,306,88);text('Modal title',title,664,314,720,44,weight='700');text('Modal message',message,536,442,848,32,'muted')
 for i,(l,d,st) in enumerate(actions):btn(l,536+i*440,690,408,88,d,st)
for i,it in enumerate(ITEMS):
 name=suffix('SCR_19_Shop',f'detail-{i}');overlay(name,'SCR_19_Shop',it[1],it[3]+'\n\n획득 방식과 가격은 아직 확정하지 않았습니다.',[('닫기','SCR_19_Shop','ghost'),('연습하기','EXT_05_PracticeSetup','primary')],it[4])
for i,(l,d) in enumerate([('연습장에서 한 판','이동과 공격을 익히는 목표입니다.'),('새로운 동료 알아보기','다른 동료의 전투 방식을 살펴보는 목표입니다.'),('끝까지 도전하기','한 판의 경험을 이어가는 목표입니다.')]):overlay(suffix('SCR_21_Mission',f'detail-{i}'),'SCR_21_Mission',l,d+'\n\n목표 진행과 보상은 확정 후 제공됩니다.',[('닫기','SCR_21_Mission','ghost'),('목표 목록','SCR_21_Mission','primary')],'book')
overlay('MENU07 / SettingsReset','CBT_08_Settings','기본값으로 복원할까요?','조작 설정을 기본값으로 되돌립니다.\n복원 여부를 선택하세요.',[('취소','CBT_08_Settings','ghost'),('복원','CBT_08_Settings','primary')],'gear')
overlay('MENU07 / ControlsParameters','CBT_08_Settings','조작 크기와 투명도','현재 기준은 크기 100%, 투명도 85%입니다.\n조절 범위는 구현 시 확정할 설정입니다.',[('닫기','CBT_08_Settings','ghost'),('설정으로','CBT_08_Settings','primary')],'gear')
overlay('MENU07 / EmptyList','SCR_20_Collection','표시할 항목이 없습니다.','다른 분류를 선택해 보세요.\n목록이 비어 있어도 메뉴로 돌아갈 수 있습니다.',[('닫기','SCR_20_Collection','ghost'),('전체 보기','SCR_20_Collection','primary')],'book')
overlay('MENU07 / SelectionRequired','SCR_08_Preset','동료를 먼저 선택하세요.','전투 편성을 준비하려면\n캐릭터를 선택해야 합니다.',[('취소','SCR_08_Preset','ghost'),('캐릭터 선택','SCR_04_CharacterCollection','primary')],'people')
overlay(suffix('SCR_22_Social','connection-error'),'SCR_22_Social','연결을 확인할 수 없습니다.','친구 기능은 온라인 구현 이후 제공됩니다.\n현재 화면은 연결 실패의 설계 예시입니다.',[('닫기','SCR_22_Social','ghost'),('친구 목록','SCR_22_Social','primary')],'people')
overlay(suffix('SCR_22_Social','search-empty'),'SCR_22_Social','친구 찾기 준비 중','찾기 기능과 검색 결과가 없는 상태의 설계입니다.\n온라인 기능 이후 제공됩니다.',[('닫기','SCR_22_Social','ghost'),('친구 목록','SCR_22_Social','primary')],'people')
# Preserve the existing combat-settings return while providing lobby-specific returns.
from copy import deepcopy
for name in ['CBT_08_Settings',suffix('CBT_08_Settings','floating')]:
 for e in S[name]['elements']:
  if e.get('text') in ['뒤로','취소','적용'] and e['kind']=='button':e['dest']='CBT_05_Pause'
for source,dest in [('CBT_08_Settings','MENU07 / ControlsFromLobby'),(suffix('CBT_08_Settings','floating'),'MENU07 / ControlsFloatingFromLobby')]:
 v=deepcopy(S[source]);v.update(name=dest,target=False);S[dest]=v
 for e in v['elements']:
  if e['kind'] not in ['button','hotspot']:continue
  if e.get('text') in ['뒤로','취소','적용']:e['dest']='EXT_06_GeneralSettings'
  elif e.get('dest')=='CBT_08_Settings':e['dest']='MENU07 / ControlsFromLobby'
  elif e.get('dest')==suffix('CBT_08_Settings','floating'):e['dest']='MENU07 / ControlsFloatingFromLobby'
  elif e.get('dest')=='MENU07 / SettingsReset':e['dest']='MENU07 / SettingsResetLobbyControls'
  elif e.get('dest')=='MENU07 / ControlsParameters':e['dest']='MENU07 / ControlsParametersLobby'
for s in list(S.values()):
 if s['name']=='EXT_06_GeneralSettings' or s['name'].startswith('MENU07 / EXT_06_GeneralSettings /'):
  for e in s['elements']:
   if e.get('dest')=='CBT_08_Settings':e['dest']='MENU07 / ControlsFromLobby'
   if e.get('dest')=='MENU07 / SettingsReset':e['dest']='MENU07 / SettingsResetGeneral'
for source,dest,returnto in [('MENU07 / SettingsReset','MENU07 / SettingsResetLobbyControls','MENU07 / ControlsFromLobby'),('MENU07 / ControlsParameters','MENU07 / ControlsParametersLobby','MENU07 / ControlsFromLobby'),('MENU07 / SettingsReset','MENU07 / SettingsResetGeneral','EXT_06_GeneralSettings')]:
 v=deepcopy(S[source]);v.update(name=dest,target=False);S[dest]=v
 for e in v['elements']:
  if e.get('dest')=='CBT_08_Settings':e['dest']=returnto

# Reachable boundary examples for prototype QA, contained in a separate review index.
for nm,title,bg in [('MENU07 / Review','메뉴 상태 검토','archive')]:
 new(nm,title,bg,section='검토용 / REVIEW')
 for i,(l,d) in enumerate([('빈 목록','MENU07 / EmptyList'),('선택 누락','MENU07 / SelectionRequired'),('연결 실패',suffix('SCR_22_Social','connection-error')),('설정 복원','MENU07 / SettingsReset')]):btn(l,96+(i%2)*880,264+(i//2)*240,848,192,d,'ghost')
 note('이 보드는 설계 검토 도구이며 실제 게임 메뉴가 아닙니다.',96,990,1728)

TASK.mkdir(exist_ok=True);(TASK/'scene-spec.json').write_text(json.dumps({'version':7,'palette':C,'base':BASE,'scenes':list(S.values())},ensure_ascii=False,indent=2))
ASSETS=ROOT/'assets/ui/premium-menu-v07';(ASSETS/'icons').mkdir(parents=True,exist_ok=True)
for k in PATHS:(ASSETS/'icons'/f'{k}-v07.svg').write_text(svg(k))
print(f'{len(BASE)} base scenes; {len(S)-len(BASE)} variants/state scenes; {len(PATHS)} original SVG icons')
