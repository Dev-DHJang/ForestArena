"""Independent read-only checks against delivered records; writes QA evidence only."""
from pathlib import Path
import hashlib,json
from datetime import datetime,timezone
from PIL import Image,ImageChops,ImageStat
TASK=Path(__file__).resolve().parent
ROOT=TASK.parents[1]
issues=[];notes=[]
def require(ok,message):
 if not ok:issues.append(message)
spec=json.loads((TASK/'scene-spec.json').read_text())
records=json.loads((TASK/'export-records.json').read_text())
base=set(spec['base']);names={s['name'] for s in spec['scenes']}
require(len(base)==13 and len(names)==81,'Expected 13 base menus and 81 unique scenes')
require({r['name'] for r in records['scenes']}==names,'Scene exports do not match complete spec')
require(len(records['scenes'])==81,'Expected 81 scene PNG records')
require(len(records['comparisons'])==4,'Expected 4 wide comparisons')
require(len(records.get('designExports',[]))==13,'Expected 13 design resolution exports')
require({r['name'] for r in records.get('designExports',[])}==base,'Design exports do not match base menus')
all_records=records['scenes']+records['comparisons']+records.get('designExports',[])
require(len({r['filename'] for r in all_records})==len(all_records),'Export filenames are not unique')
for r in all_records:
 p=TASK/'exports'/r['filename'];require(p.exists(),'Missing '+r['filename'])
 if not p.exists():continue
 im=Image.open(p);im.verify();im=Image.open(p)
 require(list(im.size)==r['outputSize'],'Record dimensions differ '+r['filename'])
 require(p.stat().st_size==r['bytes'],'Record byte count differs '+r['filename'])
hashes=json.loads((TASK/'export-hashes.json').read_text())
require({h['filename'] for h in hashes}=={r['filename'] for r in all_records},'Published export hashes differ from delivered file set')
for h in hashes:
 require(hashlib.sha256((TASK/'exports'/h['filename']).read_bytes()).hexdigest()==h['sha256'],'Published export hash differs '+h['filename'])
for s in spec['scenes']:
 for e in s['elements']:
  if e['kind'] not in ['button','hotspot']:continue
  require(e['w']>=72 and e['h']>=72,'Small target '+s['name']+'/'+e['name'])
  require(e['x']>=96 and e['y']>=48 and e['x']+e['w']<=1824.01 and e['y']+e['h']<=1032.01,'Unsafe target '+s['name']+'/'+e['name'])
for index_file in ['image-index.json','design-index.json']:
 entries=json.loads((TASK/'qa-review'/index_file).read_text())
 for e in entries:
  p=TASK/'exports'/e['filename'];digest=hashlib.sha256(p.read_bytes()).hexdigest()
  require(e.get('visually_reviewed') and e.get('review_result')=='PASS' and e['sha256']==digest,'Final pixels need successful visual review '+e['name'])
contacts=json.loads((TASK/'qa-review/contact-review.json').read_text())
require(contacts['covered_outputs']==85 and len(contacts['sheets'])==15,'Incomplete final contact review')
for sheet in contacts['sheets']:
 require(sheet['visually_reviewed'] and sheet['status']=='PASS' and hashlib.sha256((TASK/'qa-review'/sheet['filename']).read_bytes()).hexdigest()==sheet['sha256'],'Contact sheet evidence changed '+sheet['filename'])
