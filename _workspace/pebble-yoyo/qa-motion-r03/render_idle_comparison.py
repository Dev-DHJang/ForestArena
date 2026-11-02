from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,subprocess,hashlib
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent;meta=json.loads((ROOT/'_workspace/pebble-yoyo/motions/nabi/idle/r03/candidate.json').read_text());sheet=Image.open(ROOT/meta['path']).convert('RGBA');assert hashlib.sha256((ROOT/meta['path']).read_bytes()).hexdigest()==meta['sha256'];font=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',22)
def render(index):
 frame=index%16;out=Image.new('RGB',(1280,480),'#122831');dr=ImageDraw.Draw(out);dr.text((20,12),'NABI IDLE / SAME APPROVED PIXELS + TIMING / ROOT DRAWING CORRECTION ONLY',font=font,fill='#ffe2a3')
 for n in range(2):
  p=Image.new('RGBA',(640,420),'#23464f');d=ImageDraw.Draw(p);d.text((20,10),('BEFORE: drifting cells' if n==0 else 'CANDIDATE: stable two-shoe midpoint')+f' / frame{frame}',font=font,fill='white');cam=3.;scale=meta['presentation_scale'];cx=290;cy=355;root=meta['frame_anchors'][frame]['body_root'];offset=(64-root[0])*scale if n else 0.;target=(meta['conversion']['target_midpoint_pixels']-64)*scale
  d.line((0,cy+14*cam,640,cy+14*cam),fill='#82a998',width=2);d.line((cx+target*cam,45,cx+target*cam,410),fill='#ffd57b',width=2)
  f=sheet.crop((frame*128,0,frame*128+128,128));size=round(128*scale*cam);f=f.resize((size,size),Image.Resampling.LANCZOS);p.alpha_composite(f,(round(cx+(offset-64*scale)*cam),round(cy+(14-(meta['foot_pivot_y']-64)*scale-64*scale)*cam)));out.paste(p.convert('RGB'),(n*640,60))
 return out
for speed,name in [(1.,'normal'),(.25,'slow')]:
 dest=HERE/f'nabi-idle-before-after-{name}.mp4';process=subprocess.Popen(['ffmpeg','-y','-loglevel','error','-f','rawvideo','-pix_fmt','rgb24','-s','1280x480','-r','60','-i','-','-an','-c:v','libx264','-preset','veryfast','-crf','23','-pix_fmt','yuv420p',str(dest)],stdin=subprocess.PIPE)
 for t in range(round(240/speed)):process.stdin.write(render(int(t*speed*8/60)).tobytes())
 process.stdin.close();assert process.wait()==0
for i in [0,3,7,11,15]:render(i).save(HERE/f'nabi-idle-before-after-frame{i:02}.png')
print('NABI_IDLE_COMPARISON: generated exactly2 cycles at8fps, same PNG bytes and display scale.')
