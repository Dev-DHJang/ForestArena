"""승인 런타임을 건드리지 않는 후보 패키징: 공통 배율/격자 추출만 수행."""
from pathlib import Path
import json, hashlib, shutil
from PIL import Image
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'_workspace/combat-motion-naturalness/candidates'
MAN=json.loads((ROOT/'assets/character/manifest.json').read_text())['assets']
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def source(cid,motion):return next(a for a in MAN if a.get('character_id')==cid and a.get('visual_state_id')==motion and a.get('type')=='animation-runtime')
def write_candidate(cid,motion,scale,generated=None):
 old=source(cid,motion);row=json.loads(json.dumps(old));png=OUT/f'{cid}-{motion}-r01.png';tres=png.with_suffix('.tres')
 if generated is None:
  shutil.copyfile(ROOT/old['path'],png)
  row['layout_only_from_asset_id']=old['asset_id']
 else:
  shutil.copyfile(generated,OUT/'nabi-knockdown-r01-source.png')
  im=Image.open(generated).convert('RGBA');cell=im.width/4
  sheet=Image.new('RGBA',(2048,128))
  for i in range(16):
   x=i%4*cell;y=i//4*cell
   # All cells share one scale; no per-pose bounding-box resizing.
   frame=im.transform((128,128),Image.Transform.EXTENT,(x,y,x+cell,y+cell),Image.Resampling.BICUBIC)
   sheet.paste(frame,(i*128,0))
  sheet.save(png)
  row['frame_anchors']=[{'body_root':[64.0,125.0]} for i in range(16)]
  row['foot_pivot_y']=125.0
  row['landing_down_frame_range']=[12,16]
  row['creation']={'method':'built-in imagegen candidate; fixed 4x4 grid extraction at common scale','provider':'OpenAI image_gen','version':'r01','source_path':str((OUT/'nabi-knockdown-r01-source.png').relative_to(ROOT))}
  row['rights']={'status':'generated from project approved character references','references':['assets/character/nabi/reference/v01/reference.json']}
 old_tres=ROOT/old['sprite_frames_path'].removeprefix('res://')
 text=old_tres.read_text().replace('res://'+old['path'],'res://'+str(png.relative_to(ROOT)))
 tres.write_text(text)
 row.update({'type':'animation-candidate','asset_id':f'{cid}-{motion}-naturalness-r01','path':str(png.relative_to(ROOT)),'sprite_frames_path':'res://'+str(tres.relative_to(ROOT)),'presentation_scale':scale,'sha256':digest(png),'action_source':'docs/gameplay/two-fighter-combat-v2.md','expected_action':'왼손·오른손·왼손 뒤 마지막 킥. 머리·몸 크기는 중간타·대기와 일치한다.' if cid=='ja-hyun' else '피격 뒤 무릎을 굽혀 중심을 낮추고 왼쪽으로 넘어져 옆으로 눕는다. 중간에 다시 서거나 떠서 앉지 않는다. 이후 기존 기상 첫 자세로 이어진다.'})
 for k in ['approval','user_approval','qa','verified_on']:row.pop(k,None)
 return row
# Uniform 12% correction for the undersized kick; all authored cells unchanged.
rows=[write_candidate('ja-hyun','attack_light_combo_04',source('ja-hyun','attack_light_combo_04')['presentation_scale']*1.12),write_candidate('nabi','knock_down',0.80,Path('/Users/jdh/.codex/generated_images/01a1e973-bb23-73a2-8659-afc5c0a5bc64/exec-20f9cb9c-7f2b-44fa-a0f9-f631aaadbf11.png'))]
moves={'ja-hyun':'assets/combat/movesets/two_fighter_ja_hyun_moveset.tres','nabi':'assets/combat/movesets/two_fighter_nabi_moveset.tres'}
catalog=OUT/'catalog-r01.json';catalog.write_text(json.dumps({'schema_version':1,'kind':'motion-candidates','approval_status':'pending','assets':rows,'attack_sources':list(moves.values()),'character_movesets':moves},ensure_ascii=False,indent=2)+'\n')
(OUT/'scope-r01.json').write_text(json.dumps({'schema_version':1,'kind':'candidate-motion-review','catalog_sha256':digest(catalog),'motions':[{'character_id':r['character_id'],'motion':r['visual_state_id']} for r in rows]},ensure_ascii=False,indent=2)+'\n')
(OUT/'packaging-r01.json').write_text(json.dumps({'source_image':str((OUT/'nabi-knockdown-r01-source.png').relative_to(ROOT)),'source_sha256':digest(OUT/'nabi-knockdown-r01-source.png'),'source_size':[1254,1254],'source_grid':[4,4],'source_cell':313.5,'common_scale':128/313.5,'target_cell':[128,128],'target_grid':[16,1],'nabi_display_scale':0.80,'ja_hyun_uniform_factor':1.12,'unapproved_runtime_registered':False},indent=2)+'\n')
print(catalog.relative_to(ROOT))
