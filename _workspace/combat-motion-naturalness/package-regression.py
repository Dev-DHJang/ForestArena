"""실제 입력으로 촬영한 기존14동작의 20FPS 재생과 표본 비교판."""
from pathlib import Path
import json,subprocess
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[2]
source=ROOT/'build/combat-naturalness/runtime-regression-r03'
out=ROOT/'_workspace/combat-motion-naturalness/regression';out.mkdir(exist_ok=True)
report=json.loads((source/'state-report.json').read_text())
summary={k:v for k,v in report.items() if k!='scenarios'}
summary['scenarios']=[]
for clip in report['scenarios']:
 name=clip['name'];folder=source/name;frames=sorted(folder.glob('frame-*.png'))
 board=Image.new('RGB',(600*5,302*((len(frames)+4)//5)),'#14281f');draw=ImageDraw.Draw(board)
 for i,p in enumerate(frames):
  frame=int(p.stem.split('-')[-1]);x=i%5*600;y=i//5*302
  board.paste(Image.open(p).crop((420,140,1020,420)).convert('RGB'),(x,y+22))
  state=clip['states'][frame];label='/'.join(f"{p['shown_motion']}:{p['frame']+1}" for p in state['drawn'])
  draw.text((x+4,y+4),f'{frame:03d} {label}',fill='white')
 board.save(out/f'{name}.jpg',quality=89)
 listing=out/f'{name}.ffconcat';listing.write_text('ffconcat version 1.0\n'+''.join(f"file '{p}'\nduration 0.05\n" for p in frames))
 subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-safe','0','-i',str(listing),'-c:v','libx264','-crf','21','-pix_fmt','yuv420p','-movflags','+faststart',str(out/f'{name}.mp4')],check=True)
 listing.unlink()
 summary['scenarios'].append({k:v for k,v in clip.items() if k!='states'})
(out/'state-summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
(out/'index.html').write_text('<!doctype html><meta charset="utf-8"><title>기존 공격 회귀 기록</title><style>body{background:#14281f;color:white;font:16px system-ui;margin:30px}video{width:640px;max-width:100%}a{color:#cde9ba}</style><h1>실제 입력·물리·적중 회귀</h1><p>macOS Godot. 각3틱 표본(20FPS), 모션 원본 유지. 물리 Android 결과가 아닙니다.</p>'+''.join(f'<h2>{c["name"]}</h2><video controls muted src="{c["name"]}.mp4"></video><p><a href="{c["name"]}.jpg">전체 표본 프레임</a></p>' for c in report['scenarios']))
