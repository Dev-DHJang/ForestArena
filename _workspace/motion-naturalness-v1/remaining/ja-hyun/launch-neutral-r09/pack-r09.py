from PIL import Image,ImageDraw,ImageFilter
from pathlib import Path
import json,hashlib,math
R=Path(__file__).resolve().parents[5]
D=Path(__file__).parent
# Drawing pixels are only cropped, uniformly resized as a whole, and translated.
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
old=json.loads((R/'_workspace/motion-naturalness-v1/candidates/remaining/ja-hyun/launch_r01.json').read_text())
old_png=R/old['path']; atlas=Image.open(old_png).convert('RGBA'); src=Image.open(D/'neutral-four-source-r02.png').convert('RGBA')
jump_path=R/'assets/character/ja-hyun/animation/runtime/jump_24f_natural-v02.png'; jump=Image.open(jump_path).convert('RGBA').crop((10*128,0,11*128,128))
# Measured near-ear outer tip to chin; not the collar or fingers. ±3 output cell px.
raws=[dict(frame=13,box=[129,0,724,515],ear=[54+8,33+4],chin=[216+8,193+4],paste=[30,25]),dict(frame=14,box=[779,0,1445,523],ear=[207+8,26+5],chin=[340+8,213+5],paste=[13,28]),dict(frame=15,box=[112,513,682,1012],ear=[293+8,11+8],chin=[417+8,218+8],paste=[10,33])]
scale=.16
cells=[atlas.crop((i*128,0,(i+1)*128,128)) for i in range(12)]
metrics=[]
for item in raws:
 crop=src.crop(tuple(item['box'])); new_size=tuple(round(v*scale) for v in crop.size)
 tile=Image.new('RGBA',(128,128)); tile.alpha_composite(crop.resize(new_size,Image.Resampling.LANCZOS),tuple(item['paste']));cells.append(tile)
 a=tile.getchannel('A'); core=a.point(lambda v:255 if v>=128 else 0); expanded=core.filter(ImageFilter.MaxFilter(11))
 outside=[v for v,c in zip(a.tobytes(),expanded.tobytes()) if not c]
 item.update(uniform_scale=scale,resized_size=list(new_size),body_root=[64,104],ear_cell=[item['paste'][k]+item['ear'][k]*scale for k in (0,1)],chin_cell=[item['paste'][k]+item['chin'][k]*scale for k in (0,1)])
 item['ear_to_chin_world_px']=math.dist(item['ear_cell'],item['chin_cell'])*.85
 item['alpha_max_beyond_5px_core']=max(outside,default=0); item['alpha_ge_12_beyond_5px_core']=sum(v>=12 for v in outside)
 metrics.append(item)
