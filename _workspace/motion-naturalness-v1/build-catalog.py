"""Build the explicit ten-motion pilot selection; no runtime publication."""
from pathlib import Path
import hashlib,json
base=Path(__file__).resolve().parent;root=base.parents[1]
old=json.loads((root/'_workspace/two-fighter-combat-v2/candidate-catalog.json').read_text())
by_key={(r['character_id'],r['visual_state_id']):r for r in old['assets']}
selected={'ja-hyun':{'run':'r06','jump':'r03','attack_light_combo_01':'r02','attack_light_combo_02':'r02','attack_light_combo_04':'r02'},'nabi':{'run':'r05','jump':'r03','attack_light_combo_01':'r02','attack_light_up':'r03','attack_light_combo_02':'r03'}}
rows=[]
for cid,motions in selected.items():
 for motion,version in motions.items():
  row=json.loads((base/'candidates'/cid/f'{motion}_{version}.json').read_text())
  original=by_key[cid,motion]
  row['asset_id']=original.get('asset_id',f'{cid}-{motion.replace("_","-")}-16f-v01')
  row['expected_action']=original['expected_action'];row['action_source']='_workspace/motion-naturalness-v1/02_expectations.md'
  row['creation']={'method':'built-in image_gen original poses followed by source figure separation and uniform layout conversion','provider':'OpenAI built-in image generation','version':'motion-naturalness-pilot-v01','source_path':row['source_path'],'source_sha256':row['source_sha256']}
  row['rights']={'status':f'derived from the previously approved {cid} appearance; current motion pending explicit user approval; external license verification not asserted','references':['assets/character/manifest.json','_workspace/motion-naturalness-v1/00_request.md']}
  sidecar=(root/row['source_path']).with_suffix('.json')
  if sidecar.exists():row['conversion']['source_layout_record']={'path':str(sidecar.relative_to(root)),'sha256':hashlib.sha256(sidecar.read_bytes()).hexdigest()}
  rows.append(row)
doc={key:old[key] for key in ['schema_version','kind','approval_status','attack_sources','character_movesets']};doc['assets']=rows
catalog=base/'candidate-catalog.json';catalog.write_text(json.dumps(doc,ensure_ascii=False,indent=2)+'\n')
scope=base/'candidate-scope.json';scope.write_text(json.dumps({'schema_version':1,'kind':'candidate-motion-review','catalog_sha256':hashlib.sha256(catalog.read_bytes()).hexdigest(),'motions':[{'character_id':r['character_id'],'motion':r['visual_state_id']} for r in rows]},ensure_ascii=False,indent=2)+'\n')
(base/'candidate-scope.sha256').write_text(hashlib.sha256(scope.read_bytes()).hexdigest()+'\n');print('pilot10 catalog and hash-bound scope written; all pending')
