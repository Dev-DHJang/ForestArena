from pathlib import Path
import json,hashlib
P=Path(__file__).resolve().parent;j=json.loads((P/'scene-spec.json').read_text());scenes={s['key']:s for s in j['scenes']};errors=[]
for s in scenes.values():
 margin=336 if s.get('comparison_of') else 96
 if len(set(e['name'] for e in s['elements']))!=len(s['elements']):errors.append([s['key'],'duplicate names'])
 if s.get('clone_of') and s['clone_of'] not in scenes:errors.append([s['key'],'clone destination'])
 for e in s['elements']:
  if e['kind'] in ['text','button'] and (e['x']<margin or e['y']<48 or e['x']+e['w']>s['w']-margin or e['y']+e['h']>1032):errors.append([s['key'],e['name'],'safe area'])
  if e['kind']=='button':
   if min(e['w'],e['h'])<72:errors.append([s['key'],e['name'],'touch'])
   if e.get('dest') and e['dest'] not in scenes:errors.append([s['key'],e['name'],'destination'])
   if s.get('modal') and not e['name'].startswith('MODAL /') and (e.get('dest') or e.get('action')):errors.append([s['key'],e['name'],'modal background active'])
   if e.get('action')=='close-overlay' and not s.get('overlay'):errors.append([s['key'],'close-overlay without overlay'])
   if e['state']=='disabled' and (e.get('dest') or e.get('action')):errors.append([s['key'],e['name'],'disabled has action'])
  if e['kind']=='text' and any(t in e['text'] for t in ['장신구','전설','희귀 신기','다이아','나뭇잎']):errors.append([s['key'],e['name'],'display terms'])
 if s.get('overlay') and not any(e.get('action')=='close-overlay' for e in s['elements']):errors.append([s['key'],'missing native close-overlay'])
reg=json.loads((P.parent/'screen-register.json').read_text())['screens']
for r in reg:
 if r['approval_status']=='approved' and not(r.get('approval_evidence') and r['approved_revision']==r['revision']):errors.append([r['title'],'approval evidence'])
 if r['runtime_approved']:errors.append([r['title'],'runtime approval'])
 if hashlib.sha256((P.parent/r['reference_copy']).read_bytes()).hexdigest()!=r['source_sha256']:errors.append([r['source_name'],'reference changed'])
if len([r for r in reg if r['approval_status']=='approved'])!=6:errors.append(['expected six approved reference screens'])
if len(j['missing_assets'])!=26:errors.append(['missing count'])
# Pricing policy is a user direction, numeric prices remain unapproved.
for s in scenes.values():
 if not s['key'].startswith('shop-character-') or s.get('modal') or s.get('comparison_of'):continue
 names={e['name']:e for e in s['elements']}
 if 'ja-hyun' in s['key']:
  if 'PAY / free' not in names or names['PAY / free']['state']!='disabled':errors.append([s['key'],'free/owned state'])
 else:
  if not all(n in names for n in ['PAY / stone','PAY / rainbow']):errors.append([s['key'],'currency choice'])
r=dict(status='fix' if errors else 'pass',reference_total=21,approved_references=6,base_keys=j['base_keys'],boards=len(scenes),overlays=sum(bool(s.get('overlay')) for s in scenes.values()),missing_assets=len(j['missing_assets']),errors=errors)
(P/'spec-check.json').write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n');print(json.dumps(r,ensure_ascii=False));raise SystemExit(bool(errors))
