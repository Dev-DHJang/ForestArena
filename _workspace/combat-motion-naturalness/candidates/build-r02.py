"""공통 픽셀 배율을 유지하며 기상 후보와 현재 제작 이력을 정리한다."""
from pathlib import Path
import json,hashlib,shutil
from PIL import Image
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
old=json.loads((OUT/'catalog-r01.json').read_text());rows=old['assets']
refs=json.loads((ROOT/'assets/character/nabi/reference/v01/reference.json').read_text())
references=[{'path':refs['images'][k]['path'],'sha256':refs['images'][k]['sha256']} for k in ['combat','front','side']]
for row in rows:
 for key in ['motion_registration','registration_history','status','consumer_path','layout_revision']:row.pop(key,None)
 if row['character_id']=='nabi':
  for key in ['source_paths','source_sheet_sha256']:row.pop(key,None)
  row['source_path']=str((OUT/'nabi-knockdown-r01-source.png').relative_to(ROOT));row['source_sha256']=sha(ROOT/row['source_path'])
  row['conversion']={'source_grid':[4,4],'source_size':[1254,1254],'source_cell':313.5,'common_pixel_scale':128/313.5,'target_cell':128,'target_grid':[16,1],'method':'fixed-cell extraction; no per-pose resize'}
  row['creation']['reference_images']=references
  row['frame_anchors']=[{'body_root':[64.0,float(y)]} for y in [125,125,125,125,126,126,127,127,122,123,123,123,123,123,123,123]]
  row['asset_id']='nabi-knock-down-naturalness-r02'
source=Path('/Users/jdh/.codex/generated_images/01a1e973-bb23-73a2-8659-afc5c0a5bc64/exec-8f92238b-aa2e-4890-bf1f-ad63b5abfb53.png')
shutil.copyfile(source,OUT/'nabi-wakeup-r01-source.png')
im=Image.open(source).convert('RGBA');cell=im.width/4;strip=Image.new('RGBA',(2048,128))
for i in range(16):
 x=i%4*cell;y=i//4*cell
 strip.paste(im.transform((128,128),Image.Transform.EXTENT,(x,y,x+cell,y+cell),Image.Resampling.BICUBIC),(128*i,0))
png=OUT/'nabi-wake_up-r01.png';strip.save(png);tres=png.with_suffix('.tres')
manifest=json.loads((ROOT/'assets/character/manifest.json').read_text())['assets'];wake=next(a for a in manifest if a.get('character_id')=='nabi' and a.get('visual_state_id')=='wake_up')
tres.write_text((ROOT/wake['sprite_frames_path'].removeprefix('res://')).read_text().replace('res://'+wake['path'],'res://'+str(png.relative_to(ROOT))))
row={k:v for k,v in rows[1].items() if k not in ['landing_down_frame_range','state_hold_frame']}
row.update({'visual_state_id':'wake_up','asset_id':'nabi-wake-up-naturalness-r01','path':str(png.relative_to(ROOT)),'sprite_frames_path':'res://'+str(tres.relative_to(ROOT)),'sha256':sha(png),'source_path':str((OUT/'nabi-wakeup-r01-source.png').relative_to(ROOT)),'source_sha256':sha(source),'fps':wake['fps'],'loop':wake['loop'],'expected_action':'새 다운 마지막 옆으로 누운 자세에서 손·팔로 몸을 받치고 앉음→무릎→웅크림→대기 자세로 일어난다. 크기·위치가 튀지 않고 다시 눕지 않는다. 전투 기상 보호12틱 안에 표현하며 입력 복구를 지연하지 않는다.','frame_anchors':[{'body_root':[float(x),float(y)]} for x,y in zip([68,68,67,66,65,64,64,64,64,64,64,64,64,64,64,64],[115,115,115,117,116,115,116,116,116,115,115,114,122,122,122,122])],'creation':{'method':'built-in imagegen; fixed 4x4 grid extraction at common scale','provider':'OpenAI image_gen','version':'r01','source_path':str((OUT/'nabi-wakeup-r01-source.png').relative_to(ROOT)),'reference_images':[{'path':rows[1]['source_path'],'sha256':rows[1]['source_sha256']}]+references[:2]+[{'path':wake['path'],'sha256':wake['sha256']}]}})
rows.append(row)
old['assets']=rows;p=OUT/'catalog-r02.json';p.write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n')
(OUT/'scope-r02.json').write_text(json.dumps({'schema_version':1,'kind':'candidate-motion-review','catalog_sha256':sha(p),'motions':[{'character_id':r['character_id'],'motion':r['visual_state_id']} for r in rows]},ensure_ascii=False,indent=2)+'\n')
