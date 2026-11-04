"""Editable shop review only. Prices, conversion and checkout stay undecided."""
from pathlib import Path
import copy,json,re
P=Path(__file__).resolve().parent;ROOT=P.parents[2]
old=json.loads((P.parent/'scene-spec.json').read_text());C=old['colors'];scenes=[]
def elem(k,n,x,y,w,h,**kw):return dict(kind=k,name=n,x=x,y=y,w=w,h=h,**kw)
def text(n,v,x,y,w,size=28,color='text',weight='500',align='left'):return elem('text',n,x,y,w,round(size*1.45*len(v.split('\n'))),text=v,size=size,color=color,weight=weight,align=align)
def rect(n,x,y,w,h,color='panel',opacity=1,radius=12):return elem('rect',n,x,y,w,h,color=color,opacity=opacity,radius=radius)
def button(n,v,x,y,w,h,dest=None,state='default',size=28,icon=None):return elem('button',n,x,y,w,h,text=v,dest=dest,state=state,size=size,icon=icon)
def image(k,x,y,w,h,slot,n=None):return elem('image',n or 'IMG / '+k,x,y,w,h,key=k,slot=slot)
def add(s):scenes.append(s);return s
def base(key,title,tab):
 e=[image('character-room',0,0,1920,1080,'IMG/bg/character-room'),rect('ATMOSPHERE',0,0,1920,1080,'bg',.78,0),rect('HEADER',0,0,1920,160,'bg',.92,0),rect('FOOTER',0,880,1920,200,'bg',.96,0),button('BACK','←',96,48,80,80,'shop-entry','ghost',36),text('TITLE','상점 · '+title,208,48,880,52,weight='700'),text('HEADER / note','상품·수량·보유 상태는 설계용 예시 · 가격 미정',208,112,1200,26,'muted'),text('BALANCE','조약돌  —     무지개돌  —',1168,64,656,28,'gold',align='right')]
 for i,(k,l,d) in enumerate([('character','캐릭터','shop-character-myo-ryung-light'),('artifact','신기','shop-artifacts-all'),('stone','조약돌','shop-stone'),('rainbow','무지개돌','shop-rainbow')]):e.append(button('SHOP TAB / '+k,l,96+i*440,192,408,80,None if k==tab else d,'selected' if k==tab else 'default',32))
 return dict(key=key,name='MENU09 / Shop-r01 / '+key,canonical='SCR_19_Shop',title=title,revision='shop-r01',w=1920,h=1080,elements=e)
chars=[]
for key in ['myo-ryung','ja-hyun','nabi','yu-ran']:
 raw=(ROOT/'assets/character'/key/'character.tres').read_text()
 get=lambda f,default:float(re.search(r'^'+f+r' = ([\d.]+)',raw,re.M).group(1)) if re.search(r'^'+f+r' = ([\d.]+)',raw,re.M) else default
 chars.append(dict(key=key,name=re.search(r'display_name = "([^"]+)"',raw).group(1),role=re.search(r'combat_role = "([^"]+)"',raw).group(1),values=[get('max_hp',100),get('ground_speed',300),get('air_speed',280),get('jump_velocity',520),get('weight',1)]))
