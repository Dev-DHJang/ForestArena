"""기상 후반의 낮은 대기 자세를 새 원화에서 공통 배율로 포장한다."""
from pathlib import Path
import hashlib, json, shutil
from PIL import Image
ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).resolve().parent
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
source=Path('/Users/jdh/.codex/generated_images/01a1e973-bb23-73a2-8659-afc5c0a5bc64/exec-a8a1f550-da5d-439b-b291-030c0eb8bccd.png')
saved=OUT/'nabi-wakeup-r02-source.png'
shutil.copyfile(source,saved)
im=Image.open(source).convert('RGBA');cell=im.width/4
strip=Image.new('RGBA',(2048,128))
for i in range(16):
 x=i%4*cell;y=i//4*cell
 strip.paste(im.transform((128,128),Image.Transform.EXTENT,(x,y,x+cell,y+cell),Image.Resampling.BICUBIC),(128*i,0))
png=OUT/'nabi-wake_up-r02.png';strip.save(png);tres=png.with_suffix('.tres')
tres.write_text((OUT/'nabi-wake_up-r01.tres').read_text().replace('nabi-wake_up-r01.png','nabi-wake_up-r02.png'))
catalog=json.loads((OUT/'catalog-r02.json').read_text())
row=next(a for a in catalog['assets'] if a['visual_state_id']=='wake_up')
row.update(asset_id='nabi-wake-up-naturalness-r02',path=str(png.relative_to(ROOT)),sprite_frames_path='res://'+str(tres.relative_to(ROOT)),sha256=sha(png),source_path=str(saved.relative_to(ROOT)),source_sha256=sha(saved))
row['frame_anchors']=[{'body_root':[float(x),float(y)]} for x,y in zip([68,68,67,66,65,64,64,64,64,64,64,64,64,64,64,64],[118,118,119,120,116,115,115,115,113,112,112,112,117,116,117,116])]
paths=['_workspace/combat-motion-naturalness/candidates/nabi-wakeup-r01-source.png','_workspace/motion-naturalness-v1/remaining/nabi/idle-r02.png','assets/character/nabi/reference/v01/combat.png','assets/character/nabi/reference/v01/front.png']
row['creation']={'method':'built-in imagegen endpoint pose edit; fixed 4x4 extraction at one common scale','provider':'OpenAI image_gen','version':'r02','source_path':str(saved.relative_to(ROOT)),'reference_images':[{'path':p,'sha256':sha(ROOT/p)} for p in paths]}
row['expected_action']='누운 자세에서 손 짚기→앉기→무릎→낮고 넓은 전투 대기 자세로 일어난다. 마지막에 높이 솟았다 내려앉지 않는다. 기상 보호12틱 안에 표현하고 입력 복구를 지연하지 않는다.'
next(a for a in catalog['assets'] if a['visual_state_id']=='knock_down')['expected_action']='피격 뒤 중심을 낮추고 옆으로 넘어져 눕는다. 중간에 다시 서거나 떠서 앉지 않고 새 기상의 첫 누운 자세로 이어진다.'
p=OUT/'catalog-r03.json';p.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')
(OUT/'scope-r03.json').write_text(json.dumps({'schema_version':1,'kind':'candidate-motion-review','catalog_sha256':sha(p),'motions':[{'character_id':r['character_id'],'motion':r['visual_state_id']} for r in catalog['assets']]},ensure_ascii=False,indent=2)+'\n')
