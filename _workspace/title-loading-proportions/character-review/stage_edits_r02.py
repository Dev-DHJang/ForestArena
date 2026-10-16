"""Pack built-in edited art for review only; no pixel-level proportion edits."""
from pathlib import Path
from PIL import Image, ImageDraw
import json,hashlib,sys,shutil
import numpy as np
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'tools/forest_arena'));from motion_sheet_regions import split_regions
IDS=('ja-hyun','myo-ryung','nabi','yu-ran')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def matte(im,bg='#344154'):
 x=Image.new('RGBA',im.size,bg);x.alpha_composite(im);return x.convert('RGB')
def pack(fs):
 im=Image.new('RGBA',(512,512))
 for i,f in enumerate(fs):im.alpha_composite(f,((i%4)*128,(i//4)*128))
 return im
def read(fs):
 im=Image.open(fs).convert('RGBA');return [im.crop(((i%4)*128,(i//4)*128,(i%4+1)*128,(i//4+1)*128)) for i in range(16)]
after={'ja-hyun':read(OUT/'ja-hyun/idle-reference-4x4.png'),'myo-ryung':read(OUT/'myo-ryung/idle-review-4x4.png')};records=[]
landmarks={'nabi':{'crown_y':29,'chin_y':100,'sole_y':220,'head_left_x':101,'head_right_x':176},'yu-ran':{'crown_y':31,'chin_y':98,'sole_y':221,'head_left_x':111,'head_right_x':181}}
for cid,row in landmarks.items():
 folder=OUT/'edits-r02'/cid;source=folder/'idle-head-width-source.png';im=Image.open(source).convert('RGBA');fs=split_regions(im)
 scale=72/(row['sole_y']-row['crown_y']);out=[]
 for i,f in enumerate(fs):
  size=(round(f.width*scale),round(f.height*scale));rgba=np.asarray(f);_,xs=np.nonzero(rgba[round(f.height*.78):,:,3]>=64);assert len(xs)
  support=(int(xs.min())+int(xs.max())+1)/2
  x=round(64-support*scale);y=124-size[1]
  assert x>=2 and x+size[0]<=126 and y>=2,(cid,i,size,x,y)
  cell=Image.new('RGBA',(128,128));cell.alpha_composite(f.resize(size,Image.Resampling.LANCZOS),(x,y));out.append(cell)
 assert len({hashlib.sha256(f.tobytes()).hexdigest() for f in out})==16
 pack(out).save(folder/'idle-head-width-review-4x4.png');out[0].save(folder/'idle-head-width-preview-128.png')
 anim=[matte(f) for f in out];anim[0].save(folder/'idle-head-width-review.gif',save_all=True,append_images=anim[1:],duration=[120,130]*8,loop=0)
 after[cid]=out
 h=(row['chin_y']-row['crown_y'])*scale;w=(row['head_right_x']-row['head_left_x'])*scale
 rec={'character_id':cid,'status':'new-edit-user-review-pending','source_sha256':sha(source),'review_sha256':sha(folder/'idle-head-width-review-4x4.png'),'gif_sha256':sha(folder/'idle-head-width-review.gif'),'source_dimensions':list(im.size),'alpha_range':list(im.getchannel('A').getextrema()),'first_extracted_pose_dimensions':list(fs[0].size),'fixed_motion_scale':scale,'manual_landmarks':row,'scaled_body_height':72,'scaled_head_height':h,'scaled_head_width':w,'head_height_difference':abs(h/26-1),'head_width_difference':abs(w/27-1),'frame_count':16,'unique_frames':16,'all_joint_compliance_proven':False,'measurement_note':'Approximate visible cranial hair cap excluding ears and loose ponytail; first neutral pose. Manual judgment, not 3D skeleton.'};records.append(rec)
 assert rec['head_height_difference']<=.1 and rec['head_width_difference']<=.1
 # Measurement guides annotate extracted pose without altering the deliverable art.
 f=fs[0];board=matte(f).resize((f.width*3,f.height*3));d=ImageDraw.Draw(board)
 for key,color in (('crown_y','#ffca61'),('chin_y','#8fffc0'),('sole_y','#ffffff')):
  y=row[key]*3;d.line((0,y,board.width-1,y),fill=color,width=2);d.text((2,y-12),f'{key}={row[key]}',fill=color)
 for key in ('head_left_x','head_right_x'):
  x=row[key]*3;d.line((x,row['crown_y']*3,x,row['chin_y']*3),fill='#ff8ffd',width=2);d.text((x+2,row['crown_y']*3),str(row[key]),fill='#ff8ffd')
 board.save(folder/'first-pose-measurement.png')
# Preserve the first comparison and replace the main review link with materially corrected samples.
p=OUT/'comparison-before-after.png';first=OUT/'comparison-before-after-r01.png'
if not first.exists():shutil.copy2(p,first)
board=Image.new('RGB',(1100,720),'#1e2734');d=ImageDraw.Draw(board);d.text((24,12),'Head width corrected r02 / same 128px cells / no extra whole-sprite scale',fill='white')
for col,cid in enumerate(IDS):
 x=45+260*col;d.text((x,42),cid,fill='white');im=Image.open(ROOT/f'assets/character/{cid}/animation/runtime/idle_16f.png').convert('RGBA');before=im.crop((0,0,128,128))
 for y,f,label in ((78,before,'current runtime'),(370,after[cid][0],'r02 review / approval pending')):
  d.text((x,y-20),label,fill='#b5c8e0');board.paste(matte(f).resize((256,256),Image.Resampling.NEAREST),(x,y))
board.save(p)
for bg,name in (('#f2f4f7','light'),('#243044','dark')):
 strip=Image.new('RGBA',(512,128),bg)
 for col,cid in enumerate(IDS):strip.alpha_composite(after[cid][0],(col*128,0))
 strip.convert('RGB').save(OUT/f'same-size-128-{name}.png');strip.convert('RGB').resize((2048,512),Image.Resampling.NEAREST).save(OUT/f'same-size-4x-{name}.png')
(OUT/'edits-r02/report.json').write_text(json.dumps({'reference':{'head_width':27,'head_left_x':62,'head_right_x':89,'head_height':26,'body_height':72},'myo_reused':{'head_left_x':60,'head_right_x':88,'head_width':28,'relative_head_width_difference':abs(28/27-1),'head_height':25.5,'body_height':72},'scope':'Manual 2D first-pose cranial hair-cap bounds; broad head correction review. Not all-joint length compliance.','edits':records},ensure_ascii=False,indent=2)+'\n')
print('HEAD_WIDTH_EDIT_REVIEW_R02: PASS: 2 built-in edited sources, 32 unique RGBA frames, fixed scale per motion, head width/height neutral landmarks within10%; body72px; no runtime writes.')
