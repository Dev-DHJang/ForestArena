"""독립 read-only 대상 대조. 등록 도구의 plan/install을 호출하지 않는다."""
from pathlib import Path
from collections import Counter
import json,hashlib,re
ROOT=Path(__file__).resolve().parents[4]
BASE=ROOT/'_workspace/motion-naturalness-v1'
OUT=Path(__file__).resolve().parent
checks=[]
def load(p):return json.loads(p.read_text())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def check(name,ok,detail=None):
 checks.append({'check':name,'pass':bool(ok),'detail':detail});assert ok,(name,detail)
def key(r):return r['character_id'],r.get('motion',r.get('visual_state_id'))
def local(p):return ROOT/p.removeprefix('res://')
paths={'targets':BASE/'remaining-registration-targets-r10.json','preflight':BASE/'qa/remaining-registration-targets-preflight-r10.json','catalog':BASE/'remaining-candidate-catalog-r10.json','scope':BASE/'remaining-candidate-scope-r10.json','manifest':ROOT/'assets/character/manifest.json','consumer':ROOT/'scripts/local_fighter_presentation.gd','review':BASE/'qa/remaining-candidate-review-r10-current/motion-review.json'}
before={str(p.relative_to(ROOT)):sha(p) for p in paths.values()}
t,p,c,s,m=[load(paths[k]) for k in ['targets','preflight','catalog','scope','manifest']]
check('target schema',t.get('schema_version')==1 and t.get('kind')=='motion-registration-targets')
keys=[key(r) for r in t['motions']];sk=[key(r) for r in s['motions']];ck=[key(r) for r in c['assets'] if not r.get('reuse_approved_runtime',False)]
check('25 unique exact scope and pending catalog',len(keys)==25 and len(set(keys))==25 and set(keys)==set(sk)==set(ck),{'target':len(keys),'scope':len(sk),'catalog_pending':len(ck)})
check('12 Ja and13 Nabi targets',Counter(k[0] for k in keys)=={'ja-hyun':12,'nabi':13})
check('scope pins actual catalog',s['catalog_sha256']==sha(paths['catalog']))
for field,k in [('catalog_sha256','catalog'),('target_sha256','targets'),('manifest_sha256','manifest')]:check('producer pin matches '+k,p[field]==sha(paths[k]))
check('no Ja special_side nor approved scarf sweep',not ({('ja-hyun','special_side'),('ja-hyun','special_scarf_sweep')}&set(keys)))
manifest={key(r):r for r in m['assets'] if r.get('type')=='animation-runtime'}
check('unique runtime keys',len(manifest)==sum(r.get('type')=='animation-runtime' for r in m['assets']))
cat={key(r):r for r in c['assets']}
all_source_paths={local(r[f]).resolve() for r in c['assets'] for f in ['path','sprite_frames_path']}
records=[]
for r in t['motions']:
 k=key(r); old=manifest[k]; png=local(r['png_path']); tres=local(r['sprite_frames_path']);runtime=ROOT/'assets/character'/k[0]/'animation/runtime'; png_resolved=png.resolve();tres_resolved=tres.resolve()
 check(str(k)+' stable ID and consumer',r['asset_id']==old['asset_id'] and r['sprite_frames_path']==old['sprite_frames_path']==old['consumer_path'])
 check(str(k)+' existing consumer file',tres.is_file())
 check(str(k)+' destination inside character runtime',png_resolved.is_relative_to(runtime.resolve()) and tres_resolved.is_relative_to(runtime.resolve()))
 check(str(k)+' new PNG absent',not png.exists() and not png.is_symlink())
 check(str(k)+' new PNG distinct from source/current',png_resolved not in all_source_paths and png_resolved!=local(old['path']).resolve())
 check(str(k)+' version and frame count match',re.fullmatch(r'.+_%df(?:_[a-zA-Z0-9-]+)+\.png'%cat[k]['frame_count'],png.name) is not None)
 check(str(k)+' old texture still matches runtime manifest',local(old['path']).is_file() and sha(local(old['path']))==old['sha256'])
 text=tres.read_text();texpaths=re.findall(r'\[ext_resource type="Texture2D" path="([^"]+)"',text)
 check(str(k)+' TRES current texture path preserved',bool(texpaths) and set(texpaths)=={'res://'+old['path']},texpaths)
 records.append({'character_id':k[0],'motion':k[1],'logical_id':r['asset_id'],'consumer_path':r['sprite_frames_path'],'consumer_sha256':sha(tres),'existing_png_path':old['path'],'existing_png_sha256':sha(local(old['path'])),'new_png_path':r['png_path'],'new_png_exists':png.exists(),'candidate_frame_count':cat[k]['frame_count']})
check('new PNG destinations unique',len({r['png_path'] for r in t['motions']})==25)
check('consumer destinations unique',len({r['sprite_frames_path'] for r in t['motions']})==25)
check('logical IDs unique',len({r['asset_id'] for r in t['motions']})==25)
approval=local(t['approval_record']);check('approval path stays workspace JSON',approval.resolve().is_relative_to((ROOT/'_workspace').resolve()) and approval.suffix=='.json')
check('approval record absent',not approval.exists() and not approval.is_symlink())
check('preflight fields agree',p['motions']==25 and p['existing_logical_ids_and_sprite_consumers_preserved'] and p['new_png_paths_do_not_exist'] and p['approved_ja_special_excluded'] and not p['approval_record_exists'])
consumer=paths['consumer'].read_text();check('production maps visual_state to SpriteFrames via manifest',all(x in consumer for x in ['entry.get("sprite_frames_path", "")','entry.get("visual_state_id", path.get_file().get_basename())','result[motion] = path']))
approved=[]
for motion in ['special_side','special_scarf_sweep']:
 r=manifest['ja-hyun',motion];approved.append({'character_id':'ja-hyun','motion':motion,'asset_id':r['asset_id'],'png_path':r['path'],'png_sha256':sha(local(r['path'])),'consumer_path':r['sprite_frames_path'],'consumer_sha256':sha(local(r['sprite_frames_path']))})
review=load(paths['review']);verdicts=Counter(r['status'] for r in review['motions'])
after={str(p.relative_to(ROOT)):sha(p) for p in paths.values()};check('read inputs unchanged',before==after)
result={'status':'pass for target preparation only','reviewer':'afterimage_final_r09 / independent qa','check_count':len(checks),'checks':checks,'motions':records,'excluded_existing_ja_special':approved,'input_sha256':before,'approval_record':t['approval_record'],'approval_record_exists':approval.exists(),'current_review_status_counts':dict(verdicts),'registration_plan_called':False,'install_called':False,'registration_ready':False,'limits':'Target preparation only. Current full25 review is not all pass and no approval record exists. No plan/install or visual/network/device approval is asserted.'}
(OUT/'result.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print('REGISTRATION_TARGETS_INDEPENDENT: PASS',len(checks),'checks /25targets')
print('Full review snapshot:',dict(verdicts),'approval_record_exists:',approval.exists())
print('No plan_registration/install invoked; original inputs unchanged')
