"""Lossless figure separation before rearranging generated quarter sheets."""
from pathlib import Path
import argparse,importlib.util,json,hashlib,math
from PIL import Image
p=argparse.ArgumentParser();p.add_argument('character');p.add_argument('--sources',nargs=4,required=True);p.add_argument('--output',required=True);a=p.parse_args()
base=Path(__file__).resolve().parent;root=base.parents[1]
spec=importlib.util.spec_from_file_location('split_figures',base/'split-figures.py');split=importlib.util.module_from_spec(spec);spec.loader.exec_module(split)
frames=[];records=[];sizes=[]
for q,name in enumerate(a.sources):
 path=root/name;im=Image.open(path).convert('RGBA');cw,ch=im.width/2,im.height/2;sizes.append((cw,ch))
 figures,unused=split.split_figures(im,2,2)
 for index,(crop,box) in enumerate(figures):frames.append((crop,box[0]-(index%2)*cw,box[1]-(index//2)*ch))
 records.append({'path':name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'bounds':[box for _,box in figures],'unassigned':unused})
assert len(set(sizes))==1,'quarters must use the same source pixel unit'
cw,ch=sizes[0];px=math.ceil(max(16,16-min(x for _,x,y in frames),16+max(x+im.width for im,x,y in frames)-cw));py=math.ceil(max(16,16-min(y for _,x,y in frames),16+max(y+im.height for im,x,y in frames)-ch))
w,h=round(cw+2*px),round(ch+2*py);out=Image.new('RGBA',(w*4,h*4))
for i,(im,x,y) in enumerate(frames):out.alpha_composite(im,(i%4*w+round(px+x),i//4*h+round(py+y)))
path=root/a.output;out.save(path)
path.with_suffix('.json').write_text(json.dumps({'source_quarters':records,'cell_size':[w,h],'uniform_padding':[px,py],'method':'separate original connected figures BEFORE row rearrangement; original pixel RGBA only; no pose repainting/warping'},ensure_ascii=False,indent=2)+'\n')
print(path.relative_to(root))
