"""Candidate layout conversion only; no pose generation or semantic repainting."""
import argparse, hashlib, json, math, statistics, importlib.util
from pathlib import Path
from PIL import Image
P=argparse.ArgumentParser();P.add_argument('character');P.add_argument('motion');P.add_argument('source');P.add_argument('--count',type=int,required=True);P.add_argument('--columns',type=int,required=True);P.add_argument('--rows',type=int,default=4);P.add_argument('--version',default='r01');P.add_argument('--ground-start',type=int,default=0);P.add_argument('--select');P.add_argument('--phase-counts');P.add_argument('--frame-offsets')
a=P.parse_args();ROOT=Path(__file__).resolve().parents[2];BASE=Path(__file__).resolve().parent
offsets=json.loads((ROOT/a.frame_offsets).read_text()) if a.frame_offsets else {}
source=ROOT/a.source;im=Image.open(source).convert('RGBA');assert a.count in (16,24,32)
spec=importlib.util.spec_from_file_location('split_figures',BASE/'split-figures.py');split=importlib.util.module_from_spec(spec);spec.loader.exec_module(split)
figures,unused=split.split_figures(im,a.columns,a.rows)
selection=list(map(int,a.select.split(','))) if a.select else list(range(a.columns*a.rows))
assert len(selection)==a.count and len(set(selection))==a.count and all(0<=i<len(figures) for i in selection)
cw,ch=im.width/a.columns,im.height/a.rows
ref=Image.open(ROOT/'assets/character'/a.character/'animation/runtime/idle_16f.png').crop((0,0,128,128))
rb=ref.getchannel('A').point(lambda v:255 if v>=32 else 0).getbbox();target_height=rb[3]-rb[1]
standing=[figures[i][1] for i in selection[a.ground_start:]]
scale=target_height/statistics.median(b[3]-b[1] for b in standing)
reference_scale=scale
# A single scale for the whole motion; inverse presentation scale keeps its
# world size. Wide poses must fit without clipping or per-frame auto-fit.
horizontal_extent=max(max(abs(b[0]-(i%a.columns+.5)*cw),abs(b[2]-(i%a.columns+.5)*cw)) for i in selection for b in [figures[i][1]])
vertical_span=max(figures[i][1][3]-(i//a.columns)*ch for i in selection)-min(figures[i][1][1]-(i//a.columns)*ch for i in selection)
scale=min(scale,62/horizontal_extent,123/vertical_span)
foot_source=statistics.median(figures[i][1][3]-(i//a.columns)*ch for i in selection[a.ground_start:])
tx=64-cw*scale/2;ty=124-foot_source*scale
out=Image.new('RGBA',(2048,math.ceil(a.count/16)*128));out_bounds=[];placements=[];ground_anchor_offsets={}
for target,source_index in enumerate(selection):
 cell,source_box=figures[source_index]
 scaled=cell.resize((round(cell.width*scale),round(cell.height*scale)),Image.Resampling.LANCZOS)
 x=round(tx+(source_box[0]-(source_index%a.columns)*cw)*scale)
 y=round(ty+(source_box[1]-(source_index//a.columns)*ch)*scale)
 box=scaled.getchannel('A').point(lambda v:255 if v>=32 else 0).getbbox()
 if a.motion=='jump' and target>=a.ground_start:
  ground_anchor_offsets[str(target)]=124-box[3]-y
  y=124-box[3]
 if str(target) in offsets:
  dx,dy=offsets[str(target)];x+=round(dx);y+=round(dy)
 assert box and x+box[0]>=1 and x+box[2]<=127,('pose clipped horizontally',target,source_box,box,x,y)
 placements.append((target,scaled,x,y,box))
padding_shift_y=min(0,126-max(y+box[3] for _,_,_,y,box in placements))
assert min(y+box[1]+padding_shift_y for _,_,_,y,box in placements)>=1,'poses exceed cell height; do not crop'
for target,scaled,x,y,box in placements:
 y+=padding_shift_y
 out.alpha_composite(scaled,(target%16*128+x,target//16*128+y));out_bounds.append([x+box[0],y+box[1],x+box[2],y+box[3]])
folder=BASE/'candidates'/a.character;folder.mkdir(parents=True,exist_ok=True)
png=folder/f'{a.motion}_{a.count}f_{a.version}.png';tres=folder/f'{a.motion}_{a.version}.tres';out.save(png)
lines=[f'[gd_resource type="SpriteFrames" load_steps={a.count+2} format=3]','',f'[ext_resource type="Texture2D" path="res://{png.relative_to(ROOT).as_posix()}" id="1"]']
for i in range(a.count):lines+=['',f'[sub_resource type="AtlasTexture" id="Frame_{i}"]','atlas = ExtResource("1")',f'region = Rect2({i%16*128}, {i//16*128}, 128, 128)']
loop=a.motion=='run';fps=12
lines+=['','[resource]','animations = [{','"frames": ['+', '.join('{"duration": 1.0, "texture": SubResource("Frame_%d")}'%i for i in range(a.count))+'],',f'"loop": {str(loop).lower()},',f'"name": &"{a.motion}",',f'"speed": {fps}.0','}]']
tres.write_text('\n'.join(lines)+'\n')
row={'type':'animation-candidate','character_id':a.character,'visual_state_id':a.motion,'path':png.relative_to(ROOT).as_posix(),'sprite_frames_path':'res://'+tres.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(png.read_bytes()).hexdigest(),'frame_count':a.count,'atlas_columns':16,'cell_size':128,'frame_durations':[1.0]*a.count,'fps':fps,'loop':loop,'presentation_scale':reference_scale/scale,'foot_pivot_y':124+padding_shift_y,'source_path':source.relative_to(ROOT).as_posix(),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'conversion':{'explicit_pose_offsets':offsets,'ground_anchor_offsets':ground_anchor_offsets,'reference_scale':reference_scale,'padding_shift_y':padding_shift_y,'uniform_scale':scale,'translation':[tx,ty],'ground_reference_start':a.ground_start,'frame_bounds':out_bounds,'source_selection':selection,'unassigned_small_regions':unused,'method':'connected original figure regions; uniform scale and cell-relative translation; no pose repainting'}}
if a.motion=='run':row['run_stride_px']=96
elif a.motion=='jump':row['jump_frame_ranges']={'ascent':[0,6],'apex':[6,10],'descent':[10,16],'landing':[16,24]}
else:row['phase_frame_ranges']=([[0,4],[4,8],[8,16]] if a.count==16 else ([[0,6],[6,10],[10,24]] if a.count==24 else [[0,8],[8,12],[12,32]]))
if a.phase_counts:
 counts=list(map(int,a.phase_counts.split(',')));assert len(counts)==3 and min(counts)>0 and sum(counts)==a.count
 row['phase_frame_ranges']=[[0,counts[0]],[counts[0],sum(counts[:2])],[sum(counts[:2]),a.count]]
(folder/f'{a.motion}_{a.version}.json').write_text(json.dumps(row,ensure_ascii=False,indent=2)+'\n');print(png.relative_to(ROOT))
