from pathlib import Path
import json
P=Path(__file__).resolve().parent;j=json.loads((P/'scene-spec.json').read_text());old=json.loads((P.parent/'shop-r01/scene-spec.json').read_text());ss={s['key']:s for s in j['scenes']};prev={s['key']:s for s in old['scenes']};errors=[]
for s in ss.values():
 m=336 if s.get('comparison_of') else 96
 for e in s['elements']:
  if e['kind'] in ['text','button','card']:
   if e['x']<m or e['y']<48 or e['x']+e['w']>s['w']-m or e['y']+e['h']>1032:errors.append([s['key'],e['name'],'safe area'])
  if e['kind'] in ['button','card']:
   if min(e['w'],e['h'])<72:errors.append([s['key'],e['name'],'touch'])
   if e.get('dest') and e['dest'] not in ss:errors.append([s['key'],e['name'],'destination'])
   if s.get('modal') and not e['name'].startswith('MODAL /') and e.get('dest'):errors.append([s['key'],e['name'],'modal background active'])
 # Existing skill selection and quick roster routes must not turn into category navigation.
 if s['key'].startswith('shop-character-') and not s.get('overlay') and not s.get('comparison_of'):
  original={e['name']:e for e in prev[s['key']]['elements']}
  for e in s['elements']:
   if e['name'].startswith(('TECH /','ROSTER / hit')) and e.get('dest')!=original[e['name']].get('dest'):errors.append([s['key'],e['name'],'detail switch regression'])
  for n in ['BACK','SHOP TAB / character']:
   if next(e for e in s['elements'] if e['name']==n).get('dest')!='shop-characters-list':errors.append([s['key'],n,'not list'])
cards=[e for e in ss['shop-characters-list']['elements'] if e['kind']=='card']
if len(cards)!=4 or {e['key'] for e in cards}!={c['key'] for c in j['characters']}:errors.append(['cards','coverage'])
for e in cards:
 if e['dest']!='shop-character-'+e['key']+'-light':errors.append([e['key'],'wrong detail'])
for s in ss.values():
 if s.get('comparison_of'):continue
 for e in s['elements']:
  if e['name'] in ['SHOP TAB / character','NAV / 상점','GUIDE / start'] and e.get('dest') and e['dest']!='shop-characters-list':errors.append([s['key'],e['name'],'entry bypasses list'])
r=dict(status='fix' if errors else 'pass',boards=len(ss),cards=len(cards),errors=errors);(P/'spec-check.json').write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n');print(r);raise SystemExit(bool(errors))