tech=[('light','약공격'),('heavy','강공격'),('jump-light','점프 약'),('jump-heavy','점프 강'),('special','특수')]
slots={'myo-ryung':'IMG/char/rabbit/full','ja-hyun':'IMG/char/mouse/full','nabi':'IMG/char/roster/cat','yu-ran':'DESIGN/char/yu-ran/portrait'}
for c in chars:
 for idx,(t,label) in enumerate(tech):
  k='shop-character-'+c['key']+'-'+t;s=base(k,'캐릭터','character');e=s['elements']
  if idx:s['clone_of']='shop-character-'+c['key']+'-light'
  elif c['key']!='myo-ryung':s['clone_of']='shop-character-myo-ryung-light'
  e += [text('CHAR / name',c['name'],96,312,376,44,weight='700'),text('CHAR / role',c['role'],96,376,744,28,'mint'),image(c['key'],96,432,352,424,slots[c['key']],'IMG / selected-character'),rect('STATS / panel',480,432,376,424,'panel',.95,16),text('STATS / heading','기본 능력치',504,456,328,30,'gold',weight='600')]
  for n,(l,v) in enumerate(zip(['체력','지상 이동','공중 이동','점프','무게'],c['values'])):e += [text('STAT / '+str(n),l,504,520+n*64,216,28,'muted'),text('VALUE / '+str(n),str(int(v)) if v==int(v) else str(v),728,520+n*64,104,28,align='right')]
  for n,(tk,tl) in enumerate(tech):e.append(button('TECH / '+tk,tl,880,336+n*104,192,88,None if tk==t else 'shop-character-'+c['key']+'-'+tk,'selected' if tk==t else 'default',30))
  e += [rect('VIDEO / area',1144,360,640,360,'bg',1,12),text('VIDEO / heading',label+' 영상',1168,384,592,32,'gold',weight='600'),button('VIDEO / play','▶',1416,456,96,96,k+'-video','ghost',36),text('VIDEO / note','영상 준비 중',1168,584,592,28,'muted',align='center'),text('VIDEO / slot','VIDEO/'+c['key']+'/'+t,1168,664,592,24,'muted',align='center'),button('PRACTICE','획득 전 연습',1104,784,720,80,k+'-practice','default',32)]
  for n,a in enumerate(chars):
   x=96+n*264;e += [rect('ROSTER / '+a['key'],x,912,248,120),image(a['key'],x+8,920,80,104,slots[a['key']],'IMG / roster '+a['key']),button('ROSTER / hit '+a['key'],a['name']+(' ✓' if a['key']==c['key'] else ''),x+88,912,160,120,None if a['key']==c['key'] else 'shop-character-'+a['key']+'-light','selected' if a['key']==c['key'] else 'ghost',28)]
  if c['key']=='ja-hyun':e += [text('PAY / rule','유일한 무료 캐릭터',1200,880,624,24,'muted',align='center'),button('PAY / free','보유 중 · 무료 기본 지급',1200,920,624,112,None,'disabled',32)]
  else:e += [text('PAY / rule','한 재화로 전액 구매 · 합산 사용 미정',1200,880,624,24,'muted',align='center'),button('PAY / stone','조약돌 · 미정',1200,920,296,112,k+'-stone','default',28),button('PAY / rainbow','무지개돌 · 미정',1512,920,312,112,k+'-rainbow','primary',28)]
  add(s)
items=[('pebble-yoyo','조약돌 요요','attack','재사용 대기시간 10초\n전방으로 발사·회수하며 상대를 견제합니다.'),('iron-armor','철갑옷','defense','무게 +5%\n지상 이동 속도 -5%'),('boxing-gloves','복싱 글러브','attack','유란의 기술 목록으로 교체\n속도 보너스 없음'),('thorns','균형 신기','special','공중 이동 속도 +5%\n지상 이동 속도 -5%'),('explosive-gloves','도약 장갑','special','점프 속도 +5%\n무게 -5%'),('ultimate-charm','집중 신기','special','유효 적중 시 궁극기 게이지 +4\n지상 이동 속도 -5%'),('phoenix-revive','활공 신기','special','중력 -5%\n공중 이동 속도 -5%')]
def icon(e,key,x,y,size,n):
 if key=='pebble-yoyo':e.append(image(key,x,y,size,size,'IMG/accessory/pebble-yoyo',n))
 else:e += [rect(n,x,y,size,size,'bg',1,8),text(n+' / slot',('이미지\n준비 중' if size<200 else 'IMG/accessory/\n'+key),x+8,y+size/2-32,size-16,20,'muted',align='center')]
