"""Whole-figure source assembly only: no drawing, warping, or pose changes."""
from pathlib import Path
import hashlib,importlib.util,json
from PIL import Image
ROOT=Path(__file__).resolve().parents[4]
TOPIC=ROOT/'_workspace/motion-naturalness-v1'
BASE=TOPIC/'remaining/ja-hyun'
spec=importlib.util.spec_from_file_location('split_figures',TOPIC/'split-figures.py');mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
old_path=BASE/'special_neutral-r01.png';quarter_path=BASE/'special_neutral-impact-quarter-r02.png'
old=Image.open(old_path).convert('RGBA')
# The entire second physical row is discarded. Boundaries fall in real transparent
# gutters (all valid first-row pixels end before365, next retained row starts>650).
retained=old.copy();retained.paste((0,0,0,0),(0,365,old.width,650))
original,unused=mod.split_figures(retained,4,3)
new,_=mod.split_figures(Image.open(quarter_path).convert('RGBA'),2,2)
selected=[(old_path,i,1.0,*original[i]) for i in range(4)]
selected += [(quarter_path,i,.58,*new[i]) for i in range(4)]
selected += [(old_path,i+4,1.0,*original[i]) for i in range(4,12)]
cell=(420,400);floor=370;canvas=Image.new('RGBA',(cell[0]*4,cell[1]*4))
records=[]
for index,(source,source_index,factor,figure,box) in enumerate(selected):
 scaled=figure.resize((round(figure.width*factor),round(figure.height*factor)),Image.Resampling.LANCZOS)
 x=index%4*cell[0]+round((cell[0]-scaled.width)/2);y=index//4*cell[1]+floor-scaled.height
 canvas.alpha_composite(scaled,(x,y))
 records.append({'frame':index,'source_path':str(source.relative_to(ROOT)),'source_pose_index':source_index,'source_box':box,'whole_figure_uniform_scale':factor,'destination_top_left':[x,y],'scaled_size':list(scaled.size)})
out=BASE/'special_neutral-r02-combined.png';canvas.save(out)
figures,_=mod.split_figures(canvas,4,4)
a=canvas.getchannel('A');w,h=canvas.size;edges=[sum(v>=32 for v in a.crop(b).getdata()) for b in [(0,0,1,h),(0,0,w,1),(w-1,0,w,h),(0,h-1,w,h)]]
assert len(figures)==16 and edges==[0,0,0,0]
report={'character_id':'ja-hyun','motion':'special_neutral','status':'pending independent QA and explicit user approval','method':'whole original figure extraction and one uniform scale per source part; cell arrangement only; no redraw, warp, interpolation poses or duplicate filling','source_grid':[4,4],'source_cell_size':list(cell),'frame_count':16,'source_png':str(out.relative_to(ROOT)),'source_png_sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'source_dimensions':list(canvas.size),'input_files':[{'path':str(p.relative_to(ROOT)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in [old_path,quarter_path]],'quarter_uniform_scale':.58,'quarter_scale_basis':'ear-top to chin head unit about205px in quarter versus119px in original;119/205 about0.58; entire figures scaled together','source_frame_mapping':records,'checks':{'complete_figures':len(figures),'outer_edge_alpha32_pixels':edges},'remaining_checks':'actual transitions, scarf anchors, normal/slow mirror/small, independent QA'}
(BASE/'special_neutral-r02-combined.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'output':str(out.relative_to(ROOT)),'figures':len(figures),'edges':edges,'sha256':report['source_png_sha256']}))
