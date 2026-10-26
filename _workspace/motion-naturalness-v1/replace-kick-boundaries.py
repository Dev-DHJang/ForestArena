"""Whole-pose layout only. Keep the validated kick middle; add drawn transitions."""
from pathlib import Path
import hashlib,importlib.util,json,math
from PIL import Image
b=Path(__file__).resolve().parent;root=b.parents[1]
spec=importlib.util.spec_from_file_location('regions',b/'split-figures.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
oldpath=b/'drafts/ja-hyun/attack_light_combo_04-r01.png';old=Image.open(oldpath).convert('RGBA');oldfigs,_=m.split_figures(old,4,4);cw=old.width/4
oldrow=json.loads((b/'candidates/ja-hyun/attack_light_combo_04_r02.json').read_text());world_unit=oldrow['conversion']['uniform_scale']*1.15
records=[];poses=[]
def quarter(name,factor,indices):
 path=b/'drafts/ja-hyun'/name;im=Image.open(path).convert('RGBA');figs,_=m.split_figures(im,2,2)
 records.append({'path':str(path.relative_to(root)),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'uniform_source_unit_scale':factor,'selected_frames':indices})
 for i in indices:
  crop,box=figs[i];local_x=box[0]-(i%2)*im.width/2
  x=cw/2+(local_x-im.width/4)*factor
  resized=crop.resize((round(crop.width*factor),round(crop.height*factor)),Image.Resampling.LANCZOS)
  poses.append((resized,x))
quarter('kick-start-quarter-r04.png',.525,[0,1,2,3])
records.append({'path':str(oldpath.relative_to(root)),'sha256':hashlib.sha256(oldpath.read_bytes()).hexdigest(),'uniform_source_unit_scale':1,'selected_frames':list(range(4,12))})
for i in range(4,12):
 crop,box=oldfigs[i];poses.append((crop,box[0]-(i%4)*cw))
quarter('kick-end-quarter-r04.png',.49,[0,1])
# Newly drawn bridge avoids the over-deep recovery dip in the first review.
bridge=b/'drafts/ja-hyun/kick-end-inbetween-r05.png';im=Image.open(bridge).convert('RGBA');box=im.getchannel('A').point(lambda v:255 if v>=32 else 0).getbbox();crop=im.crop(box);factor=.26
poses.append((crop.resize((round(crop.width*factor),round(crop.height*factor)),Image.Resampling.LANCZOS),cw/2+(box[0]-im.width/2)*factor))
records.append({'path':str(bridge.relative_to(root)),'sha256':hashlib.sha256(bridge.read_bytes()).hexdigest(),'uniform_source_unit_scale':factor,'selected_frames':[0],'role':'newly drawn recovery in-between, not a copied ready pose'})
# A shared approved ready pose is a designed endpoint, not filler/extra count.
idlepath=root/'assets/character/ja-hyun/animation/runtime/idle_16f.png';idle=Image.open(idlepath).convert('RGBA').crop((0,0,128,128));box=idle.getchannel('A').point(lambda v:255 if v>=32 else 0).getbbox();crop=idle.crop(box);factor=1/world_unit
poses.append((crop.resize((round(crop.width*factor),round(crop.height*factor)),Image.Resampling.LANCZOS),cw/2+(box[0]-64)*factor))
records.append({'path':str(idlepath.relative_to(root)),'sha256':hashlib.sha256(idlepath.read_bytes()).hexdigest(),'selected_frames':[0],'uniform_source_unit_scale':factor,'role':'shared approved final ready key; unique within this sixteen-frame attack'})
assert len(poses)==16
pad=math.ceil(max(16,16-min(x for _,x in poses),16+max(x+im.width for im,x in poses)-cw));w=math.ceil(cw+2*pad);h=max(im.height for im,_ in poses)+32;floor=h-16
out=Image.new('RGBA',(w*4,h*4))
for i,(im,x) in enumerate(poses):out.alpha_composite(im,(i%4*w+round(pad+x),i//4*h+floor-im.height))
path=b/'drafts/ja-hyun/attack_light_combo_04-r05-combined.png';out.save(path)
path.with_suffix('.json').write_text(json.dumps({'source_poses':records,'world_scale_per_source_pixel':world_unit,'cell_size':[w,h],'source_floor':floor,'method':'original complete pose pixels; one uniform head-unit scale per new quarter; unchanged middle source pixels; ground-aligned translation; approved ready endpoint; no pose warp or semantic repainting'},ensure_ascii=False,indent=2)+'\n')
print(path.relative_to(root),'cell',w,h,'world unit',world_unit)
