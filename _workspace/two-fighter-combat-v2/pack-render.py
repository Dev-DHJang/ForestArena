from pathlib import Path
import json,subprocess,hashlib
from PIL import Image
ROOT=Path(__file__).resolve().parents[2];base=Path(__file__).resolve().parent/'review/rendered'
report=json.loads((base/'render-report.json').read_text())
for item in report['motions']:
 folder=base/(item['character_id']+'__'+item['motion'])
 for codec,suffix in [('libx264','.mp4'),('ffv1','.mkv')]:
  cmd=['ffmpeg','-v','error','-y','-framerate','60','-i',str(folder/'frame-%03d.png')]
  if suffix=='.mp4':cmd+=['-vf','scale=960:540','-crf','18','-pix_fmt','yuv420p']
  subprocess.run(cmd+['-c:v',codec,str(folder.with_suffix(suffix))],check=True)
 n=item['frames'];p,a,r=item['phase_ticks'];selected=[0,p-1,p,p+a//2,p+a-1,n-1]
 board=Image.new('RGB',(960*2,540*3))
 for k,i in enumerate(selected):
  im=Image.open(folder/('frame-%03d.png'%i)).convert('RGB');im.thumbnail((960,540));board.paste(im,((k%2)*960,(k//2)*540))
 board.save(folder.with_suffix('.jpg'),quality=88)
 for im in folder.glob('frame-*.png'):im.unlink()
 folder.rmdir()
files=[p for p in base.iterdir() if p.suffix in ['.mp4','.mkv','.jpg']]
report['render_files']={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
report['sources']={str(p):hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in [Path('scripts/local_fighter_presentation.gd'),Path('scripts/fighter_attack_effects.gd'),Path('_workspace/two-fighter-combat-v2/render-candidates.gd'),Path('_workspace/two-fighter-combat-v2/candidate-catalog.json')]}
(base/'render-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
html='<!doctype html><meta charset="utf-8"><title>실제 표현 코드와 효과 검토</title><style>body{background:#172128;color:white;font:18px system-ui}video{width:min(960px,100%)} article{margin-bottom:36px}button{font:18px system-ui}</style><h1>승인 전 실제 표현 코드·효과</h1><p>합성 상태를 실제 공격 시간으로 재생합니다. 실제 경기 이동·피격 검사는 별도입니다. 왼쪽 시안 / 오른쪽 승인 idle, 줌1.50.</p><button onclick="document.querySelectorAll(\'video\').forEach(v=>v.playbackRate=1)">정상속도 1×</button> <button onclick="document.querySelectorAll(\'video\').forEach(v=>v.playbackRate=.25)">느린속도 .25×</button>'
for item in report['motions']:
 name=item['character_id']+'__'+item['motion'];html+='<article><h2>'+name+'</h2><video controls loop muted autoplay src="'+name+'.mp4"></video><p><a href="'+name+'.jpg">6장 비교판</a></p></article>'
(base/'index.html').write_text(html)
print('packed',len(report['motions']),'actual presentation videos and lossless sources')
