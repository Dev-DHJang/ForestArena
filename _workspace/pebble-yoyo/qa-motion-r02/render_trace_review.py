"""Read-only art input; diagnostic trace reconstruction, never runtime assets."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json, subprocess, hashlib
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
TRACE=ROOT/'_workspace/pebble-yoyo/game-timeline.json'
data=json.loads(TRACE.read_text())
font=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',18)
small=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',14)
body=Image.open(ROOT/'forest_arena/assets/common/accessory/pebble_yoyo_combat.png').convert('RGBA')
for motion in data['motions']:
 p=ROOT/f"_workspace/pebble-yoyo/motions/{motion['character']}/{motion['mode']}/r02"
 meta=json.loads((p/'candidate.json').read_text())
 assert motion['metadata']['frame_anchors']==meta['frame_anchors'], 'trace must reflect latest anchors'
 assert motion['metadata']['sheet_sha256']==hashlib.sha256((p/'sheet-128.png').read_bytes()).hexdigest()
 motion['sheet']=Image.open(p/'sheet-128.png').convert('RGBA')
 motion['latest']=meta

lookup={}
for m in data['motions']:
 lookup[(m['character'],m['motion_id'])]=(m['sheet'],m['latest'])
manifest=json.loads((ROOT/'assets/character/manifest.json').read_text())
for m in manifest['assets']:
 if m.get('type')=='animation-runtime' and m.get('character_id') in ['ja-hyun','nabi'] and m.get('visual_state_id') in ['idle','jump']:
  path=ROOT/m['path'];lookup[(m['character_id'],m['visual_state_id'])]=(Image.open(path).convert('RGBA'),{'columns':m.get('atlas_columns',Image.open(path).width//128)})

def render(tick,mirror=False):
 canvas=Image.new('RGB',(1280,720),'#122831');draw=ImageDraw.Draw(canvas)
 draw.text((16,10),'RECONSTRUCTED ACTUAL-CODE TRACE / camera follows actor / candidate only',font=font,fill='#ffe2a3')
 for n,m in enumerate(data['motions']):
  ox=(n%2)*640;oy=(n//2)*344+32
  r=m['frames'][min(tick,len(m['frames'])-1)]
  panel=Image.new('RGBA',(640,340),'#23464f');pd=ImageDraw.Draw(panel)
  pd.text((15,8),m['character']+' / '+m['mode']+' / '+r['phase']+' / tick '+str(r['tick'])+' / frame '+str(r['frame']),font=small,fill='white')
  scale=r['scale'];cam=1.5;cx=190;cy=255
  if m['mode']=='ground':pd.line((20,cy+14*cam,600,cy+14*cam),fill='#82a998',width=2)
  tx=r['rendered_tip_x'];ty=r['rendered_tip_y'];phase=r['phase']
  active=phase!='idle'
  if active:pd.line((cx+r['hand_x']*cam,cy+r['hand_y']*cam,cx+tx*cam,cy+ty*cam),fill='#fff0ca',width=3)
  i=r['frame'];sheet,layout=lookup[(m['character'],r['motion'])];cols=layout['columns'];f=sheet.crop(((i%cols)*128,(i//cols)*128,(i%cols+1)*128,(i//cols+1)*128))
  size=round(128*scale*cam);f=f.resize((size,size),Image.Resampling.LANCZOS)
  x=round(cx+(r['sprite_x']-64*scale)*cam);y=round(cy+(r['sprite_y']-64*scale)*cam);panel.alpha_composite(f,(x,y))
  if active:
   yo=body.resize((42,42),Image.Resampling.LANCZOS).rotate(-r['tick']*.5*180/3.141592653589793,resample=Image.Resampling.BICUBIC)
   panel.alpha_composite(yo,(round(cx+tx*cam-21),round(cy+ty*cam-21)))
  if mirror:panel=panel.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
  canvas.paste(panel.convert('RGB'),(ox,oy))
 return canvas

# Grid samples for every actual trace tick: inspect all real frames and hand/string alignment.
for mirror in [False,True]:
 for tick in range(49):
  if tick in [0,5,6,12,18,23,24,30,36,41,42,46,48]:render(tick,mirror).save(HERE/(f'trace-{tick:02d}'+('-flip.png' if mirror else '.png')))
for speed,name,cycles in [(1,'normal',6),(.25,'slow',3)]:
 for mirror in [False,True]:
  dest=HERE/(f'trace-{name}'+('-flip.mp4' if mirror else '.mp4'))
  cmd=['ffmpeg','-y','-loglevel','error','-f','rawvideo','-pix_fmt','rgb24','-s','1280x720','-r','60','-i','-','-an','-c:v','libx264','-preset','ultrafast','-crf','20','-pix_fmt','yuv420p',str(dest)]
  process=subprocess.Popen(cmd,stdin=subprocess.PIPE)
  span=72
  for video_tick in range(round(span*cycles/speed)):
   tick=min(int(video_tick*speed)%span,48)
   process.stdin.write(render(tick,mirror).tobytes())
  process.stdin.close();assert process.wait()==0
report={'kind':'offline diagnostic reconstruction from actual combat/presentation trace; not game-screen capture','trace_sha256':hashlib.sha256(TRACE.read_bytes()).hexdigest(),'motions':[{k:m[k] for k in ['character','mode','motion_id']} for m in data['motions']]}
(HERE/'reconstruction.json').write_text(json.dumps(report,indent=2)+'\n')
