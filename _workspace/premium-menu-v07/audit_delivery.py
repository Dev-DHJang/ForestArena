"""Acceptance audit of actual Penpot records, scene links and delivered exports."""
from pathlib import Path
import csv,hashlib,json,re,argparse
from PIL import Image
ROOT=Path(__file__).resolve().parents[2];TASK=Path(__file__).resolve().parent
parser=argparse.ArgumentParser();parser.add_argument('--runtime-baseline',default='runtime-baseline.json');args=parser.parse_args()
spec=json.loads((TASK/'scene-spec.json').read_text());scenes=spec['scenes'];base=set(spec['base'])
baseline=json.loads((TASK/'baseline-audit.json').read_text());names={s['name'] for s in scenes}|{s['name'] for s in baseline['sources']}
issues=[]
def check(ok,msg):
 if not ok:issues.append(msg)
check(len(base)==13,'Expected 13 base menus')
check(len({s['name'] for s in scenes})==len(scenes),'Duplicate scenes')
valid_slots={r['asset_slot'] for r in csv.DictReader((ROOT/'assets/ui/asset-requirements.csv').open())}
controls=[];images=[]
for s in scenes:
 for e in s['elements']:
  d=e.get('dest')
  if d:check(d in names,f"Missing destination {s['name']} -> {d}")
  if e['kind'] in ['button','hotspot']:
   check(e['w']>=72 and e['h']>=72,f"Small touch target {s['name']} / {e['name']}")
   check(e['x']>=96 and e['y']>=48 and e['x']+e['w']<=1824.01 and e['y']+e['h']<=1032.01,f"Unsafe touch target {s['name']} / {e['name']}")
   controls.append({'screen':s['name'],'control':e['name'],'x':e['x'],'y':e['y'],'width':e['w'],'height':e['h'],'destination':d or '', 'state':e.get('state','default')})
  if e['kind']=='image' and e.get('slot','').startswith('IMG/'):check(e['slot'] in valid_slots,'Undefined official image slot '+e['slot'])
  if e['kind']=='image':images.append({'screen':s['name'],'shape':e['name'],'slot':e.get('slot') or 'DESIGN/bg/'+e['key'],'key':e['key']})
  if e['kind']=='text':check(not re.search(r'[\u3040-\u30ff]',e['text']),f"Unexpected Japanese text {s['name']}")
for name,digest in json.loads((TASK/args.runtime_baseline).read_text()).items():check(hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==digest,'Runtime/source changed '+name)
for rows,file in [(controls,'control-coordinates.csv'),(images,'image-mapping.csv')]:
 with (TASK/file).open('w',newline='') as f:
  w=csv.DictWriter(f,fieldnames=list(rows[0]),lineterminator="\n");w.writeheader();w.writerows(rows)
