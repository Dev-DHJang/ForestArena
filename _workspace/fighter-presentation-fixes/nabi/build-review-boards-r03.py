"""Comparison layout only: do not repaint or change approved source art."""
from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
import json
BASE=Path(__file__).resolve().parent;ROOT=BASE.parents[2]
manifest=json.loads((ROOT/'assets/character/manifest.json').read_text())
entries={(e.get('character_id'),e.get('visual_state_id')):e for e in manifest['assets'] if e.get('type')=='animation-runtime'}
candidates={e['visual_state_id']:e for e in json.loads((BASE/'registration-catalog-r03.json').read_text())['assets']}
font=ImageFont.truetype('/System/Library/Fonts/Menlo.ttc',16)
scenes=[('idle',0),('run',0),('run',4),('run',8),('jump',0),('jump',6),('jump',16),('jump',23)]
out=Image.new('RGBA',(1600,2000),(49,54,62,255));draw=ImageDraw.Draw(out)
for k,(motion,idx) in enumerate(scenes):
 bx=k%2*800;by=k//2*500;baseline=by+430
 draw.text((bx+10,by+8),f'{motion} F{idx+1}; Ja unchanged / Nabi candidate',font=font,fill='white');draw.line((bx+4,baseline,bx+795,baseline),fill=(140,170,155),width=2)
 for i,e in enumerate([entries['ja-hyun',motion],candidates[motion]]):
  src=Image.open(ROOT/e['path']).convert('RGBA');cols=src.width//128;im=src.crop((idx%cols*128,idx//cols*128,idx%cols*128+128,idx//cols*128+128));s=e.get('presentation_scale',1);mag=3.6;im=im.resize((round(128*s*mag),round(128*s*mag)),Image.Resampling.NEAREST)
  x=bx+[200,600][i]-im.width//2;y=baseline-round(e.get('foot_pivot_y',128)*s*mag);out.alpha_composite(im,(x,y));draw.text((bx+20+i*400,by+452),f'{e["character_id"]} scale={s:.4f}',font=font,fill='white')
out.convert('RGB').save(BASE/'representative-body-fit-r03.jpg',quality=96)
for motion in ['run','jump']:
 e=candidates[motion];src=Image.open(ROOT/e['path']).convert('RGBA');count=e['frame_count'];cols=4;rows=(count+cols-1)//cols;board=Image.new('RGBA',(4*300,rows*330),(85,90,98,255));d=ImageDraw.Draw(board)
 for idx in range(count):
  oldcols=src.width//128;im=src.crop((idx%oldcols*128,idx//oldcols*128,idx%oldcols*128+128,idx//oldcols*128+128)).resize((256,256),Image.Resampling.NEAREST);board.alpha_composite(im,(idx%4*300+22,idx//4*330+35));d.text((idx%4*300+10,idx//4*330+8),f'{motion} F{idx+1}',font=font,fill='white')
 board.convert('RGB').save(BASE/f'{motion}-all-frames-r03.jpg',quality=96)
