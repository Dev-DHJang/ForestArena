"""원화를 다시 그리지 않고 공통 배율·발 기준 이동으로 모션 후보를 포장한다."""
from pathlib import Path
from PIL import Image, ImageDraw
import numpy as np, json, hashlib, shutil
ROOT=Path(__file__).resolve().parents[2]
SOURCE=Path('/Users/jdh/.codex/generated_images/01a18aea-103c-78c0-910c-6a29b46419b6')
JOBS=[('ja-hyun','ground','exec-35d2d2db-2acb-4010-a520-8a63e5eaef36.png'),('ja-hyun','air','exec-d35cfa25-1e3b-46c5-a89d-b15bc11d2b01.png'),('nabi','ground','exec-a5343993-e20d-4cb2-b542-8138ec477f3a.png'),('nabi','air','exec-94ef52d9-889f-469c-a7b6-a3919e60acd1.png')]
SCALE=.32

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def boundary(projection, nominal):
 lo=max(1,int(nominal)-32);hi=min(len(projection)-1,int(nominal)+32)
 # Prefer true transparent gaps nearest nominal; never cut a visible outline.
 indexes=list(range(lo,hi));chosen=min(indexes,key=lambda x:(int(projection[x]),abs(x-nominal)))
 if projection[chosen]>0: raise ValueError('No transparent separator; regenerate, do not cut artwork')
 return chosen

for character,mode,file in JOBS:
 dest=ROOT/'_workspace/pebble-yoyo/motions'/character/mode/'r02';dest.mkdir(parents=True,exist_ok=True)
 shutil.copy2(SOURCE/file,dest/'source.png')
 im=Image.open(dest/'source.png').convert('RGBA');mask=np.array(im.getchannel('A'))>64;h,w=mask.shape
 assert not any((mask[0].any(),mask[-1].any(),mask[:,0].any(),mask[:,-1].any())), 'clipped outer source'
 ys=[0]+[boundary(mask.sum(1),h*i/4) for i in range(1,4)]+[h]
 sheet=Image.new('RGBA',(1024,256));records=[];frames=[]
 for row in range(4):
  band=mask[ys[row]:ys[row+1]]
  xs=[0]+[boundary(band.sum(0),w*i/4) for i in range(1,4)]+[w]
  for col in range(4):
   rect=(xs[col],ys[row],xs[col+1],ys[row+1]);cell=im.crop(rect);a=np.array(cell.getchannel('A'))>64
   yy,xx=np.nonzero(a);bottom=int(yy.max())+1
   # Both shoe soles define the reference. Tail/ribbon extent never determines scale.
   foot_pixels=(yy>=bottom-12);foot_x=(int(xx[foot_pixels].min())+int(xx[foot_pixels].max()))/2
   if mode == "air": foot_x=cell.width/2 # fixed source body column center; tucked shoes do not move body sideways
   offset=(round(64-foot_x*SCALE),round(120-bottom*SCALE))
   resized=cell.resize((round(cell.width*SCALE),round(cell.height*SCALE)),Image.Resampling.LANCZOS)
   frame=Image.new('RGBA',(128,128));frame.alpha_composite(resized,offset)
   bb=frame.getchannel('A').point(lambda v:255 if v>64 else 0).getbbox()
   assert bb and bb[0]>0 and bb[1]>0 and bb[2]<128 and bb[3]<128,(character,mode,row,col,bb)
   frames.append(frame);sheet.alpha_composite(frame,(((row*4+col)%8)*128,((row*4+col)//8)*128))
   records.append({'source_rect':rect,'common_scale':SCALE,'foot_baseline_y':120,'foot_midpoint_source':[foot_x,bottom],'translation':offset})
 sheet.save(dest/'sheet-128.png')
 # Contact board is a review artifact only.
 board=Image.new('RGB',(1024,1104),'#182c35');draw=ImageDraw.Draw(board)
 for i,frame in enumerate(frames):
  tile=Image.new('RGBA',(256,276),'#213d47');tile.alpha_composite(frame.resize((256,256),Image.Resampling.NEAREST),(0,20));ImageDraw.Draw(tile).text((8,4),str(i+1),fill='white');board.paste(tile.convert('RGB'),((i%4)*256,(i//4)*276))
 board.save(dest/'contact.png')
 ref=ROOT/f'assets/character/{character}/reference/v01/reference.json';refs=[ref.parent/'combat.png',ref.parent/'side.png']
 metadata={'character_id':character,'motion_id':'equipment_yoyo_'+mode,'status':'candidate-pending-independent-review-and-user-approval','frame_count':16,'cell_size':[128,128],'columns':8,'source_grid':[4,4],'common_scale':SCALE,'foot_pivot_y':120,'presentation_scale':1.0,'equipment_phase_frame_ranges':[[0,3],[3,8],[8,13],[13,16]],'frame_durations':[2,2,2,4,4,4,3,3,4,4,4,3,3,2,2,2],'reference_version':'v01','reference_set':str(ref.relative_to(ROOT)),'reference_attachments':[{'path':str(p.relative_to(ROOT)),'sha256':sha(p)} for p in refs],'source_sha256':sha(dest/'source.png'),'sheet_sha256':sha(dest/'sheet-128.png'),'packing':records,'frame_anchors':[]}
 previous=json.loads((dest/'candidate.json').read_text()) if (dest/'candidate.json').exists() else {}
 for field in ['presentation_scale','size_basis','frame_anchors']:
  if field in previous:metadata[field]=previous[field]
 (dest/'candidate.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2)+'\n')
 print(character,mode,'packed16, common scale',SCALE)
