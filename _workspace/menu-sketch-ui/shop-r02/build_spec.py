from pathlib import Path
import json,copy
P=Path(__file__).resolve().parent
old=json.loads((P.parent/'shop-r01/scene-spec.json').read_text());new=copy.deepcopy(old);scenes=new['scenes'];new['approval_batch']='shop-r02';new['base_keys'][0]='shop-characters-list'
source=next(s for s in scenes if s['key']=='shop-character-myo-ryung-light')
# Reuse the shared shop header/navigation; all card contents remain editable.
listing=dict(key='shop-characters-list',name='MENU09 / Shop-r02 / shop-characters-list',canonical='SCR_19_Shop',title='캐릭터 목록',revision='shop-r02',w=1920,h=1080,elements=copy.deepcopy(source['elements'][:12]))
for e in listing['elements']:
 if e['name']=='SHOP TAB / character':e['dest']=None
listing['elements'] += [dict(kind='text',name='LIST / intro',x=96,y=296,w=1728,h=38,text='캐릭터를 선택해 상세 정보와 구매 조건을 확인하세요',size=26,color='muted',weight='500',align='left')]
slot={'myo-ryung':'IMG/char/rabbit/full','ja-hyun':'IMG/char/mouse/full','nabi':'IMG/char/roster/cat','yu-ran':'DESIGN/char/yu-ran/portrait'}
# Ja-hyun first, followed by the established roster. No new character or price data.
chars={c['key']:c for c in old['characters']}
for i,k in enumerate(['ja-hyun','myo-ryung','nabi','yu-ran']):
 c=chars[k];listing['elements'].append(dict(kind='card',name='CHARACTER CARD / '+k,x=96+i*440,y=352,w=408,h=504,key=k,slot=slot[k],title=c['name'],role=c['role'],price='무료 · 기본 지급' if k=='ja-hyun' else '조약돌/무지개돌 · 미정',dest='shop-character-'+k+'-light',state='default'))
listing['elements'].append(dict(kind='text',name='LIST / footnote',x=96,y=944,w=1728,h=42,text='캐릭터 4종 · 가격과 보유 표시는 설계용 예시',size=28,color='muted',weight='500',align='left'))
# Every category entry opens the list; detail quick-switches remain available.
changed=[]
for s in scenes:
 edits=[]
 for e in s['elements']:
  if e.get('dest')=='shop-character-myo-ryung-light' and e['name'] in ['SHOP TAB / character','NAV / 상점','GUIDE / start','MODAL / close']:e['dest']='shop-characters-list';edits.append(e['name']+'/entry')
  if s['key'].startswith('shop-character-') and not s.get('overlay') and not s.get('comparison_of'):
   if e['name']=='BACK':e['dest']='shop-characters-list';edits.append('BACK')
   if e['name']=='SHOP TAB / character':e['dest']='shop-characters-list';edits.append('category back')
   if e['name']=='TITLE':e['text']='상점 · 캐릭터 상세';edits.append('TITLE')
 if s['key']=='shop-character-myo-ryung-light-wide':
  next(e for e in s['elements'] if e['name']=='TITLE')['text']='상점 · 캐릭터 상세';edits.append('TITLE')
 if s['key']=='shop-handoff':
  e=next(e for e in s['elements'] if e['name']=='TITLE');e['text']='MENU09 · 상점 5종 r02';edits.append('TITLE')
  e=next(e for e in s['elements'] if e['name']=='RIGHT / body');e['text']='캐릭터 목록 → 선택 캐릭터 상세\n상세 뒤로·캐릭터 탭 → 목록 복귀\n획득 전 연습 버튼 · 연결 안내 포함\n현재 정식 활성: 자현·나비 / 조약돌 요요\n\n기존 6신기는 실제 게임에서 비활성\n가격·상품 수량·신기 분류는 미정/예시\n이미지6/영상20은 슬롯 이름으로 표시\n기존 ID·저장·API·게임 규칙 변경 없음';edits.append('flow note')
 if edits:
  s['revision']='shop-r02';s['name']=s['name'].replace('/ Shop-r01 /','/ Shop-r02 /');changed.append(dict(key=s['key'],changes=edits))
# Loading is a static review state based on the new category entry list.
loading=next(s for s in scenes if s['key']=='shop-loading');tail=loading['elements'][next(i for i,e in enumerate(loading['elements']) if e['name']=='MODAL / scrim'):];loading['elements']=copy.deepcopy(listing['elements'])+tail
for e in loading['elements']:
 if e['kind'] in ['button','card'] and not e['name'].startswith('MODAL /'):e['dest']=None
loading['revision']='shop-r02';loading['clone_of']='shop-characters-list';changed.append(dict(key='shop-loading',changes=['list loading background']))
scenes.append(listing)
wide=copy.deepcopy(listing);wide.update(key='shop-characters-list-wide',name='MENU09 / Shop-r02 / shop-characters-list-wide',w=2400,comparison_of='shop-characters-list',clone_of='shop-characters-list')
for e in wide['elements']:
 if e['name'] in ['IMG / character-room','ATMOSPHERE','HEADER','FOOTER']:e['w']=2400
 else:e['x']+=240
 if e['kind'] in ['button','card']:e['dest']=None
scenes.append(wide)
new['revision_changes']=changed
(P/'scene-spec.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n');(P/'revision-changes.json').write_text(json.dumps(changed,ensure_ascii=False,indent=2)+'\n');print('boards',len(scenes),'changed',len(changed),'added2')