assets=[]
for p in sorted((ROOT/'assets/ui/premium-menu-v07').rglob('*')):
 if p.suffix in ['.png','.svg']:
  v={'path':str(p.relative_to(ROOT)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size}
  if p.suffix=='.png':
   im=Image.open(p);im.verify();im=Image.open(p);v.update(width=im.width,height=im.height)
  assets.append(v)
check(len([a for a in assets if a['path'].endswith('.png')])==6,'Six new background PNGs required')
check(len([a for a in assets if a['path'].endswith('.svg')])==16,'Sixteen original SVG icons required')
manifest=json.loads((ROOT/'assets/ui/premium-menu-v07/manifest.json').read_text())
for a in manifest['assets']:
 check(hashlib.sha256((ROOT/a['path']).read_bytes()).hexdigest()==a['sha256'],'Asset manifest hash differs '+a['path'])
for a in manifest['approved_character_sources']:
 check(hashlib.sha256((ROOT/a['design_backup']).read_bytes()).hexdigest()==a['sha256'],'Approved design backup changed '+a['character_id'])
actualpath=TASK/'final-audit.json'
if actualpath.exists():
 actual=json.loads(actualpath.read_text());check(not actual['outsideChanges'],'Outside source screens changed');check(not actual['missingOriginalComponents'],'Original components missing');check(not actual['changedLegacyLinks'],'Legacy link identities/destinations changed')
 check(len(actual['base'])==13,'Actual base menus missing');check(len(actual['scenes'])==len(scenes),'Actual scene count differs');check(len(actual['comparisons'])==4,'Four 20:9 comparisons required')
 check({s['name'] for s in actual['scenes']}=={s['name'] for s in scenes},'Actual exported scenes differ from specification')
 check(len({s['filename'] for s in actual['scenes']+actual['comparisons']})==len(scenes)+4,'Duplicate export filenames')
 check(actual['currentComponents']>=len(baseline['components'])+25,'Premium components missing')
 check(not actual['missingDestinations'],'Actual destinations missing');check(not actual['textIssues'],'Actual text clipping/overflow');check(not actual['touchIssues'],'Actual touch bounds issues')
 check(not actual.get('componentIssues',[]),'Actual component state mismatch');check(actual.get('componentUsage',0)>0,'Actual component usage missing');
 check(not actual.get('shapeIssues',[]),'Actual native shape mismatch');check(not actual.get('comparisonIssues',[]),'Actual comparison content mismatch')
 originals={s['name']:s['id'] for s in baseline['sources'] if s['target']}
 check({s['name']:s['id'] for s in actual['base']}==originals,'Original base menu IDs changed')
 check(actual['sourceCount']==len(scenes) and actual['prototypeCount']==len(scenes),'Native or wired prototype count incomplete')
 for k in ['baseIdIssues','officialScreenIssues','legacyChildIssues','sourceControlIssues']:check(not actual.get(k,[]),'Actual '+k)
 check(len(actual.get('officialIds',[]))==24,'Official 24 screen IDs missing')
 check(len(actual.get('designExports',[]))==13,'Thirteen 1920 exports required')
 states={(s['name'],e['name'],round(e['x'],4),round(e['y'],4)):e.get('state','default') for s in scenes for e in s['elements'] if e['kind'] in ['button','hotspot']}
 actual_controls=[]
 for c in actual.get('actualControls',[]):
  actual_controls.append({'screen':c['scene'],'control':c['name'],'source_shape_id':c['sourceId'],'prototype_hotspot_id':c['id'] or '', 'x':c['x'],'y':c['y'],'width':c['w'],'height':c['h'],'active':c['active'],'destination':c['destinationName'] or '', 'destination_id':c['destinationId'] or '', 'state':states.get((c['scene'],c['name'],round(c['x'],4),round(c['y'],4)),'default'),'transition_ms':(c['animation'] or {}).get('duration',''),'x_1280':round(c['x']*2/3,3),'y_1280':round(c['y']*2/3,3),'width_1280':round(c['w']*2/3,3),'height_1280':round(c['h']*2/3,3)})
 check(len(actual_controls)==len(controls),'Actual control coordinate count differs')
 if actual_controls:
  with (TASK/'control-coordinates.csv').open('w',newline='') as f:
   w=csv.DictWriter(f,fieldnames=list(actual_controls[0]),lineterminator="\n");w.writeheader();w.writerows(actual_controls)
 exported=[]
 for s in actual['scenes']+actual['comparisons']+actual.get('designExports',[]):
  p=TASK/'exports'/s['filename'];check(p.exists(),'Missing export '+p.name)
  if p.exists():
   im=Image.open(p);im.verify();im=Image.open(p);check(im.size==tuple(s['outputSize']),'Wrong export size '+p.name)
   expected=(1600,720) if s in actual['comparisons'] else (1920,1080) if s in actual.get('designExports',[]) else (1280,720)
   check(im.size==expected,'Wrong required output dimensions '+p.name)
   exported.append({**s,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
 (TASK/'export-hashes.json').write_text(json.dumps(exported,ensure_ascii=False,indent=2))
else:issues.append('Actual Penpot audit not yet saved')
report={'status':'PASS' if not issues else 'FIX','baseMenus':len(base),'sceneCount':len(scenes),'controls':len(controls),'imageMappings':len(images),'assets':assets,'issues':issues}
(TASK/'delivery-audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2));print(json.dumps({k:v for k,v in report.items() if k!='assets'},ensure_ascii=False,indent=2))
raise SystemExit(bool(issues))
