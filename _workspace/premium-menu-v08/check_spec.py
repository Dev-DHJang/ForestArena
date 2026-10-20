"""Static scene geometry/text-width audit. PNG/Penpot validation is recorded separately."""
import json, math
from pathlib import Path
from PIL import ImageFont
TASK=Path(__file__).resolve().parent
p=json.loads((TASK/'scene-spec.json').read_text());errors=[];warnings=[]
fontroot=Path.home()/'Library/Fonts';fonts={}
for scene in p['scenes']:
 for e in scene['elements']:
  tag=scene['name']+' / '+e['name']
  if min(e['w'],e['h'])<=0:errors.append([tag,'nonpositive size'])
  if e['x']<0 or e['y']<0 or e['x']+e['w']>1920.01 or e['y']+e['h']>1080.01:errors.append([tag,'outside frame',e['x'],e['y'],e['w'],e['h']])
  if e['kind'] in ['button','hotspot'] and min(e['w'],e['h'])<72:errors.append([tag,'touch smaller than72'])
  if e['kind']=='text':
   ft='Bold' if int(e.get('weight',500))>=700 else 'Regular';k=(ft,e['size'])
   if k not in fonts:fonts[k]=ImageFont.truetype(str(fontroot/f'NotoSansCJKkr-{ft}.otf'),e['size'])
   f=fonts[k]
   for line in e['text'].splitlines():
    length=f.getlength(line)
    if length>e['w']+1:errors.append([tag,'line too wide',round(length,1),e['w'],line])
   if e['y']+e['h']>1032.1:errors.append([tag,'text below safe margin',e['y']+e['h']])
   if e['x']<96 or e['x']+e['w']>1824.1:errors.append([tag,'text outside horizontal safe area'])
  if e.get('dest') and e['dest'] not in set(s['name'] for s in p['scenes'])|set(p['externalDestinations']):errors.append([tag,'unresolved destination',e['dest']])
# Ignore obscured source layers below the modal scrim; compare visible native text boxes.
for scene in p['scenes']:
 es=scene['elements'];start=next((i for i,e in enumerate(es) if e['name']=='MODAL / scrim'),0);es=es[start:]
 ts=[e for e in es if e['kind']=='text'];bs=[e for e in es if e['kind']=='button']
 for i,a in enumerate(ts):
  for b in ts[i+1:]+bs:
   ix=min(a['x']+a['w'],b['x']+b['w'])-max(a['x'],b['x']);iy=min(a['y']+a['h'],b['y']+b['h'])-max(a['y'],b['y'])
   if ix>2 and iy>2:errors.append([scene['name'],'visible text box overlaps text/button',a['name'],b['name'],ix,iy])
# Behavior-level invariants for selection, category retention, and empty preset validation.
byname={s['name']:s for s in p['scenes']}
for scene in p['scenes']:
 name=scene['name']
 if name=='SCR_05_CharacterDetail' or name.startswith('MENU08 / SCR_05_CharacterDetail / '):
  hero=next(e['key'] for e in scene['elements'] if e['kind']=='image' and e['x']==264 and e['w']==856)
  action=next(e for e in scene['elements'] if e['name']=='BUTTON / 편성에 넣기');target=byname[action['dest']]
  if target.get('selection',{}).get('character')!=hero:errors.append([name,'selected character lost on preset action'])
 if '-filter-' in name and any(v in name for v in ['SCR_06_AccessoryCollection','SCR_07_AccessoryDetail']):
  category=name.split('-filter-',1)[1]
  if category!='전체':
   names={'이동':{'균형 장신구','도약 장갑','활공 장신구'},'방어':{'철갑옷'},'기술':{'복싱 글러브','집중 장신구'}}[category]
   for e in scene['elements']:
    if e['kind']=='hotspot' and e['name'].startswith('SELECT / '):
     if e['name'].split('SELECT / ',1)[1] not in names:errors.append([name,'item outside category',e['name']])
     if not e['dest'].endswith('-filter-'+category):errors.append([name,'category lost on item click'])
    if e['name']=='BUTTON / 상세 · 비교' or ('SCR_07_AccessoryDetail' in name and e['name']=='BUTTON / 뒤로'):
     if not e['dest'].endswith('-filter-'+category):errors.append([name,'category lost on detail/back'])
 if scene.get('selection') and name.startswith('MENU08 / SCR_08_Preset / '):
  selected=scene['selection']['character']
  for e in scene['elements']:
   if e.get('dest') in byname and (e['name'] in ['BUTTON / 취소','BUTTON / 저장','BUTTON / 편성 적용','BUTTON / 저장 확인','BUTTON / 적용 확인','BUTTON / 뒤로','SELECT / 편성 1']):
    target=byname[e['dest']]
    if target.get('selection') and target['selection']['character']!=selected:errors.append([name,'character changed across save/apply/cancel/back',e['name']])
for i in [1,2,3]:
 name='MENU08 / SCR_08_Preset / slot-'+str(i)
 for e in byname[name]['elements']:
  if e['name'] in ['BUTTON / 저장','BUTTON / 편성 적용'] and e.get('dest')!='MENU08 / SelectionRequired':errors.append([name,'empty preset signals success'])

report={'scope' :'static geometry only; not a PNG/Penpot visual pass','base':len(p['base']),'scenes':len(p['scenes']),'legacyMapping':len(p['legacyMapping']),'errors':errors,'warnings':warnings}
(TASK/'geometry-audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2));print(json.dumps(report,ensure_ascii=False,indent=2));raise SystemExit(bool(errors))
