"""Inspect the parent's completed read-only plan without invoking registrar functions."""
from pathlib import Path
from collections import Counter
import json,hashlib
ROOT=Path(__file__).resolve().parents[4];B=ROOT/'_workspace/motion-naturalness-v1';OUT=Path(__file__).resolve().parent
checks=[]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def digest(b):return hashlib.sha256(b).hexdigest()
def load(p):return json.loads(p.read_text())
def ck(n,ok,d=None):checks.append({'check':n,'pass':bool(ok),'detail':d});assert ok,(n,d)
def key(r):return r['character_id'],r.get('motion',r.get('visual_state_id'))
planpath=B/'remaining-registration-plan-r10.json';wrapper=load(planpath);p=wrapper['plan'];t=load(B/'remaining-registration-targets-r10.json');c=load(B/'remaining-candidate-catalog-r10.json');fpath=B/'qa/remaining-candidate-review-r10-final/motion-review.json'
ck('read only wrapper',wrapper['writes'] is False)
ck('approval missing explicitly',wrapper['approval_status']=='explicit per-motion human approval record is missing' and not (ROOT/p['approval_record']).exists())
ck('canonical plan SHA256',digest(json.dumps(p,ensure_ascii=False,sort_keys=True,separators=(',',':')).encode())==wrapper['plan_sha256']=='e66bfcf150d8b8c9aa1c174709aa5f4322ba6caffde351321566079d8c6baa88')
ck('plan schema',p['schema_version']==1 and p['kind']=='motion-registration-plan')
for k in ['catalog','scope','qa_review','registration_targets']:ck('plan pins current '+k,sha(ROOT/p[k+'_path'])==p[k+'_sha256'])
ck('pins exact final25 review',p['qa_review_path']==str(fpath.relative_to(ROOT)) and all(r['status']=='pass' for r in load(fpath)['motions']))
ck('pins current registrar and layout',p['registrar_sha256']==sha(ROOT/'tools/forest_arena/register_motion_candidates.py') and p['layout_validator_sha256']==sha(ROOT/'tools/forest_arena/motion_layout.py'))
ck('approval path same target',p['approval_record']==t['approval_record'])
by={key(r):r for r in p['motions']};targets={key(r):r for r in t['motions']};candidate={key(r):r for r in c['assets']}
ck('exact unique25 plan targets',len(p['motions'])==len(by)==25 and by.keys()==targets.keys())
ck('25 replacements only',Counter(r['operation'] for r in p['motions'])=={'replace':25})
expected={'assets/character/manifest.json'};outby={r['path']:r for r in p['outputs']}
ck('51 unique future output paths',len(p['outputs'])==len(outby)==51)
for k,r in by.items():
 tr=targets[k];source=candidate[k];sprite=ROOT/source['sprite_frames_path'].removeprefix('res://');png=ROOT/source['path']
 ck(str(k)+' target identity exact',all(r[x]==tr[x] for x in ['asset_id','png_path','sprite_frames_path']))
 ck(str(k)+' unchanged candidate PNG SHA',r['png_sha256']==sha(png)==source['sha256'])
 ck(str(k)+' unchanged candidate TRES SHA',r['candidate_sprite_frames_sha256']==sha(sprite))
 oldref='path="res://'+source['path']+'"';text=sprite.read_text();ck(str(k)+' exactly one candidate texture reference',text.count(oldref)==1)
 future=text.replace(oldref,'path="res://'+r['png_path']+'"').encode();ck(str(k)+' prospective TRES only retargets PNG',digest(future)==r['registered_sprite_frames_sha256'] and b'res://_workspace/' not in future)
 expected.update([r['png_path'],r['sprite_frames_path'].removeprefix('res://')])
 ck(str(k)+' output afterSHA matches motion plan',outby[r['png_path']]['after_sha256']==r['png_sha256'] and outby[r['sprite_frames_path'].removeprefix('res://')]['after_sha256']==r['registered_sprite_frames_sha256'])
ck('no extra future output files',set(outby)==expected)
for rel,r in outby.items():
 path=ROOT/rel
 ck('output remains at beforeSHA '+rel,not path.exists() if r['before_sha256'] is None else path.is_file() and sha(path)==r['before_sha256'])
ck('existing production manifest unchanged',sha(ROOT/'assets/character/manifest.json')=='2503ccf0b0b32c3626c047818559d213b1184d1e8017076e4c9968cc0800674c')
result={'status':'pass for read-only plan consistency','reviewer':'afterimage_final_r09 / independent qa','plan_path':str(planpath.relative_to(ROOT)),'plan_file_sha256':sha(planpath),'plan_sha256':wrapper['plan_sha256'],'checks_count':len(checks),'checks':checks,'writes':False,'outputs':{'new_png':25,'existing_tres_future_replacements':25,'future_manifest':1,'all_current_files_still_at_before_sha256':True},'approval_record_exists':False,'approval_status':wrapper['approval_status'],'registrar_invoked_by_this_checker':False,'install_called':False,'ready_to_install':False}
(OUT/'plan-result.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print('READ_ONLY_PLAN_INDEPENDENT: PASS',len(checks),'checks;25motions/51futureoutputs; actualwrites0;approval missing')
