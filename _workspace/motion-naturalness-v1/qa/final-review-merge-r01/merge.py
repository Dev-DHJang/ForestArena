"""Copy exact scoped QA decisions; never infer a new pass from an aggregate."""
from pathlib import Path
import hashlib,json,shutil
ROOT=Path(__file__).resolve().parents[4];BASE=Path(__file__).resolve().parent
FIRST=ROOT/'_workspace/motion-naturalness-v1/qa/remaining-candidate-review-r10-current'
SECOND=ROOT/'_workspace/nabi-claw-vfx-v2/qa/independent-visual-r02/four-motion-verdicts.json'
SECOND_FORMAL=SECOND.parent/'formal-review/motion-review.json'
DEST=FIRST.with_name('remaining-candidate-review-r10-final')
assert not DEST.exists()
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
a=json.loads((FIRST/'motion-review.json').read_text());b=json.loads(SECOND.read_text());formal=json.loads(SECOND_FORMAL.read_text())
assert len(a['motions'])==25 and sum(r['status']=='pass' for r in a['motions'])==21 and sum(r['status']=='blocked' for r in a['motions'])==4
assert len(b['motions'])==4 and b['catalog_sha256']==a['candidate_selection']['catalog_sha256']
bykey={(r['character_id'],r['motion']):r for r in b['motions']};originals={(r['character_id'],r['motion']):r for r in formal['motions']}
assert len(bykey)==4 and set(bykey)==set(originals)
merged=[]
for row in a['motions']:
 key=row['character_id'],row['motion']
 if key not in bykey:assert row['status']=='pass';continue
 source=bykey[key];independent=originals[key]
 assert row['status']=='blocked' and key[0]=='nabi'
 for field in ['path','sha256','sprite_frames_path','sprite_frames_sha256']:
  assert row[field]==source[field]==independent[field],(key,field)
 for field in ['status','checks','observations','issues']:
  assert source[field]==independent[field],(key,field)
 assert source['status']=='pass' and all(source['checks'].values()) and not source['issues']
 for field in ['status','checks','observations','issues']:row[field]=source[field]
 merged.append('/'.join(key))
assert len(merged)==4 and all(r['status']=='pass' and all(r['checks'].values()) for r in a['motions'])
assert a['sources']['scripts/launch_release_clock.gd']==digest(ROOT/'scripts/launch_release_clock.gd')
a['reviewer']='remaining_21_visual (21 motions) + afterimage_final_r09 (4 motions); exact scoped decisions merged by orchestrator'
a['independent_review_merge']={'first_review':str((FIRST/'motion-review.json').relative_to(ROOT)),'first_review_sha256':digest(FIRST/'motion-review.json'),'second_review':str(SECOND_FORMAL.relative_to(ROOT)),'second_review_sha256':digest(SECOND_FORMAL),'second_verdicts':str(SECOND.relative_to(ROOT)),'second_verdicts_sha256':digest(SECOND),'copied_motion_decisions':merged,'scope':'only four existing independent decisions copied; no new visual verdict, artwork, code or registration'}
shutil.copytree(FIRST,DEST)
(DEST/'motion-review.json').write_text(json.dumps(a,ensure_ascii=False,indent=2)+'\n')
proof={'status':'pass','total':25,'original_pass':21,'exact_copied_pass':4,'all_pass':True,'sources_unchanged':all(digest(ROOT/p)==sha for p,sha in a['sources'].items()),'review_sha256':digest(DEST/'motion-review.json'),'merge':a['independent_review_merge'],'runtime_manifest_sha256':digest(ROOT/'assets/character/manifest.json'),'approval_status':a['approval_status']}
assert proof['sources_unchanged'] and proof['approval_status']=='pending'
(BASE/'merge-proof-r01.json').write_text(json.dumps(proof,ensure_ascii=False,indent=2)+'\n');print({k:v for k,v in proof.items() if k!='merge'})
