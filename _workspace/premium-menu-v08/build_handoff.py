from pathlib import Path
import json,csv,hashlib,gzip
from collections import Counter
ROOT=Path(__file__).resolve().parents[2]
TASK=Path(__file__).resolve().parent
spec=json.loads((TASK/'scene-spec.json').read_text())
old=json.loads((ROOT/'assets/ui/premium-menu-v07/manifest.json').read_text())
assets=[]
for a in old['assets']:
 row={**a,'v08_usage':'reused without modifying original','runtime_registered':False}
 assert hashlib.sha256((ROOT/row['path']).read_bytes()).hexdigest()==row['sha256']
 assets.append(row)
for key in ['ja-hyun','myo-ryung','nabi','yu-ran']:
 p=ROOT/'_workspace/premium-menu-v07/approved-source'/f'{key}-concept-v01.png'
 assets.append({'id':'menu08.character.'+key,'path':str(p.relative_to(ROOT)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'source':'v07 approved character source; preserved','runtime_registered':False})
manifest={'schema_version':1,'version':'premium-menu-v08','date':'2026-10-20','purpose':'Penpot design only, no Godot menu changes','new_raster_assets':0,'reused_assets':assets,'original_records':'assets/ui/premium-menu-v07/manifest.json'}
out=ROOT/'assets/ui/premium-menu-v08';out.mkdir(exist_ok=True)
(out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
def table(name,fields,rows):
 with (TASK/name).open('w') as f:
  w=csv.DictWriter(f,fieldnames=fields);w.writeheader();w.writerows(rows)
index={a['id'].split('.')[-1]:a for a in assets}
rows=[];controls=[];states=Counter()
for s in spec['scenes']:
 elems=s['elements'];last=max((i for i,e in enumerate(elems) if e['name']=='MODAL / scrim'),default=-1)
 for i,e in enumerate(elems):
  if e['kind'] in ['image','svg']:
   a=index[e['key']];rows.append({'scene':s['name'],'slot':e.get('slot',('DESIGN/bg/' if e['kind']=='image' else 'DESIGN/icon/')+e['key']),'key':e['key'],'path':a['path'],'sha256':a['sha256'],'runtime_registered':False})
  if e['kind']=='button':states[e['state']]+=1
  if e['kind'] in ['button','hotspot']:
   enabled=bool(i>last and e.get('dest') and e.get('state')!='disabled')
   controls.append({'scene':s['name'],'control':e['name'],'state':e.get('state','default'),'dest':e.get('dest') or '', 'x1920':e['x'],'y1920':e['y'],'w1920':e['w'],'h1920':e['h'],'centerX1280':round((e['x']+e['w']/2)*2/3,3),'centerY720':round((e['y']+e['h']/2)*2/3,3),'enabled':enabled,'transition_ms':200,'basis':'scene-spec; validate against Penpot actual audit'})
table('image-mapping.csv',['scene','slot','key','path','sha256','runtime_registered'],rows)
table('control-coordinates.csv',list(controls[0]),controls)
table('component-state-table.csv',['namespace','component','meaning','uses'],[{'namespace':'Premium Menu v08','component':'surface-'+k,'meaning':v,'uses':states[k]} for k,v in [('default','기본 표면'),('primary','주요 행동'),('ghost','보조 행동'),('selected','선·체크·선택 문구'),('pressed','누름'),('disabled','사용 불가·클릭 차단'),('owned','보유'),('equipped','장착'),('danger','확인 필요한 변경')]])
print(json.dumps({'reusedAssets':len(assets),'imageUses':len(rows),'controls':len(controls),'enabled':sum(r['enabled'] for r in controls)},ensure_ascii=False))
