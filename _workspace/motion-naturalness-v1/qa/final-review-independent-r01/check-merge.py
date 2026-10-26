"""독립 대조 only; no registration module import or plan/install call."""
from pathlib import Path
import json,hashlib
from collections import Counter
ROOT=Path(__file__).resolve().parents[4];B=ROOT/'_workspace/motion-naturalness-v1/qa';OUT=Path(__file__).resolve().parent
checks=[]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def load(p):return json.loads(p.read_text())
def ck(n,ok,d=None):checks.append({'check':n,'pass':bool(ok),'detail':d});assert ok,(n,d)
def key(r):return r['character_id'],r['motion']
a_path=B/'remaining-candidate-review-r10-current/motion-review.json'; f_path=B/'remaining-candidate-review-r10-final/motion-review.json'; own=ROOT/'_workspace/nabi-claw-vfx-v2/qa/independent-visual-r02';b_path=own/'formal-review/motion-review.json';v_path=own/'four-motion-verdicts.json';proof_path=B/'final-review-merge-r01/merge-proof-r01.json'
a,f,b,v,p=[load(x) for x in [a_path,f_path,b_path,v_path,proof_path]]
ck('original21pass4blocked',Counter(r['status'] for r in a['motions'])=={'pass':21,'blocked':4})
ck('Nabi independent4pass',len(b['motions'])==4 and all(r['status']=='pass' for r in b['motions']))
ck('final25pass',len(f['motions'])==25 and all(r['status']=='pass' for r in f['motions']))
a_rows={key(r):r for r in a['motions']};f_rows={key(r):r for r in f['motions']};b_rows={key(r):r for r in b['motions']};v_rows={key(r):r for r in v['motions']}
ck('exact25 unique keys',len(a_rows)==len(f_rows)==25 and a_rows.keys()==f_rows.keys())
ck('only exact4 Nabi source keys',set(b_rows)==set(v_rows)=={('nabi',x) for x in ['attack_air_heavy','attack_air_light','attack_heavy_up','special_side']})
fields=['status','checks','observations','issues']; changed=[]
for k,ar in a_rows.items():
 fr=f_rows[k]
 if k in b_rows:
  ck(str(k)+' exact independently approved QA fields',all(fr[x]==b_rows[k][x]==v_rows[k][x] for x in fields))
  ck(str(k)+' nondecision fields unchanged',{x:y for x,y in ar.items() if x not in fields}=={x:y for x,y in fr.items() if x not in fields})
  ck(str(k)+' all six checked',len(fr['checks'])==6 and all(value is True for value in fr['checks'].values()))
  changed.append('/'.join(k))
 else:ck(str(k)+' original21 row byte-value unchanged',ar==fr)
 for pf,hf in [('path','sha256'),('sprite_frames_path','sprite_frames_sha256')]:ck(str(k)+' current asset '+pf,sha(ROOT/fr[pf])==fr[hf])
 ck(str(k)+' source action hash unchanged',sha(ROOT/fr['action_source'])==fr['action_source_sha256'])
 for rel,digest in fr['materials'].items():ck(str(k)+' exact comparison material '+rel,sha(f_path.parent/rel)==digest and (a_path.parent/rel).read_bytes()==(f_path.parent/rel).read_bytes())
ck('top-level fields unchanged except reviewer and provenance',{k:v for k,v in a.items() if k not in ['reviewer','motions']}=={k:v for k,v in f.items() if k not in ['reviewer','motions','independent_review_merge']})
merge=f['independent_review_merge']
for field,path in [('first_review',a_path),('second_review',b_path),('second_verdicts',v_path)]:ck('merge reference '+field,merge[field]==str(path.relative_to(ROOT)) and merge[field+'_sha256']==sha(path))
ck('copied_motion_decisions exact',set(merge['copied_motion_decisions'])==set(changed))
ck('approval remains pending',a['approval_status']==f['approval_status']=='pending' and f['candidate_selection']['approval_status']=='pending')
ck('proof final hash',p['review_sha256']==sha(f_path));ck('proof merge equals actual',p['merge']==merge)
ck('final review source hash current',all((ROOT/s).is_file() and sha(ROOT/s)==h for s,h in f['sources'].items()),len(f['sources']))
ck('PNG/TRES/index/timeline and all other copied files equal',all((a_path.parent/rel).read_bytes()==(f_path.parent/rel).read_bytes() for rel in [str(x.relative_to(a_path.parent)) for x in a_path.parent.rglob('*') if x.is_file() and x.name!='motion-review.json']))
t=load(ROOT/'_workspace/motion-naturalness-v1/remaining-registration-targets-r10.json');ck('approval record still absent',not (ROOT/t['approval_record']).exists())
prior=load(B/'registration-targets-independent-r01/result.json')
# The full review was intentionally changed by its independent owner: all other preregistration inputs must stay unchanged.
ck('target prereflight inputs still same bytes',all(sha(ROOT/x)==h for x,h in prior['input_sha256'].items() if x!=str(a_path.relative_to(ROOT))))
ck('target destinations still absent',all(not (ROOT/r['png_path']).exists() for r in t['motions']))
result={'status':'pass for exact25 QA merge integrity','checks_count':len(checks),'checks':checks,'reviewer':'afterimage_final_r09 / independent qa','references_sha256':{str(x.relative_to(ROOT)):sha(x) for x in [a_path,f_path,b_path,v_path,proof_path]},'changed_decision_rows':changed,'passed_original_rows':21,'passed_copied_rows':4,'approval_status':'pending','registration_plan_invoked_by_this_check':False,'install_invoked':False,'art_reinspection_needed':False,'basis':'Exact image/TRES/time/action/material bytes preserved; existing independent reviews are the visual judgment sources, not a new aggregate visual judgment.'}
(OUT/'result.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print('FINAL_REVIEW_MERGE_INDEPENDENT: PASS',len(checks),'checks, exact21+4=25pass; approval pending, no install')
