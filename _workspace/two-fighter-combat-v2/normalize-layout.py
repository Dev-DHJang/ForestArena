"""Repack generated figures without cutting cross-cell limbs or changing poses.
Uses the existing tested region splitter. Only scale and translation follow.
"""
from pathlib import Path
import sys,json,hashlib
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/forest_arena'))
from motion_sheet_regions import split_regions
BASE=Path(__file__).resolve().parent
plans=[
 ('ja-hyun','attack_light_combo_04','light_kick_r01_source.png',.34,124,None,'r01n02',1.0),
 ('ja-hyun','attack_air_heavy','air_heavy_r01_source.png',.30,90,[269,257,285,283,210,210,200,200,180,180,247,246,253,240,252,236],'r01n02',1.0),
 ('ja-hyun','special_scarf_sweep','special_scarf_sweep_r01_source.png',.265,124,None,'r01n02',1.45),
 ('nabi','attack_light_up','up_claw_r02_source.png',.34,124,None,'r02n02',1.0),
 ('nabi','attack_air_heavy','air_heavy_r03_source.png',.34,124,None,'r04n02',1.0),
]
records=[]
for cid,motion,source,scale,foot,anchors,version,display in plans:
 base=BASE/'candidates'/cid
 frames=split_regions(Image.open(base/source).convert('RGBA'))
 assert len(frames)==16
 if cid=='nabi' and motion=='attack_air_heavy':
  key=Image.open(base/'air_heavy_r04_key_source.png').convert('RGBA')
  key=key.crop(key.getbbox())
  ref_height=frames[6].height
  key=key.resize((round(key.width*ref_height/key.height),ref_height),Image.Resampling.LANCZOS)
  # Generated once from the actual foreground-arm key; short active hold.
  for index in [7,8,9]: frames[index]=key.copy()
 sheet=Image.new('RGBA',(2048,128))
 for i,frame in enumerate(frames):
  anchor=anchors[i] if anchors else frame.height
  pose=frame.resize((round(frame.width*scale),round(frame.height*scale)),Image.Resampling.LANCZOS)
  x=(128-pose.width)//2;y=round(foot-anchor*scale)
  assert x>=2 and y>=2 and x+pose.width<=126 and y+pose.height<=126,(cid,motion,i,x,y,pose.size)
  sheet.alpha_composite(pose,(i*128+x,y))
 target=base/(motion+'_16f_'+version+'.png');sheet.save(target)
 tres=base/(motion+'_'+version+'.tres')
 lines=['[gd_resource type="SpriteFrames" load_steps=18 format=3]','',f'[ext_resource type="Texture2D" path="res://{target.relative_to(ROOT).as_posix()}" id="1"]']
 for i in range(16):lines+=['',f'[sub_resource type="AtlasTexture" id="Frame_{i}"]','atlas = ExtResource("1")',f'region = Rect2({i*128}, 0, 128, 128)']
 lines+=['','[resource]','animations = [{','"frames": ['+', '.join('{"duration": 1.0, "texture": SubResource("Frame_%d")}'%i for i in range(16))+'],','"loop": false,',f'"name": &"{motion}",','"speed": 12.0','}]']
 tres.write_text('\n'.join(lines)+'\n')
 records.append({'character_id':cid,'motion':motion,'source':str((base/source).relative_to(ROOT)),'source_sha256':hashlib.sha256((base/source).read_bytes()).hexdigest(),'path':str(target.relative_to(ROOT)),'sprite_frames_path':'res://'+str(tres.relative_to(ROOT)),'scale':scale,'foot_pivot_y':foot,'anchors':anchors,'presentation_scale':display})
(BASE/'candidate-layout.json').write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n')
print('normalized',len(records),'motions; full alpha figure bounds fit every 128 cell')
