"""원화 좌표 sidecar를 진단판에 표시한다. 원화/후보/production 쓰기 없음."""
from pathlib import Path
import hashlib,json,math,importlib.util
from PIL import Image,ImageDraw
base=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('motion_split',base.parents[1]/'split-figures.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
checks=[]
for sidecar in sorted(base.glob('*.anchors.json')):
 data=json.loads(sidecar.read_text());source=base/data['source_png'];assert hashlib.sha256(source.read_bytes()).hexdigest()==data['source_sha256'],source
 im=Image.open(source).convert('RGBA');figures,_=module.split_figures(im,4,4);pixels=im.load();out=base/'anchor-diagnostics';name=source.stem
 for batch in range(4):
  board=Image.new('RGB',(960,880),'#252831');draw=ImageDraw.Draw(board)
  for k in range(4):
   f=batch*4+k;entry=data['frames'][f];crop,bounds=figures[f];ox,oy=entry['cell']['origin'];sc=min(420/crop.width,365/crop.height);bx=k%2*480+25;by=k//2*440+45
   shown=crop.resize((round(crop.width*sc),round(crop.height*sc)));board.paste(shown,(bx,by),shown);draw.text((bx,by-27),f'{name} F{f} / motion F{entry["motion_frame_index"]} {entry["phase"]}',fill='white')
   for key,point in entry['anchors'].items():
    x,y=point;gx,gy=x+ox,y+oy;ax,ay=round(gx),round(gy);alpha=pixels[ax,ay][3] if 0<=ax<im.width and 0<=ay<im.height else 0
    nearest=999
    for dy in range(-15,16):
     for dx in range(-15,16):
      xx,yy=ax+dx,ay+dy
      if 0<=xx<im.width and 0<=yy<im.height and pixels[xx,yy][3]>=32:nearest=min(nearest,math.hypot(dx,dy))
    checks.append(dict(source=source.name,frame=f,key=key,cell_point=point,source_point=[gx,gy],alpha=alpha,nearest_alpha_distance=nearest))
    xx=bx+(gx-bounds[0])*sc;yy=by+(gy-bounds[1])*sc;color='#50e8ff' if key=='claw_hand' else '#ffe050';draw.ellipse((xx-4,yy-4,xx+4,yy+4),outline=color,width=2);draw.line((xx-8,yy,xx+8,yy),fill=color);draw.line((xx,yy-8,xx,yy+8),fill=color)
    draw.text((xx+7,yy+3),f'{"H" if key=="claw_hand" else "T"} {x:g},{y:g}',fill=color)
   if 'claw_tip' not in entry['anchors']:draw.text((bx,by+375),'T omitted: folded/occluded central metal claw',fill='#c8c8ce')
  board.save(out/f'{name}-marked-f{batch*4:02d}-{batch*4+3:02d}.png')
(base/'anchor-diagnostics'/'anchor-location-check.json').write_text(json.dumps({'kind':'read-only pixel proximity diagnostics, not anatomy or VFX pass','points':checks},ensure_ascii=False,indent=2)+'\n')
for c in checks:
 if c['nearest_alpha_distance']>4:print(c)
print('marked',len(checks),'points; source PNG hashes unchanged')
