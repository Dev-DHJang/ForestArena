"""r03: 승인 idle과 같은 표시 배율/발 위치, 두 신발 기준. 원화 재그림 없음."""
from pathlib import Path
from PIL import Image,ImageDraw
import json,hashlib,shutil,numpy as np
ROOT=Path(__file__).resolve().parents[2];BASE=ROOT/'_workspace/pebble-yoyo';SOURCE=Path('/Users/jdh/.codex/generated_images/01a18b45-1561-7d91-ab6c-2a6dc3ba2cfe')
JOBS=[('ja-hyun','ground','exec-f61ecbc2-1686-4618-8481-eee2bf718043.png',.3353,.85,124,64),('ja-hyun','air','exec-4173d132-2588-4f9c-8755-803da37d4065.png',.375,.85,117,64),('nabi','ground','exec-9b451a94-c224-42a1-8dd2-90166a6997f0.png',.34,.909369596799596,123,64),('nabi','air','exec-c98e18f3-6d24-4385-83c3-3bca3e57b817.png',.29,.8488372093023255,104,64)]
MANIFEST=json.loads((ROOT/'assets/character/manifest.json').read_text())['assets']
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def cut(proj,n):
 candidates=range(max(1,int(n)-24),min(len(proj)-1,int(n)+24));q=min(candidates,key=lambda k:(int(proj[k]),abs(k-n)));assert proj[q]==0,('no gap',n,q,int(proj[q]));return q
for c,mode,src,scale,display,baseline,targetx in JOBS:
 d=BASE/f'motions/{c}/{mode}/r03';d.mkdir(parents=True,exist_ok=True);shutil.copy2(SOURCE/src,d/'source.png')
 im=Image.open(d/'source.png').convert('RGBA');mask=np.array(im.getchannel('A'))>64;h,w=mask.shape;ys=[0]+[cut(mask.sum(1),h*i/4) for i in range(1,4)]+[h];frames=[];records=[]
 for row in range(4):
  xs=[0]+[cut(mask[ys[row]:ys[row+1]].sum(0),w*i/4) for i in range(1,4)]+[w]
  for col in range(4):
   rect=(xs[col],ys[row],xs[col+1],ys[row+1]);cell=im.crop(rect);a=np.array(cell.getchannel('A'))>64;yy,xx=np.nonzero(a);bottom=int(yy.max())+1
   if mode=='ground':
    # Both soles are visibly in this broad shoe band; never lowest12px.
    region=(yy>=bottom-55);left=int(xx[region].min());right=int(xx[region].max());cx=(left+right)/2
   else:
    # Fixed source-column body position, not tucked feet, tail or ribbons.
    rgb=np.array(cell); skin=(rgb[:,:,0]>150)&(rgb[:,:,1]>100)&(rgb[:,:,2]<220)&(rgb[:,:,0]>rgb[:,:,1]*1.1)&a
    top=int(yy.min());skin[:top+int((bottom-top)*.25)]=False;skin[top+int((bottom-top)*.55):]=False
    sy,sx=np.nonzero(skin);cx=float(np.median(sx))-25 if c=='ja-hyun' else float(np.median(sx))-22;left=right=None
   offset=(round(targetx-cx*scale),round(baseline-bottom*scale));size=(round(cell.width*scale),round(cell.height*scale));frame=Image.new('RGBA',(128,128));frame.alpha_composite(cell.resize(size,Image.Resampling.LANCZOS),offset)
   bb=frame.getchannel('A').point(lambda x:255 if x>64 else 0).getbbox();assert bb and bb[0]>0 and bb[1]>0 and bb[2]<128 and bb[3]<128,(c,mode,row,col,bb)
   frames.append(frame);records.append({'source_rect':rect,'common_scale':scale,'translation':offset,'body_column_source_x':cx,'two_shoe_region_x':[left,right] if left is not None else None,'foot_baseline_source_y':bottom,'foot_baseline_target_y':baseline,'target_two_shoe_midpoint_x':targetx,'landmark_method':'both visible soles in hand-checked55px shoe band, never lowest shoe only' if mode=='ground' else 'hand-checked face core landmark, uniform scale, no tucked-foot recentring'})
 # Use the exact already-approved whole idle pose at entry and recovery endpoint.
 # This is a semantic transition endpoint, not repeated filler or a part warp.
 approved=next(a for a in MANIFEST if a.get('character_id')==c and a.get('visual_state_id')=='idle' and a.get('type')=='animation-runtime')
 endpoints=[]
 if mode=='ground':
  idle=Image.open(ROOT/approved['path']).convert('RGBA').crop((0,0,128,128))
  for i in [0,15]: frames[i]=idle.copy();endpoints.append({'frame':i,'source_path':approved['path'],'source_frame':0,'source_sha256':sha(ROOT/approved['path']),'operation':'whole-cell exact copy, no resize or part edits'})
 sheet=Image.new('RGBA',(1024,256));board=Image.new('RGB',(1024,1104),'#182c35')
 for i,f in enumerate(frames):
  sheet.alpha_composite(f,((i%8)*128,(i//8)*128));tile=Image.new('RGBA',(256,276),'#213d47');tile.alpha_composite(f.resize((256,256),Image.Resampling.NEAREST),(0,20));ImageDraw.Draw(tile).text((8,4),str(i),fill='white');board.paste(tile.convert('RGB'),((i%4)*256,(i//4)*276))
 sheet.save(d/'sheet-128.png');board.save(d/'contact.png')
 refs=[ROOT/f'assets/character/{c}/reference/v01/combat.png',ROOT/f'assets/character/{c}/reference/v01/side.png',BASE/'revision-r03-inputs'/f'{c}-{("idle" if mode=="ground" else "jump")}-approved.png']
 comparison_refs=[]
 if c=='ja-hyun' and mode=='air':
  comparison_refs=[{'path':str(refs[-1].relative_to(ROOT)),'sha256':sha(refs[-1]),'role':'review comparison only; not attached to selected generation chain'}]
  refs=[ROOT/'_workspace/motion-naturalness-v1/drafts/ja-hyun/jump-r02.png',*refs[:2]]
 m={'character_id' :c,'motion_id':'equipment_yoyo_'+mode,'status':'candidate-pending-independent-review-and-user-approval','frame_count':16,'cell_size':[128,128],'columns':8,'source_grid':[4,4],'common_scale':scale,'foot_pivot_y':baseline,'presentation_scale':display,'equipment_phase_frame_ranges':[[0,3],[3,8],[8,13],[13,16]],'frame_durations':[2,2,2,4,4,4,3,3,4,4,4,3,3,2,2,2],'reference_version':'v01','comparison_references':comparison_refs,'reference_set':f'assets/character/{c}/reference/v01/reference.json','reference_attachments':[{'path':str(p.relative_to(ROOT)),'sha256':sha(p)} for p in refs],'source_path':str((d/'source.png').relative_to(ROOT)),'source_sha256':sha(d/'source.png'),'sheet_sha256':sha(d/'sheet-128.png'),'packing':records,'whole_figure_boundary_endpoints':endpoints,'frame_anchors':[{'body_root':[64 if i in [0,15] else 47,baseline]} for i in range(16)] if c=='nabi' and mode=='ground' else [],'size_basis':'approved runtime idle or jump model, head/body and two-shoe silhouette; one uniform source scale per motion; exact approved idle whole-figure entry/recovery endpoint on ground'}
 previous=json.loads((d/'candidate.json').read_text()) if (d/'candidate.json').exists() else {}
 if previous.get('frame_anchors'):m['frame_anchors']=previous['frame_anchors']
 (d/'candidate.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n');print(c,mode,'packed',scale,display)