for fil in ['all','attack','defense','special']:
 s=base('shop-artifacts-'+fil,'신기','artifact');e=s['elements']
 if fil!='all':s['clone_of']='shop-artifacts-all'
 e += [text('CATALOG / note','가격 미정 · 무지개돌 전용 · 판매·분류는 설계 예시',320,296,1504,26,'muted')]
 for i,(f,l) in enumerate([('all','전체'),('attack','공격'),('defense','방어'),('special','특수')]):e.append(button('FILTER / '+f,l,96,336+i*136,192,112,None if f==fil else 'shop-artifacts-'+f,'selected' if f==fil else 'default',32))
 visible=[i for i in items if fil=='all' or i[2]==fil]
 for i,(key,label,_,desc) in enumerate(visible):
  x=320+(i%4)*384;y=344+(i//4)*272;e += [rect('ITEM / '+key,x,y,352,248,'panel',.95,16)]
  icon(e,key,x+24,y+16,112,'IMG / item '+key)
  e += [text('ITEM / name '+key,label,x+152,y+32,184,26,weight='600'),text('ITEM / price '+key,'무지개돌 · 미정',x+152,y+104,184,22,'muted'),button('ITEM / open '+key,'상세 보기',x+16,y+160,320,72,'shop-artifact-'+key+'-from-'+fil,'default',28)]
 e += [text('CATALOG / count',f'표시 상품 {len(visible)} / 7 · 기존 보유는 유지',320,944,1504,28,'muted')];add(s)
for fil in ['all','attack','defense','special']:
 for key,label,kind,desc in items:
  if fil!='all' and kind!=fil:continue
  k='shop-artifact-'+key+'-from-'+fil;s=base(k,'신기 상세','artifact');e=s['elements'];s['detail_of']=key;s['return_filter']=fil
  if not (fil=='all' and key=='pebble-yoyo'):s['clone_of']='shop-artifact-pebble-yoyo-from-all'
  next(v for v in e if v['name']=='BACK')['dest']='shop-artifacts-'+fil
  e += [text('ART / name',label,96,320,720,48,weight='700')];icon(e,key,176,432,416,'IMG / selected-artifact')
  e += [rect('ART / panel',880,336,944,520,'panel',.95,16),text('ART / heading','신기 설명',920,376,864,36,'gold',weight='600'),text('ART / description',desc,920,456,864,32),text('ART / note','자현·나비 사용 가능' if key=='pebble-yoyo' else '현재 게임에서 비활성 · 판매 여부 미정',920,600,864,28,'mint'),text('ART / currency','구매 재화 · 무지개돌만',920,672,864,28,'muted'),text('ART / price','가격 미정',920,728,864,40,'gold',weight='700'),button('PRACTICE','획득 전 연습',96,920,736,112,k+'-practice','default',32),button('PAY / info','구매 조건 확인',880,920,944,112,k+'-buy','primary' if key=='pebble-yoyo' else 'default',32)]
  add(s)
for typ,title in [('stone','조약돌'),('rainbow','무지개돌')]:
 s=base('shop-'+typ,title,typ);e=s['elements'];
 if typ=='rainbow':s['clone_of']='shop-stone'
 e += [text('PACK / intro','게임에서 얻는 재화 · 제공 방식 미정' if typ=='stone' else '유료 재화 · 현금 패키지 가격 미정',96,312,1728,32,'mint')]
 for i,amount in enumerate([100,500,1000]):
  x=96+i*584;e += [rect('PACK / card '+str(i),x,392,560,464,'panel',.95,16),elem('currency','VEC / '+typ+str(i),x+120,416,320,224,currency=typ,count=i+1),text('PACK / amount '+str(i),f'{title} {amount:,}',x+24,656,512,40,'gold',weight='700',align='center'),text('PACK / sample '+str(i),'수량 예시 · 가격 미정',x+24,728,512,28,'muted',align='center'),button('PACK / open '+str(i),'구성 보기',x,920,560,112,'shop-'+typ+'-pack-'+str(i),'default',32)]
 e += [text('PACK / footnote','두 재화 간 교환과 제공 조건은 아직 정하지 않았어요.' if typ=='stone' else '결제·환불 조건은 아직 정하지 않았어요.',96,880,1728,24,'muted',align='center')];add(s)
# Entry prototype preserves the approved lobby rather than changing its links.
s=copy.deepcopy(next(s for s in old['scenes'] if s['key']=='lobby'));s.update(key='shop-entry',name='MENU09 / Shop-r01 / entry',revision='shop-r01')
for e in s['elements']:
 if e['kind']=='button':e['dest']='shop-entry-pending'
 if e['name']=='NAV / 상점':e['dest']='shop-character-myo-ryung-light'
add(s)
def modal(origin,key,title,body,blocked=None):
 o=next(s for s in scenes if s['key']==origin);s=copy.deepcopy(o);s.update(key=key,name='MENU09 / Shop-r01 / '+key,title=title,modal=True,clone_of=origin)
 for e in s['elements']:
  if e['kind']=='button':e['dest']=None
 s['elements'] += [rect('MODAL / scrim',0,0,1920,1080,'bg',.85,0),rect('MODAL / panel',464,288,992,504,'panel',1,20),text('MODAL / eyebrow','FOREST ARENA · 설계 검토',512,328,864,24,'gold'),text('MODAL / title',title,512,376,864,44,weight='700'),text('MODAL / body',body,512,464,864,30,'muted')]
 if blocked:s['elements'] += [button('MODAL / close','닫기',512,672,424,80,origin,'default',30),button('MODAL / blocked',blocked,960,672,448,80,None,'disabled',28)]
 else:s['elements'].append(button('MODAL / close','닫기',512,672,896,80,origin,'primary',30))
 add(s)
# All current character states preserve exact character/skill/payment context on close.
for s in list(scenes):
 if not s['key'].startswith('shop-character-'):continue
 key=s['key'];c=next(c for c in chars if key.startswith('shop-character-'+c['key']+'-'))
 modal(key,key+'-video','영상 준비 중','아직 준비된 기술 영상이 없습니다.\n캐릭터와 기술 분류를 먼저 살펴보세요.')
 modal(key,key+'-practice','획득 전 연습','연습 진입 화면은 후속 연결 대상입니다.\n현재 시안에서 실제 경기를 시작하지 않습니다.')
 if c['key']!='ja-hyun':
  for pay,label in [('stone','조약돌'),('rainbow','무지개돌')]:modal(key,key+'-'+pay,'구매 조건 확인',c['name']+' · '+label+'로 전액 구매\n가격은 아직 정하지 않았어요.\n두 재화를 합산하지 않습니다.','가격 확정 후 구매')
for s in list(scenes):
 if not s.get('detail_of') or s.get('modal'):continue
 key=s['key'];modal(key,key+'-practice','획득 전 연습','신기의 연습 연결은 후속 검토 대상입니다.\n현재 시안에서 실제 경기를 시작하지 않습니다.')
 modal(key,key+'-buy','구매 조건 확인',next(i[1] for i in items if i[0]==s['detail_of'])+' · 무지개돌만\n가격과 판매 조건은 아직 정하지 않았어요.','가격 확정 후 구매')
for typ,title in [('stone','조약돌'),('rainbow','무지개돌')]:
 for i,amount in enumerate([100,500,1000]):modal('shop-'+typ,'shop-'+typ+'-pack-'+str(i),'상품 구성 확인',f'{title} {amount:,}개 · 수량 예시\n'+('제공 방식과 비용은 아직 정하지 않았어요.' if typ=='stone' else '현금 가격과 결제 조건은 아직 정하지 않았어요.'),'조건 확정 후 구매')
modal('shop-entry','shop-entry-pending','다음 설계 묶음','이번에는 상점 화면을 검토합니다.\n다른 메뉴는 기존 승인 원본과 후속 묶음에서 확인합니다.')
# Distinct reviews of store loading/error/empty/insufficient states, entered only from review guide.
modal('shop-character-myo-ryung-light','shop-loading','상점을 불러오는 중','잠시만 기다려 주세요.\n상품 정보를 확인하고 있습니다.')
modal('shop-character-myo-ryung-light','shop-error','상점을 불러오지 못했습니다','연결 상태를 확인한 뒤 다시 시도해 주세요.')
err=scenes[-1];err['elements'][-1]=button('MODAL / close','닫기',512,672,424,80,'shop-character-myo-ryung-light','default',30);err['elements'].append(button('MODAL / retry','다시 시도',960,672,448,80,'shop-loading','primary',30))
modal('shop-character-myo-ryung-light','shop-insufficient','잔액 부족 · 상태 예시','필요 재화  —     보유 재화  —\n가격·잔액이 확정된 뒤 다시 확인할 수 있어요.')
s=base('shop-empty','신기','artifact');s['elements'] += [text('EMPTY / title','표시할 상품이 없습니다',336,416,1248,48,weight='700',align='center'),text('EMPTY / body','조건을 바꾸거나 잠시 후 다시 확인해 주세요.',336,520,1248,32,'muted',align='center'),button('EMPTY / reset','전체 상품 보기',672,656,576,104,'shop-artifacts-all','primary',32)];add(s)
# Native 20:9 comparisons. Primary geometry remains centered and unchanged.
for src in ['shop-character-myo-ryung-light','shop-artifacts-all','shop-rainbow']:
 o=next(s for s in scenes if s['key']==src);s=copy.deepcopy(o);s.update(key=src+'-wide',name='MENU09 / Shop-r01 / '+src+'-wide',w=2400,comparison_of=src,clone_of=src)
 for e in s['elements']:
  if e['name'] in ['IMG / character-room','ATMOSPHERE','HEADER','FOOTER']:e['w']=2400
  else:e['x']+=240
  if e['kind']=='button':e['dest']=None
 add(s)
# Exact missing media names, not aliases for unrelated legacy art.
missing=['IMG/accessory/'+k for k,_,_,_ in items if k!='pebble-yoyo']+['VIDEO/'+c['key']+'/'+t for c in chars for t,_ in tech]
s=dict(key='shop-missing',name='MENU09 / Shop-r01 / missing-assets',canonical='MENU09_HANDOFF',title='MISSING ASSETS',revision='shop-r01',w=1920,h=1080,elements=[rect('BG',0,0,1920,1080,'bg',1,0),text('TITLE','MISSING ASSETS · 26개',96,64,1728,48,'gold',weight='700'),text('NOTE','이미지 6종 · 기술 영상 20종 / 신규 런타임 등록 없음',96,152,1728,30,'mint')])
for col in range(2):s['elements'] += [rect('PANEL / '+str(col),96+888*col,248,840,584),text('LIST / '+str(col),'\n'.join(missing[col*13:(col+1)*13]),128+888*col,280,776,26,'muted')]
s['elements'].append(button('GUIDE / back','검토 안내',96,920,1728,112,'shop-handoff','primary',32));add(s)
s=dict(key='shop-handoff',name='MENU09 / Shop-r01 / handoff',canonical='MENU09_HANDOFF',title='상점 검토 안내',revision='shop-r01',w=1920,h=1080,elements=[rect('BG',0,0,1920,1080,'bg',1,0),text('TITLE','MENU09 · 상점 5종 r01',96,64,1728,48,'gold',weight='700'),text('STATUS','이전 6종 승인 완료 · 상점 5종은 검토 대기 · 실제 개발 전',96,152,1728,30,'mint'),rect('LEFT',96,248,840,584),rect('RIGHT',984,248,840,584),text('LEFT / title','승인된 기준과 미정 항목',128,280,776,34,'gold',weight='600'),text('LEFT / body','자현만 무료 · 다른 캐릭터는 재화 택일\n캐릭터 외 상품은 무지개돌만 사용\n수치 가격·보상량·재화 교환은 미정\n현금 패키지 가격·결제·환불은 미정\n\n조약돌/무지개돌 수량은 설계용 예시\n기존 보유를 회수하거나 저장하지 않음\n현재 0원 런타임 가격을 변경하지 않음',128,352,776,28),text('RIGHT / title','화면 검토와 기능 연결',1016,280,776,34,'gold',weight='600'),text('RIGHT / body','별점 대신 기존 CharacterStats 수치 표시\n획득 전 연습 버튼 · 연결 안내 포함\n현재 정식 활성 캐릭터: 자현 · 나비\n현재 활성 신기: 조약돌 요요\n\n기존 6신기는 실제 게임에서 비활성\n신기 분류는 설계 예시 · 내부 ID 유지\n이미지6/영상20은 슬롯 이름으로 표시\n신기 등급·희귀도·추가 피해 없음',1016,352,776,28),button('GUIDE / start','상점 보기',96,920,328,112,'shop-character-myo-ryung-light','primary',30),button('GUIDE / missing','누락 자산',448,920,328,112,'shop-missing','default',30),button('GUIDE / error','오류 상태',800,920,328,112,'shop-error','default',30),button('GUIDE / empty','빈 목록',1152,920,328,112,'shop-empty','default',30),button('GUIDE / balance','잔액 부족',1504,920,320,112,'shop-insufficient','default',30)])
add(s)
# Native overlays share identical content and close to the untouched source board.
# Their 1920 transparent scrim covers the source; close-overlay preserves all current context.
alias={};overlays={};out=[]
for s in scenes:
 if not s.get('modal') or s['key']=='shop-loading':out.append(s);continue
 tail=copy.deepcopy(s['elements'][next(i for i,e in enumerate(s['elements']) if e['name']=='MODAL / scrim'):])
 for e in tail:
  if e['name']=='MODAL / close':e.update(dest=None,action='close-overlay')
 signature=json.dumps(tail,ensure_ascii=False,sort_keys=True)
 if signature in overlays:
  alias[s['key']]=overlays[signature]['key'];continue
 z=dict(key=s['key'],name=s['name'],canonical='MENU09_OVERLAY',title=s['title'],revision='shop-r01',w=1920,h=1080,modal=True,overlay=True,elements=tail)
 overlays[signature]=z;alias[s['key']]=s['key'];out.append(z)
scenes=out
first_overlay=next(s['key'] for s in scenes if s.get('overlay'))
for s in scenes:
 if s.get('overlay') and s['key']!=first_overlay:s['clone_of']=first_overlay
for s in scenes:
 for e in s['elements']:
  if e.get('dest') in alias:e['dest']=alias[e['dest']]
for s in scenes:
 assert len(set(e['name'] for e in s['elements']))==len(s['elements']),s['key']
item_data=[]
for k,n,category,_ in items:
 src=ROOT/'assets/loadouts'/('pebble_yoyo_accessory.tres' if k=='pebble-yoyo' else 'fixtures/'+k.replace('-','_')+'_accessory.tres')
 raw=src.read_text();item_data.append(dict(design_key=k,display_name=n,data_id=re.search(r'accessory_id = &"([^"]+)"',raw).group(1),source=str(src.relative_to(ROOT)),proposed_filter=category))

spec=dict(version=1,approval_batch='shop-r01',base_keys=['shop-character-myo-ryung-light','shop-artifacts-all','shop-artifact-pebble-yoyo-from-all','shop-stone','shop-rainbow'],colors=C,missing_assets=missing,characters=chars,item_data=item_data,scenes=scenes)
(P/'scene-spec.json').write_text(json.dumps(spec,ensure_ascii=False,indent=2)+'\n');print('boards',len(scenes),'base5; missing',len(missing))
