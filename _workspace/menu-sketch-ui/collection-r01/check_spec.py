import json,hashlib
from pathlib import Path
P=Path(__file__).resolve().parent
j=json.loads((P/'scene-spec.json').read_text());scenes={s['key']:s for s in j['scenes']};errors=[]
for s in scenes.values():
 if len(set(e['name'] for e in s['elements']))!=len(s['elements']):errors.append([s['key'],'duplicate layer names'])
 margin=336 if s.get('comparison_of') else 96
 for e in s['elements']:
  if e['kind'] in ['text','button'] and (e['x']<margin or e['y']<48 or e['x']+e['w']>s['w']-margin or e['y']+e['h']>1032):errors.append([s['key'],e['name'],'safe area'])
  if e['kind']=='button':
   if min(e['w'],e['h'])<72:errors.append([s['key'],e['name'],'touch'])
   if e.get('dest') and e['dest'] not in scenes:errors.append([s['key'],e['name'],'dest'])
   if s.get('modal') and not e['name'].startswith('MODAL /') and e.get('dest'):errors.append([s['key'],e['name'],'modal background active'])
  if e['kind']=='text' and any(x in e['text'] for x in ['전설','희귀','영웅 등급']):errors.append([s['key'],'rarity'])
# All closures must restore their exact underlay source.
for s in scenes.values():
 if not s.get('modal'):continue
 close=next(e for e in s['elements'] if e['name'] in ['MODAL / close','MODAL / cancel']);dest=scenes[close['dest']]
 orig=[{**e,'dest':None} if e['kind']=='button' else e for e in dest['elements']]
 if s['elements'][:len(orig)]!=orig:errors.append([s['key'],'close loses context'])
register=json.loads((P.parent/'screen-register.json').read_text())['screens']
if len([r for r in register if r['group']=='representative' and r['approval_status']=='approved'])!=3:errors.append(['approval count'])
if any(r['runtime_approved'] for r in register):errors.append(['runtime gate'])
result=dict(status='fix' if errors else 'pass',boards=len(scenes),base_keys=j['base_keys'],errors=errors)
(P/'spec-check.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print(json.dumps(result,ensure_ascii=False));raise SystemExit(bool(errors))
