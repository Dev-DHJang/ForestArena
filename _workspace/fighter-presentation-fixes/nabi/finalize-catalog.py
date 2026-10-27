"""Freeze the exact18 Nabi review candidates without touching runtime."""
from pathlib import Path
import hashlib,json,copy
from PIL import Image
ROOT=Path(__file__).resolve().parents[3];BASE=Path(__file__).resolve().parent
h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
m=json.loads((ROOT/'assets/character/manifest.json').read_text());current={(e.get('character_id'),e.get('visual_state_id')):e for e in m['assets'] if e.get('type')=='animation-runtime'}
scale=json.loads((BASE/'scale-only-catalog-r01.json').read_text());rows=scale['assets'];proof=[]
for motion in ['run','jump']:
 p=BASE/'candidates'/f'{motion}_body-fit-r01.json';row=json.loads(p.read_text());old=current['nabi',motion]
 for key in ['jump_frame_ranges','run_stride_px']:
  if key in old:row[key]=copy.deepcopy(old[key])
 source=row['source_paths'][0];row['source_path']=source;row['source_sheet_sha256']=[h(ROOT/source)];row['source_sha256']=h(ROOT/source)
 inputs=[BASE/'run-r01-source.png'] if motion=='run' else [BASE/'jump-r01-source.png',BASE/'jump-repair-r02-source.png']
 row['creation']={'method':'built-in image_gen whole-figure new poses; deterministic connected-figure placement and one uniform whole-motion scale; no body-part warp','provider':'OpenAI built-in image generation','version':'nabi-body-fit-r01','source_inputs':[{'path':str(p.relative_to(ROOT)),'sha256':h(p)} for p in inputs]}
 row['rights']={'status':'derivative of approved Nabi appearance; modified run/jump not yet user-approved for registration; no external license assertion','references':['docs/contracts/character-appearance-v01.json','assets/character/manifest.json','_workspace/fighter-presentation-fixes/00_request.md']}
 row['status']='unapproved-workspace-only';row['layout_revision']={'kind':'new whole-figure motion candidate','source_runtime_png':old['path'],'source_runtime_png_sha256':old['sha256'],'source_runtime_tres':old['sprite_frames_path'],'source_runtime_tres_sha256':h(ROOT/old['sprite_frames_path'].removeprefix('res://')),'figure_pixels_changed':True,'intrinsic_body_proportion_assessment':'redrawn to a lower forward model for Ja-hyun comparison; independent visual/transition QA pending','source_composition_record':str((BASE/'jump-r02-composition.json').relative_to(ROOT)) if motion=='jump' else None}
 if motion=='jump':row['conversion']['source_composition_record']=str((BASE/'jump-r02-composition.json').relative_to(ROOT))
 p.write_text(json.dumps(row,indent=2,ensure_ascii=False)+'\n');rows.append(row)
assert len(rows)==18 and len({e['visual_state_id'] for e in rows})==18
rows.sort(key=lambda e:e['visual_state_id'])
for row in rows:
 png=ROOT/row['path'];tres=ROOT/row['sprite_frames_path'].removeprefix('res://');im=Image.open(png).convert('RGBA');count=row['frame_count'];assert h(png)==row['sha256'];assert im.size==(2048,128*((count+15)//16));assert len(row['frame_durations'])==count
 seen=[];bounds=[]
 for i in range(count):
  cell=im.crop((i%16*128,i//16*128,i%16*128+128,i//16*128+128));a=cell.getchannel('A');visible=a.point(lambda x:255 if x>=32 else 0).getbbox();assert visible;assert visible[0]>=1 and visible[1]>=1 and visible[2]<=127 and visible[3]<=127,(row['visual_state_id'],i,visible)
  seen.append(hashlib.sha256(cell.tobytes()).hexdigest());bounds.append(list(visible))
 assert len(set(seen))==count,(row['visual_state_id'],'duplicate whole frame')
 proof.append({'motion':row['visual_state_id'],'frame_count':count,'png_sha256':h(png),'tres_sha256':h(tres),'no_empty_or_duplicate_frames':True,'all_solid_pixels_inside_cells':True,'frame_bounds':bounds,'scale':row['presentation_scale'],'foot_pivot_y':row['foot_pivot_y'],'new_figure_pixels':row['visual_state_id'] in ['run','jump']})
cat={'schema_version':1,'kind':'candidate-motion-layouts','source_manifest_sha256':h(ROOT/'assets/character/manifest.json'),'assets':rows};cp=BASE/'candidate-catalog-r01.json';cp.write_text(json.dumps(cat,indent=2,ensure_ascii=False)+'\n')
scope={'schema_version':1,'kind':'candidate-motion-review','catalog_sha256':h(cp),'motions':[{'character_id':'nabi','motion':e['visual_state_id']} for e in rows]};sp=BASE/'candidate-scope-r01.json';sp.write_text(json.dumps(scope,indent=2)+'\n');sp.with_suffix('.sha256').write_text(h(sp)+'\n')
protected=json.loads((BASE/'scale-only-proof-r01.json').read_text())['protected_runtime_files'];assert all(h(ROOT/p)==sha for p,sha in protected.items())
(BASE/'candidate-technical-proof-r01.json').write_text(json.dumps({'status':'technical-pass; independent semantic/body/transition visual QA pending','catalog_sha256':h(cp),'scope_sha256':h(sp),'motion_count':18,'newly_drawn_motions':['run','jump'],'scale_only_motions':16,'source_pixels_warped':False,'runtime_manifest_unchanged':True,'protected_runtime_files':protected,'motions':proof,'proportion_target':'visible body bulk and head/body balance close to Ja-hyun; exact hidden anatomy +/-5% not inferred from alpha bbox or posed total height'},indent=2,ensure_ascii=False)+'\n')
print(json.dumps({'catalog':str(cp.relative_to(ROOT)),'sha256':h(cp),'scope_sha256':h(sp),'motions':len(rows),'frames':sum(e['frame_count'] for e in rows),'visual_status':'pending'},ensure_ascii=False))