cells.append(jump)
out=Image.new('RGBA',(2048,128))
for i,c in enumerate(cells):out.paste(c,(i*128,0))
png=D/'launch_16f_neutral-r09.png';out.save(png)
assert all(cells[i].tobytes()==atlas.crop((i*128,0,(i+1)*128,128)).tobytes() for i in range(12))
assert cells[15].tobytes()==jump.tobytes()
entry={k:v for k,v in old.items() if k not in ['conversion','source_paths','source_sha256']}
entry.update(path=str(png.relative_to(R)),sprite_frames_path='res://'+str((D/'launch_neutral-r09.tres').relative_to(R)),sha256=digest(png),source_paths=[str((D/'neutral-four-source-r02.png').relative_to(R))],source_sha256=digest(D/'neutral-four-source-r02.png'),frame_anchors=[{'body_root':[64,104]} for _ in range(15)]+[{'body_root':[64,117]}],status='unapproved-workspace-only',conversion={'method':'F1–12 exact prior RGBA; F13–15 new r02 original poses, uniform whole-figure 0.16 scale + translation; F16 whole approved jump F11 shared neutral boundary pose, exact RGBA', 'new_pose_placements':metrics, 'shared_boundary_pose':{'source':str(jump_path.relative_to(R)),'source_sha256':digest(jump_path),'source_frame_one_based':11,'body_root':[64,117]},'preserved_first_twelve':{'source':str(old_png.relative_to(R)),'source_sha256':digest(old_png),'all_rgba_equal':True}})
entry['creation']={'method':'OpenAI built-in image_gen new F13–15 poses; existing F1–12 exact pixel preservation; approved jump F11 whole-pose boundary sharing','provider':'OpenAI built-in image generation','version':'launch-neutral-r09','prompt_path':str((D/'neutral-four-source-r02.prompt.txt').relative_to(R)),'source_roles':[{'role':'preserved F1–12','path':str(old_png.relative_to(R)),'sha256':digest(old_png)},{'role':'new F13–15 drawings','path':str((D/'neutral-four-source-r02.png').relative_to(R)),'sha256':digest(D/'neutral-four-source-r02.png')},{'role':'shared boundary F16 from approved jump F11','path':str(jump_path.relative_to(R)),'sha256':digest(jump_path)}]}
entry['rights']={'status':'project candidate derived from previously approved Ja-Hyun appearance references; new poses generated with built-in image_gen; no separate legal verification asserted','approval':'pending independent visual QA and explicit per-motion user approval'}
(D/'launch_neutral-r09.json').write_text(json.dumps(entry,ensure_ascii=False,indent=2)+'\n')
tres=(R/'_workspace/motion-naturalness-v1/candidates/remaining/ja-hyun/launch_r01.tres').read_text().replace('res://'+old['path'],'res://'+str(png.relative_to(R)))
(D/'launch_neutral-r09.tres').write_text(tres)
proof={'first_12_rgba_equal':True,'shared_f16_jump_f11_rgba_equal':True,'presentation_scale':.85,'f16_root':[64,117],'jump_root':[64,117],'f16_boundary_world_rgba_equal_normal_and_mirror':True,'new_pose_placements':metrics,'atlas_sha256':digest(png),'source_sha256':digest(D/'neutral-four-source-r02.png'),'source_preserved':True,'qa_status':'producer technical check only; independent visual QA and user approval pending'}
(D/'packing-proof-r09.json').write_text(json.dumps(proof,ensure_ascii=False,indent=2)+'\n')
# Compare at identical fighter origin, no body part edits. At 1x image unit = world pixel.
seq=[(cells[11],104,'F12 old'),(cells[12],104,'F13 new'),(cells[13],104,'F14 new'),(cells[14],104,'F15 new'),(cells[15],117,'F16 shared'),(jump,117,'jump F11')]
board=Image.new('RGB',(240*6,220*3),'white');draw=ImageDraw.Draw(board)
for row,bg in enumerate([(245,245,245),(28,30,37),(138,138,138)]):
 for n,(tile,root,label) in enumerate(seq):
  panel=Image.new('RGBA',(240,220),bg+(255,));d=ImageDraw.Draw(panel);ox,oy=120,165
  d.line((0,oy,240,oy),fill=(120,150,120,255));d.line((ox,20,ox,205),fill=(120,150,120,255))
  # Exact same display transform as presentation: ground_contact offset common omitted.
  sz=round(128*.85);render=tile.resize((sz,sz),Image.Resampling.NEAREST)
  panel.alpha_composite(render,(round(ox-64*.85),round(oy-root*.85)))
  d.text((8,8),label+' root '+str(root),fill=(255,255,255,255) if row==1 else (0,0,0,255));board.paste(panel.convert('RGB'),(n*240,row*220))
board.save(D/'same-origin-r09.png')
board.resize((2880,1320),Image.Resampling.NEAREST).save(D/'same-origin-r09-2x.png')
# All 16 exact candidate cells for contact review.
allboard=Image.new('RGBA',(512,4*152),(110,110,110,255));d=ImageDraw.Draw(allboard)
for i,tile in enumerate(cells):
 x=(i%4)*128;y=(i//4)*152;allboard.alpha_composite(tile,(x,y+24));d.text((x+4,y+4),'F'+str(i+1),fill='white')
allboard.save(D/'all16-r09.png')
print(json.dumps(proof,ensure_ascii=False))
