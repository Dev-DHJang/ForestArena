from pathlib import Path
import json,shutil,subprocess
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[2]
out=ROOT/'_workspace/combat-motion-naturalness/review-r05/special';out.mkdir(parents=True,exist_ok=True)
for variant,folder in [('candidate','special-live-r05'),('small-flipped','special-mirrored-small-r05')]:
 source=ROOT/'build/combat-naturalness'/folder
 if not (source/'state-report.json').exists():continue
 shutil.copy2(source/'state-report.json',out/f'{variant}-state-report.json')
 frames=source/'ja-hyun__special'
 subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-framerate','60','-i',str(frames/'frame-%03d.png'),'-c:v','libx264','-crf','19','-pix_fmt','yuv420p','-movflags','+faststart',str(out/f'{variant}.mp4')],check=True)
 crop=(540,200,820,390) if variant=='candidate' else (530,290,750,410)
 width,height=crop[2]-crop[0],crop[3]-crop[1]
 for page in range(3):
  board=Image.new('RGB',(width*5,(height+22)*8),'#14281f');draw=ImageDraw.Draw(board)
  for i in range(40):
   frame=page*40+i;x=i%5*width;y=i//5*(height+22)
   board.paste(Image.open(frames/f'frame-{frame:03d}.png').crop(crop).convert('RGB'),(x,y+22));draw.text((x+3,y+4),f'tick {frame}',fill='white')
  board.save(out/f'{variant}-sequence-{page+1}.jpg',quality=94)
before=ROOT/'build/combat-naturalness/runtime-regression-r03/ja-hyun__special'
after=ROOT/'build/combat-naturalness/special-live-r05/ja-hyun__special'
board=Image.new('RGB',(300*4,230*2),'#14281f');draw=ImageDraw.Draw(board)
for row,folder in enumerate([before,after]):
 for col,frame in enumerate([9,12,105,108]):
  x=col*300;y=row*230
  board.paste(Image.open(folder/f'frame-{frame:03d}.png').crop((540,180,840,390)).convert('RGB'),(x,y+20));draw.text((x+4,y+3),f'{"before" if row==0 else "candidate"} tick {frame}',fill='white')
board.save(out/'entry-exit-before-after.jpg',quality=95)
shutil.copy2(ROOT/'_workspace/combat-motion-naturalness/regression/ja-hyun__special.mp4',out/'before.mp4')
(out/'index.html').write_text('''<!doctype html><meta charset="utf-8"><title>자현 특수기 표시 크기</title><style>body{background:#14281f;color:#f3fff1;font:16px/1.6 system-ui;padding:24px}video{width:46%;margin:1%}button{padding:14px;font:inherit}img{max-width:100%}</style><h1>자현 특수기 · 원화 그대로 전체 배율 +18%</h1><p>준비·휘두르기·회수 시간과 판정은 유지됩니다. 승인 전 후보입니다.</p><button onclick="playAll(1)">1배속 처음부터</button><button onclick="playAll(.5)">0.5배속 처음부터</button><span id="status">준비</span><h2>기존 / 후보</h2><video controls muted playsinline preload="auto" src="before.mp4"></video><video id="candidate" controls muted playsinline preload="auto" src="candidate.mp4"></video><h2>작은 좌우반전 화면</h2><video controls muted playsinline preload="auto" src="small-flipped.mp4"></video><h2>진입·복귀 같은 시점</h2><img src="entry-exit-before-after.jpg"><script>function playAll(rate){document.querySelectorAll('video').forEach(v=>{if(v.readyState>=2){v.pause();v.currentTime=0;v.playbackRate=rate;v.play()}});document.getElementById('status').textContent=rate+'배속 재생중'}document.getElementById('candidate').addEventListener('ended',()=>{document.getElementById('status').textContent=document.getElementById('candidate').playbackRate+'배속 완료'})</script>''')
