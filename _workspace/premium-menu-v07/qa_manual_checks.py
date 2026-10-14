"""Review recorded actual viewer clicks; does not click or edit Penpot."""
from pathlib import Path
from datetime import datetime,timezone
from urllib.parse import urlparse,parse_qs
import json,hashlib

task=Path(__file__).resolve().parent
manual=json.loads((task/'manual-click-review.json').read_text())
frame_record=json.loads((task/'prototype-frame-index.json').read_text())
frames=frame_record['frames'] if isinstance(frame_record,dict) else frame_record
actual=json.loads((task/'final-audit.json').read_text())
spec=json.loads((task/'scene-spec.json').read_text())
viewer={len(frames)-1-r.get('nativeRootIndex',r.get('index')):r for r in frames}
issues=[];review=[]
if not manual.get('complete'):issues.append('Actual manual review is not complete')
for test in manual['tests']:
 fragment=urlparse(test['url']).fragment
 query=parse_qs(fragment.split('?',1)[1])
 index=int(query['index'][0]);frame=viewer.get(index,{})
 ok=(test['result']=='PASS' and test['expected']==test['observed'] and frame.get('name') in [test['observed'],'PROTO / '+test['observed']] and query.get('file-id')==[actual['file']])
 if not ok:issues.append(test['name'])
 review.append({'test':test['name'],'from':test['from'],'expected':test['expected'],'observed':test['observed'],'viewer_index':index,'observed_native_frame_id':frame.get('id'),'result':'PASS' if ok else 'FIX'})
names=[t['name'] for t in manual['tests']]
if len(set(names))!=len(names):issues.append('Duplicate test names')
for attempt in manual.get('manualAttempts',[]):
 resolved=next((t for t in manual['tests'] if t['name']==attempt.get('resolvedBy')),None)
 if not attempt.get('cause') or not resolved or resolved['result']!='PASS':issues.append('Unresolved manual attempt '+attempt['name'])
screenshots=json.loads((task/'qa-review/viewer-review.json').read_text())['screenshots']
if len(screenshots)!=7:issues.append('Expected seven independently reviewed viewer screenshots')
for screenshot in screenshots:
 if not screenshot['visually_reviewed'] or screenshot['result']!='PASS' or hashlib.sha256((task/'qa-review'/screenshot['filename']).read_bytes()).hexdigest()!=screenshot['sha256']:issues.append('Screenshot review differs '+screenshot['filename'])
observed={t['observed'] for t in manual['tests'] if t['result']=='PASS'}
missing_base=set(spec['base'])-observed
if missing_base:issues.append('Base menus not reviewed in viewer: '+str(sorted(missing_base)))
save=json.loads((task/'penpot-final-save.json').read_text())
if not(save['file']==actual['file'] and not save['isAutosave'] and save['sourceCount']==81 and save['prototypeCount']==81 and save['exports']==81 and save['comparisons']==4 and save['designExports']==13):issues.append('Final saved version does not match delivery')
report={'status':'PASS' if not issues else 'FIX','scope':'Independent review of recorded actual Chrome viewer actions; QA did not perform the clicks','checked_at':datetime.now(timezone.utc).isoformat(),'tests':review,'count':len(review),'base_menu_coverage':sorted(set(spec['base'])&observed),'issues':issues,'viewer_index_rule':'Viewer ordering is reverse of native children order: viewer index = 122 - prototype-frame-index.json index (123 boards)','source_sha256':{n:hashlib.sha256((task/n).read_bytes()).hexdigest() for n in ['manual-click-review.json','prototype-frame-index.json','penpot-final-save.json']},'android_device':'not-run'}
(task/'qa-review/manual-evidence-checks.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
print(json.dumps({k:report[k] for k in ['status','count','issues','viewer_index_rule']},ensure_ascii=False,indent=2))
raise SystemExit(bool(issues))
