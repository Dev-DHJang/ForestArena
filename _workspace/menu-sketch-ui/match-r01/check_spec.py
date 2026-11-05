from pathlib import Path
import json,collections
P=Path(__file__).resolve().parent;j=json.loads((P/'scene-spec.json').read_text());ss={s['key']:s for s in j['scenes']};errors=[]
for s in ss.values():
 names=[e['name'] for e in s['elements']]
 if len(set(names))!=len(names):errors.append([s['key'],'duplicate-layer'])
 margin=336 if s.get('comparison_of') else 96
 for e in s['elements']:
  if e.get('dest') and e['dest'] not in ss:errors.append([s['key'],e['name'],'missing-target'])
  if e.get('dest')==s['key']:errors.append([s['key'],e['name'],'self-link'])
  if e['kind'] in ['text','button'] and not (e['x']>=margin and e['y']>=48 and e['x']+e['w']<=s['w']-margin and e['y']+e['h']<=1032):errors.append([s['key'],e['name'],'safe'])
  if e['kind']=='button':
   if min(e['w'],e['h'])<72:errors.append([s['key'],e['name'],'touch'])
   if e['state']=='disabled' and (e.get('dest') or e.get('action')):errors.append([s['key'],e['name'],'disabled-active'])
   if s.get('modal') and not e['name'].startswith('MODAL /') and (e.get('dest') or e.get('action')):errors.append([s['key'],e['name'],'modal-background-active'])
  if s.get('comparison_of') and (e.get('dest') or e.get('action')):errors.append([s['key'],'comparison-active'])
def el(k,n):return next(e for e in ss[k]['elements'] if e['name']==n)
for k in ['rooms-solo','rooms-solo-selected','rooms-solo-full']:
 if el(k,'FILTER / solo')['state']!='selected':errors.append([k,'filter'])
 if el(k,'ROOM ROW / 0')['dest']!=(None if k=='rooms-solo-selected' else 'rooms-solo-selected'):errors.append([k,'selection-context'])
 if el(k,'ROOM ROW / 1')['dest']!=(None if k=='rooms-solo-full' else 'rooms-solo-full'):errors.append([k,'full-context'])
for k in ['rooms-full-selected','rooms-solo-full']:
 if el(k,'ACTION / join')['state']!='disabled':errors.append([k,'full-join'])
for k,d in [('ai-room','mode-select'),('room-normal','rooms-selected'),('room-solo','rooms-solo-selected'),('room-team','rooms-team-selected')]:
 for suffix in ['', '-ready']:
  origin=k+suffix
  if el(origin+'-leave','MODAL / cancel')['dest']!=origin:errors.append([origin,'cancel-context'])
  if el(origin+'-leave','MODAL / leave').get('action')!='close-overlay':errors.append([origin,'leave-context'])
  if len([e for e in ss[origin]['elements'] if e['name'].startswith('PARTY / slot ')])!=8:errors.append([origin,'capacity-slots'])
for k in ['normal-match-info','rank-party-info','rank-match-info','rank-invite-info','start-info']:
 if el(k,'MODAL / unavailable')['state']!='disabled':errors.append([k,'unapproved-action'])
if el('rank-lobby','RANK / tier')['text']!='실버 3 · 예시':errors.append(['rank-tier-not-example'])
if j['missing_assets']!=['IMG/rank/emblem/silver-3']:errors.append(['rank-slot'])
for k in ['code-input','code-filled','create-room','create-team']:
 for n in ['BACK', 'CODE / cancel' if k.startswith('code-') else 'CREATE / cancel']:
  if el(k,n).get('action')!='close-overlay':errors.append([k,n,'cancel-context'])
r=dict(status='fix' if errors else 'pass',boards=len(ss),representatives=len(j['base_keys']),comparisons=sum(bool(s.get('comparison_of')) for s in ss.values()),overlays=sum(bool(s.get('overlay')) for s in ss.values()),room_contexts=4,leave_contexts=8,errors=errors);(P/'spec-check.json').write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n');print(r);raise SystemExit(bool(errors))
