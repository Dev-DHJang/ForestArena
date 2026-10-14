"""Acceptance audit of actual Penpot records, scene links and delivered exports."""
from pathlib import Path
import csv,hashlib,json,re
from PIL import Image
ROOT=Path(__file__).resolve().parents[2];TASK=Path(__file__).resolve().parent
spec=json.loads((TASK/'scene-spec.json').read_text());scenes=spec['scenes'];base=set(spec['base'])
baseline=json.loads((TASK/'baseline-audit.json').read_text());names={s['name'] for s in scenes}|{s['name'] for s in baseline['sources']}
issues=[]
def check(ok,msg):
 if not ok:issues.append(msg)
check(len(base)==13,'Expected 13 base menus')
check(len({s['name'] for s in scenes})==len(scenes),'Duplicate scenes')
controls=[];images=[]
for s in scenes:
 for e in s['elements']:
  d=e.get('dest')
  if d:check(d in names,f"Missing destination {s['name']} -> {d}")
  if e['kind'] in ['button','hotspot']:
   check(e['w']>=72 and e['h']>=72,f"Small touch target {s['name']} / {e['name']}")
   check(e['x']>=96 and e['y']>=48 and e['x']+e['w']<=1824.01 and e['y']+e['h']<=1048.01,f"Unsafe touch target {s['name']} / {e['name']}")
   controls.append({'screen':s['name'],'control':e['name'],'x':e['x'],'y':e['y'],'width':e['w'],'height':e['h'],'destination':d or '', 'state':e.get('state','default')})
  if e['kind']=='image':images.append({'screen':s['name'],'shape':e['name'],'slot':e.get('slot') or 'DESIGN/bg/'+e['key'],'key':e['key']})
  if e['kind']=='text':check(not re.search(r'[\u3040-\u30ff]',e['text']),f"Unexpected Japanese text {s['name']}")
for name,digest in json.loads((TASK/'runtime-baseline.json').read_text()).items():check(hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==digest,'Runtime/source changed '+name)
for rows,file in [(controls,'control-coordinates.csv'),(images,'image-mapping.csv')]:
 with (TASK/file).open('w',newline='') as f:
  w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
assets=[]
for p in sorted((ROOT/'assets/ui/premium-menu-v07').rglob('*')):
 if p.suffix in ['.png','.svg']:
  v={'path':str(p.relative_to(ROOT)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size}
  if p.suffix=='.png':
   im=Image.open(p);im.verify();im=Image.open(p);v.update(width=im.width,height=im.height)
  assets.append(v)
check(len([a for a in assets if a['path'].endswith('.png')])==6,'Six new background PNGs required')
check(len([a for a in assets if a['path'].endswith('.svg')])==16,'Sixteen original SVG icons required')
actualpath=TASK/'final-audit.json'
if actualpath.exists():
 actual=json.loads(actualpath.read_text());check(not actual['outsideChanges'],'Outside source screens changed');check(not actual['missingOriginalComponents'],'Original components missing');check(not actual['changedLegacyLinks'],'Legacy link identities/destinations changed')
 check(len(actual['base'])==13,'Actual base menus missing');check(len(actual['scenes'])==len(scenes),'Actual scene count differs');check(len(actual['comparisons'])==4,'Four 20:9 comparisons required')
 check(not actual['missingDestinations'],'Actual destinations missing');check(not actual['textIssues'],'Actual text clipping/overflow');check(not actual['touchIssues'],'Actual touch bounds issues')
 for s in actual['scenes']+actual['comparisons']:
  p=TASK/'exports'/s['filename'];check(p.exists(),'Missing export '+p.name)
  if p.exists():
   im=Image.open(p);im.verify();im=Image.open(p);check(im.size==tuple(s['outputSize']),'Wrong export size '+p.name)
else:issues.append('Actual Penpot audit not yet saved')
report={'status':'PASS' if not issues else 'FIX','baseMenus':len(base),'sceneCount':len(scenes),'controls':len(controls),'imageMappings':len(images),'assets':assets,'issues':issues}
(TASK/'delivery-audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2));print(json.dumps({k:v for k,v in report.items() if k!='assets'},ensure_ascii=False,indent=2))
raise SystemExit(bool(issues))
