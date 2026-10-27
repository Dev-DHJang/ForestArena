"""Prepare display-only scale candidates; never writes approved runtime assets."""
from pathlib import Path
import hashlib,json,copy,re
ROOT=Path(__file__).resolve().parents[3];BASE=Path(__file__).resolve().parent
manifest_path=ROOT/'assets/character/manifest.json';document=json.loads(manifest_path.read_text())
digest=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
move_set=(ROOT/'assets/combat/movesets/two_fighter_nabi_moveset.tres').read_text()
active=set(re.findall(r'visual_state_id = &"([^\"]+)"',move_set))|{'idle','run','jump','guard','hitstun','launch','knock_down','wake_up','death','ring_out','spawn'}
entries=[e for e in document['assets'] if e.get('type')=='animation-runtime' and e.get('character_id')=='nabi' and e.get('visual_state_id') in active]
assert len(entries)==18
candidates=[];proof=[];protected={str(p.relative_to(ROOT)):digest(p) for e in entries for p in [ROOT/e['path'],ROOT/e['sprite_frames_path'].removeprefix('res://')]};protected[str(manifest_path.relative_to(ROOT))]=digest(manifest_path)
for e in entries:
 name=e['visual_state_id']
 if name in ['run','jump']:continue
 row=copy.deepcopy(e)
 row['type']='animation-candidate'
 for k in ['motion_registration','registration_history','asset_id','consumer_path']:row.pop(k,None)
 src=ROOT/e['path'];tres=ROOT/e['sprite_frames_path'].removeprefix('res://')
 dst=BASE/'candidates'/f'{name}_{e["frame_count"]}f_body-fit-r01.png';dst.parent.mkdir(parents=True,exist_ok=True);dst.write_bytes(src.read_bytes())
 tdst=BASE/'candidates'/f'{name}_body-fit-r01.tres';text=tres.read_text();old='res://'+e['path'];new='res://'+str(dst.relative_to(ROOT));assert text.count(old)==1;tdst.write_text(text.replace(old,new))
 row['path']=str(dst.relative_to(ROOT));row['sprite_frames_path']='res://'+str(tdst.relative_to(ROOT));row['presentation_scale']=e.get('presentation_scale',1.0)*0.92
 row['status']='unapproved-workspace-only'
 row['layout_revision']={'kind':'whole-figure display-size candidate','source_runtime_png':e['path'],'source_runtime_png_sha256':e['sha256'],'source_runtime_tres':e['sprite_frames_path'],'source_runtime_tres_sha256':digest(tres),'uniform_display_factor':0.92,'prior_display_scale':e.get('presentation_scale',1.0),'figure_pixels_changed':False,'intrinsic_body_ratios_changed':False,'assessment':'candidate; independent body-proportion and transition review pending'}
 if name=='hitstun':
  row['hit_reaction_lead_frame_range']=[0,6];row['hit_reaction_lead_ticks']=6
 candidates.append(row)
 proof.append({'motion':name,'png_exact_original':digest(dst)==e['sha256'],'tres_only_png_reference_changed':tdst.read_text().replace(new,old)==text,'old_scale':e.get('presentation_scale',1.0),'candidate_scale':row['presentation_scale'],'factor':0.92,'frame_count':e['frame_count'],'anchors_unchanged':row.get('frame_anchors')==e.get('frame_anchors'),'phase_weights_unchanged':row.get('phase_frame_ranges')==e.get('phase_frame_ranges') and row.get('frame_durations')==e.get('frame_durations')})
assert all(digest(ROOT/p)==v for p,v in protected.items())
(BASE/'scale-only-catalog-r01.json').write_text(json.dumps({'schema_version':1,'kind':'candidate-motion-layouts','source_manifest_sha256':digest(manifest_path),'assets':candidates},indent=2,ensure_ascii=False)+'\n')
(BASE/'scale-only-proof-r01.json').write_text(json.dumps({'status':'technical-pass; visual/proportion/transition QA pending','motions':proof,'protected_runtime_files':protected,'active_motion_count':18,'scale_only_motion_count':16,'new_art_pending':['run','jump'],'runtime_manifest_unchanged':True,'body_ratio_claim':'uniform display scaling preserves the existing intrinsic ratio; it does not prove the +/-5% visual target'},indent=2,ensure_ascii=False)+'\n')
print('16 scale-only candidates prepared; 18 approved runtime PNG/TRES and manifest untouched')
