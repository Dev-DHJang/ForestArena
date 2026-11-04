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
# Exact mailbox selection and context-preserving detail routes.
def key(mask):return 'mailbox' if mask==0 else 'mailbox-selected' if mask==1 else 'mailbox-selected-'+str(mask)
for mask in range(8):
 es={e['name']:e for e in scenes[key(mask)]['elements']}
 for i in range(3):
  if es['MAIL / select '+str(i)]['dest']!=key(mask^(1<<i)):errors.append([key(mask),'selection',i])
  if es['MAIL / open '+str(i)]['dest']!='mail-detail-'+str(i):errors.append([key(mask),'detail',i])
 if mask==0 and es['MAIL / delete']['state']!='disabled':errors.append(['unselected delete active'])
for suffix,dest in [('entry','life-entry'),('profile','settings-profile'),('view','settings-effects'),('notifications','settings-notifications'),('account','settings-account'),('info','settings-info')]:
 es={e['name']:e for e in scenes['settings-discard-'+suffix]['elements']}
 if es['MODAL / cancel']['dest']!='settings-sound-dirty' or es['MODAL / discard']['dest']!=dest:errors.append(['discard context',suffix])
if any(e.get('dest')=='settings-sound-dirty' for e in scenes['settings-sound-applied']['elements'] if e['name']=='SETTING / value music'):errors.append(['same value dirty'])
r=dict(status='fix' if errors else 'pass',boards=len(scenes),mailbox_selection_states=8,discard_contexts=6,errors=errors);(P/'spec-check.json').write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n');print(r);raise SystemExit(bool(errors))
