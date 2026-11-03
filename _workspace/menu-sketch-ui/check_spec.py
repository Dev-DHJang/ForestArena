"""Check reference coverage, touch targets, navigation and approval gates."""
import json,hashlib
from pathlib import Path
P=Path(__file__).resolve().parent
j=json.loads((P/'scene-spec.json').read_text());scenes={s['key']:s for s in j['scenes']};errors=[]
for s in scenes.values():
 margin=96+(240 if s.get('comparison_of') else 0)
 for e in s['elements']:
  if e['kind'] in ['text','button']:
   if e['x']<margin or e['y']<48 or e['x']+e['w']>s['w']-margin or e['y']+e['h']>1032:errors.append([s['key'],e['name'],'safe area'])
  if e['kind']=='button':
   if min(e['w'],e['h'])<72:errors.append([s['key'],e['name'],'touch target'])
   if e.get('dest') and e['dest'] not in scenes:errors.append([s['key'],e['name'],'missing destination'])
   if s.get('modal') and not e['name'].startswith('MODAL /') and e.get('dest'):errors.append([s['key'],e['name'],'modal background active'])
register=json.loads((P/'screen-register.json').read_text())['screens']
assert len(register)==21 and len({r['source_name'] for r in register})==21
for r in register:
 if hashlib.sha256((P/r['reference_copy']).read_bytes()).hexdigest()!=r['source_sha256']:errors.append([r['source_name'],'source changed'])
 if r['approval_status']!='pending' or r['runtime_approved']:errors.append([r['title'],'approval gate violated'])
for key,dest in [('room-leave','room'),('room-ready-leave','room-ready')]:
 b=next(e for e in scenes[key]['elements'] if e['name']=='MODAL / cancel')
 if b['dest']!=dest:errors.append([key,'cancel loses state'])
result={'status':'pass' if not errors else 'fix','reference_count':len(register),'representatives':j['base_keys'],'boards':len(scenes),'errors':errors}
(P/'spec-check.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print(json.dumps(result,ensure_ascii=False));raise SystemExit(bool(errors))