wide=[];by_name={r['name']:r for r in records['scenes']}
for r in records['comparisons']:
 name=r['name'].replace('CMP20 / MENU07 / ','');source=by_name.get(name)
 require(source is not None,'Unknown wide source '+r['name'])
 if source is None:continue
 large=Image.open(TASK/'exports'/r['filename']).convert('RGB');small=Image.open(TASK/'exports'/source['filename']).convert('RGB')
 require(large.size==(1600,720),'Wide comparison must be 1600x720')
 center=large.crop(((large.width-small.width)//2,0,(large.width+small.width)//2,small.height))
 diff=ImageChops.difference(center,small);gray=diff.convert('L');hist=gray.histogram()
 wide.append({'name':r['name'],'source':name,'exact_center_match':diff.getbbox() is None,'different_pixels':sum(hist[1:]),'total_pixels':small.width*small.height,'mean_channel_difference':ImageStat.Stat(diff).mean})
actual_path=TASK/'final-audit.json'
if not actual_path.exists():issues.append('Final native Penpot audit is unavailable')
else:
 actual=json.loads(actual_path.read_text())
 for key in ['outsideChanges','missingOriginalComponents','changedLegacyLinks','missingDestinations','textIssues','touchIssues','shapeIssues','comparisonIssues','baseIdIssues','officialScreenIssues','legacyChildIssues','sourceControlIssues','componentIssues']:
  require(key in actual,'Missing final audit field '+key);require(not actual.get(key),'Final audit issue '+key)
 require(actual.get('originalComponents')==536,'Original component count differs')
 require(actual.get('currentComponents')==561,'Expected 536 original plus 25 new components')
 require(actual.get('originalLinks')==287,'Original prototype link count differs')
 require(actual.get('prototypeCount')==81,'Expected 81 wired prototype scenes')
 baseline=json.loads((TASK/'baseline-audit.json').read_text());baseline_ids={s['name']:s['id'] for s in baseline['sources'] if s.get('target')}
 require({r['name']:r['id'] for r in actual.get('base',[])}==baseline_ids,'Base native screen IDs changed')
 require(actual.get('originalLinksPreserved')==baseline['links'],'Original 287 link identities/content differ from baseline')
 official={r['name']:(r['id'],r['w'],r['h']) for r in baseline['sources'] if r['name'].startswith('SCR_')}
 require({r['name']:(r['id'],r['width'],r['height']) for r in actual.get('officialIds',[])}==official,'Official 24 screens differ from baseline')
 controls=actual.get('actualControls',[])
 require(len(controls)==846,'Expected all 846 actual controls')
 active=[c for c in controls if c['active']]
 require(len(active)==681 and len(actual.get('newLinks',[]))==681,'Expected 681 active new links')
 require(actual.get('currentLinks')==len(baseline['links'])+len(active),'Final link total differs')
 require(actual.get('sourceCount')==81 and set(actual.get('prototypeIds',{}))==names,'Native source/prototype scene names differ')
 native_links={l['id']:l for l in actual.get('newLinks',[])}
 for scene in spec['scenes']:
  expected=[e for e in scene['elements'] if e['kind'] in ['button','hotspot']]
  observed=[c for c in controls if c['scene']==scene['name']]
  require(len(expected)==len(observed),'Control count differs '+scene['name'])
  for e,c in zip(expected,observed):
   label=scene['name']+'/'+e['name']
   require(c['name']==e['name'] and all(abs(c[k]-e[k])<0.01 for k in ['x','y','w','h']),'Actual control identity/geometry differs '+label)
   require(c['destinationName']==e.get('dest'),'Actual control destination differs '+label)
   require(bool(c.get('sourceId')),'Missing native source control ID '+label)
   if c['active']:
    require(e.get('state')!='disabled','Disabled control has an active link '+label)
    link=native_links.get(c['id'],{})
    require(link.get('trigger')=='click' and link.get('type')=='navigate-to' and link.get('destination')==c['destinationId'] and link.get('destinationName')=='PROTO / '+c['destinationName'],'Native click wiring differs '+label)
    require(c['animation']=={'type':'dissolve','duration':200,'easing':'ease-out'} and link.get('animation')==c['animation'],'Transition differs '+label)
    if e.get('dest') in actual['prototypeIds']:
     require(c['destinationId']==actual['prototypeIds'][e['dest']],'Native destination board differs '+label)
   else:
    require(c['id'] is None and c['destinationId'] is None and c['animation'] is None,'Inactive control retains a link '+label)
 notes.append('Baseline 287 links and official 24 screens compared in full; all 846 control coordinates/destinations and 681 active native links compared with spec')
legacy=json.loads((TASK/'legacy-native-preservation.json').read_text())
require(len(legacy)==13 and all(r['expected']==r['actual'] and r['expectedCount']==r['count'] for r in legacy),'Legacy native child snapshots differ')
report={'status':'PASS' if not issues else 'FIX','scope':'Independent delivered files, prior visual review hashes, and native audit consistency; manual viewer evidence reviewed separately','checked_at':datetime.now(timezone.utc).isoformat(),'input_sha256':{name:hashlib.sha256((TASK/name).read_bytes()).hexdigest() for name in ['scene-spec.json','export-records.json','export-hashes.json','baseline-audit.json','final-audit.json','legacy-native-preservation.json']},'scene_count':len(records['scenes']),'base_count':len(base),'wide_count':len(records['comparisons']),'design_count':len(records.get('designExports',[])),'issues':issues,'wide_pixel_comparisons':wide,'notes':notes,'android_device':'not-run'}
(TASK/'qa-review/independent-checks.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
print(json.dumps(report,ensure_ascii=False,indent=2))
raise SystemExit(bool(issues))
