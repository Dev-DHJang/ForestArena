from pathlib import Path
import json,subprocess,hashlib
from PIL import Image
ROOT=Path(__file__).resolve().parents[2];base=Path(__file__).resolve().parent/'review/live-special'
report=json.loads((base/'state-report.json').read_text())
html='<!doctype html><meta charset="utf-8"><title>나비 특수 실제 경기</title><style>body{background:#172128;color:white;font:18px system-ui}video{width:min(960px,100%)}</style><h1>나비 특수 실제 경기</h1><p>고정60Hz 실제 입력·이동·피격·표현. 성공 / 빗나감 / 벽 차단. Android 실기기 검사가 아닙니다.</p><button onclick="document.querySelectorAll(\'video\').forEach(v=>v.playbackRate=1)">1×</button><button onclick="document.querySelectorAll(\'video\').forEach(v=>v.playbackRate=.25)">.25×</button>'
for item in report['scenarios']:
 name=item['scenario'];folder=base/name
 for codec,suffix in [('libx264','.mp4'),('ffv1','.mkv')]:
  cmd=['ffmpeg','-v','error','-y','-framerate','60','-i',str(folder/'frame-%03d.png')]
  if suffix=='.mp4':cmd+=['-vf','scale=960:540','-crf','18','-pix_fmt','yuv420p']
  subprocess.run(cmd+['-c:v',codec,str(folder.with_suffix(suffix))],check=True)
 board=Image.new('RGB',(1920,1620))
 for k,i in enumerate([0,9,14,20,28,45]):
  im=Image.open(folder/('frame-%03d.png'%i)).convert('RGB');im.thumbnail((960,540));board.paste(im,((k%2)*960,(k//2)*540))
 board.save(folder.with_suffix('.jpg'),quality=88)
 for im in folder.glob('frame-*.png'):im.unlink()
 folder.rmdir()
 html+='<h2>'+name+'</h2><video controls loop muted autoplay src="'+name+'.mp4"></video><p><a href="'+name+'.jpg">6장 비교판</a></p>'
(base/'index.html').write_text(html)
report['sources']={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in ['scripts/fighter_controller.gd','scripts/local_fighter_presentation.gd','scripts/fighter_attack_effects.gd','assets/combat/movesets/two_fighter_nabi_moveset.tres','_workspace/two-fighter-combat-v2/render-live-special.gd']}
report['render_files']={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in base.iterdir() if p.suffix in ['.mp4','.mkv','.jpg']}
(base/'state-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print('packed 3 actual match scenarios')
