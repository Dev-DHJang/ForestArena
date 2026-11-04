from pathlib import Path
import json
P=Path(__file__).resolve().parent;j=json.loads((P/'scene-spec.json').read_text());scenes={s['key']:s for s in j['scenes']};errors=[]
for s in scenes.values():
 names=[e['name'] for e in s['elements']]
 if len(names)!=len(set(names)):errors.append([s['key'],'duplicate element'])
 m=336 if s.get('comparison_of') else 96
 for e in s['elements']:
  if e['kind'] in ['text','button'] and not (e['x']>=m and e['y']>=48 and e['x']+e['w']<=s['w']-m and e['y']+e['h']<=1032):errors.append([s['key'],e['name'],'safe'])
  if e['kind']=='button' and min(e['w'],e['h'])<72:errors.append([s['key'],e['name'],'touch'])
  if e.get('dest') and e['dest'] not in scenes:errors.append([s['key'],e['name'],'missing destination'])
  if s.get('modal') and e['name'].startswith('MODAL /') is False and e.get('dest'):errors.append([s['key'],e['name'],'modal background active'])
 if s.get('comparison_of') and any(e.get('dest') for e in s['elements']):errors.append([s['key'],'comparison active'])
ids=['daily-play','daily-win','weekly-play','weekly-win','first-play','ten-play','all-characters']
for id in ids:
 if not any(e['name']=='ROW / '+id for s in scenes.values() for e in s['elements']):errors.append([id,'missing actual id'])
if len([e for e in scenes['mission-attendance']['elements'] if e['name'].startswith('ATT / day')])!=28:errors.append(['attendance count'])
r=dict(status='fix' if errors else 'pass',boards=len(scenes),actual_record_ids=ids,errors=errors);(P/'spec-check.json').write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n');print(r);raise SystemExit(bool(errors))
