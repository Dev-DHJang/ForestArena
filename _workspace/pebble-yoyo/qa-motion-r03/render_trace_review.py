"""실제 표시 코드 기록을 같은 좌표에 재현. 게임/기기 화면 캡처가 아니다."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,hashlib,subprocess,math
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent;TRACE=ROOT/'_workspace/pebble-yoyo/game-timeline-r03.json';data=json.loads(TRACE.read_text())
font=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',18);small=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',14)
body=Image.open(ROOT/'forest_arena/assets/common/accessory/pebble_yoyo_combat.png').convert('RGBA');lookup={}
for m in data['motions']:
 p=ROOT/f"_workspace/pebble-yoyo/motions/{m['character']}/{m['mode']}/r03";meta=json.loads((p/'candidate.json').read_text());assert meta['frame_anchors']==m['metadata']['frame_anchors'];assert meta['sheet_sha256']==m['metadata']['sheet_sha256'];assert meta['sheet_sha256']==hashlib.sha256((p/'sheet-128.png').read_bytes()).hexdigest();lookup[(m['character'],m['motion_id'])]=(Image.open(p/'sheet-128.png').convert('RGBA'),meta['columns'])
for a in json.loads((ROOT/'assets/character/manifest.json').read_text())['assets']:
 if a.get('type')=='animation-runtime' and a.get('character_id') in ['ja-hyun','nabi'] and a.get('visual_state_id') in ['idle','jump']:
  lookup[(a['character_id'],a['visual_state_id'])]=(Image.open(ROOT/a['path']).convert('RGBA'),a.get('atlas_columns',16))
def render(tick,facing=1):
 canvas=Image.new('RGB',(1280,720),'#122831');draw=ImageDraw.Draw(canvas);draw.text((16,10),'ACTUAL-CODE TRACE RECONSTRUCTION / BEFORE > CAST > AFTER / not device capture',font=font,fill='#ffe2a3')
 selected=[m for m in data['motions'] if m['facing']==facing]
 for n,m in enumerate(selected):
  r=m['frames'][max(0,min(tick+27,len(m['frames'])-1))];panel=Image.new('RGBA',(640,340),'#23464f');pd=ImageDraw.Draw(panel);pd.text((15,8),f"{m['character']} / {m['mode']} / {r['phase']} / tick {r['tick']} / {r['motion']}:{r['frame']}",font=small,fill='white')
  scale=r['scale'];cam=2.;cx=180 if facing==1 else 460;cy=277
  pd.line((cx,45,cx,320),fill='#395d63',width=1)
  if m['mode']=='ground':pd.line((20,cy+14*cam,620,cy+14*cam),fill='#82a998',width=2)
  if r['phase']!='idle':pd.line((cx+r['hand_x']*cam,cy+r['hand_y']*cam,cx+r['rendered_tip_x']*cam,cy+r['rendered_tip_y']*cam),fill='#fff0ca',width=3)
  sheet,cols=lookup[(m['character'],r['motion'])];i=r['frame'];f=sheet.crop((i%cols*128,i//cols*128,i%cols*128+128,i//cols*128+128));f=f.transpose(Image.Transpose.FLIP_LEFT_RIGHT) if r['sprite_flip_h'] else f
  size=round(128*scale*cam);f=f.resize((size,size),Image.Resampling.LANCZOS);panel.alpha_composite(f,(round(cx+(r['sprite_x']-64*scale)*cam),round(cy+(r['sprite_y']-64*scale)*cam)))
  if r['phase']!='idle':
   yo=body.resize((56,56),Image.Resampling.LANCZOS).rotate(-r['display_rotation']*180/math.pi,resample=Image.Resampling.BICUBIC,expand=False);panel.alpha_composite(yo,(round(cx+r['rendered_tip_x']*cam-28),round(cy+r['rendered_tip_y']*cam-28)))
  canvas.paste(panel.convert('RGB'),(n%2*640,n//2*344+32))
 return canvas
samples=[-27,-20,-12,-6,-1,0,1,2,4,5,6,12,18,23,24,30,36,41,42,46,47,48,54,60,71]
for facing in [1,-1]:
 for tick in samples:render(tick,facing).save(HERE/f'trace-{tick:+03d}{"-flip" if facing<0 else ""}.png')
# Read-only images/video; rotations and left-facing positions come from actual code, not mirrored panels.
for speed,name,cycles in [(1,'normal',4),(.25,'slow',2)]:
 for facing in [1,-1]:
  dest=HERE/f'trace-{name}{"-flip" if facing<0 else ""}.mp4';cmd=['ffmpeg','-y','-loglevel','error','-f','rawvideo','-pix_fmt','rgb24','-s','1280x720','-r','60','-i','-','-an','-c:v','libx264','-preset','veryfast','-crf','23','-pix_fmt','yuv420p',str(dest)];process=subprocess.Popen(cmd,stdin=subprocess.PIPE)
  for v in range(round(120*cycles/speed)):
   tick=min(int(v*speed)%120,98)-27;process.stdin.write(render(tick,facing).tobytes())
  process.stdin.close();assert process.wait()==0
(HERE/'reconstruction.json').write_text(json.dumps({'kind':'offline actual-code trace reconstruction, not game/device screenshot','trace_sha256':hashlib.sha256(TRACE.read_bytes()).hexdigest(),'mirror_source':'independent actual fighter.facing=-1 trace, including display_rotation and sprite_flip_h; texture is never panel-mirrored','source':str(TRACE.relative_to(ROOT))},indent=2)+'\n')
print('Rendered4 videos, normal/slow, real left/right-facing traces.')
