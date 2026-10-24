from pathlib import Path
from PIL import Image,ImageDraw
import json,subprocess,hashlib
R=Path(__file__).resolve().parents[4];O=Path(__file__).resolve().parent
receipts=[]
for variant in ['normal','mirror-small']:
 src=R/('_workspace/ja-scarf-barrage-v1/qa/live-'+variant+'-r04'); report=json.loads((src/'state-report.json').read_text()); archive=json.loads((src/'raw-archive.json').read_text()); clip=archive['clips'][0]; states=report['scenarios'][0]['states']; movie=src/clip['archive']; p=subprocess.Popen(['ffmpeg','-v','error','-i',str(movie),'-f','rawvideo','-pix_fmt','rgba','-'],stdout=subprocess.PIPE);all_hash=[]
 for f in range(120):
  raw=p.stdout.read(1280*720*4); assert len(raw)==1280*720*4
  digest=hashlib.md5(raw).hexdigest();assert digest==clip['rgba_md5'][f];all_hash.append(digest);im=Image.frombytes('RGBA',(1280,720),raw)
  if f%20==0: board=Image.new('RGB',(1280,1025),'#16252b');draw=ImageDraw.Draw(board)
  x=f%4*320;y=(f%20)//4*205;draw.text((x+4,y+3),str(f)+' / '+states[f]['drawn'][0]['shown_motion']+' F'+str(states[f]['drawn'][0]['frame']+1),fill='white');board.paste(im.resize((320,180)),(x,y+23))
  if f%20==19: board.save(O/(variant+'-allticks-'+str(f//20+1)+'.jpg'),quality=95)
  if f in [12,23,24,29,34,39,44,49,54,59,64,69,74,79,83,84,89,95,101,107,108,119]:
   crop=im.crop((270,40,1050,410)) if variant=='normal' else im.crop((390,180,900,410));crop.thumbnail((780,370));canvas=Image.new('RGB',(780,400),'#16252b');ImageDraw.Draw(canvas).text((4,3),variant+' tick '+str(f)+' '+states[f]['drawn'][0]['shown_motion']+' F'+str(states[f]['drawn'][0]['frame']+1),fill='white');canvas.paste(crop,(0,25));canvas.save(O/(variant+'-tick-'+str(f)+'.jpg'),quality=96)
 assert p.stdout.read()==b'';assert p.wait()==0
 changes=[];prev=None
 for st in states:
  drawst=st['drawn'][0];fid=(drawst['shown_motion'],drawst['frame'])
  if fid!=prev:changes.append({'capture_frame':st['frame'],'motion':fid[0],'art_frame':fid[1]+1,'fighter_state':st['match']['fighters'][0]['state']});prev=fid
 mismatched=[k for k,v in report['sources'].items() if not (R/k).exists() or hashlib.sha256((R/k).read_bytes()).hexdigest()!=v]
 receipts.append({'variant':variant,'capture_report':str((src/'state-report.json').relative_to(R)),'capture_report_sha256':hashlib.sha256((src/'state-report.json').read_bytes()).hexdigest(),'archive_sha256':hashlib.sha256(movie.read_bytes()).hexdigest(),'all120_rgba_md5_match':True,'current_source_mismatches':mismatched,'shown_changes':changes})
(O/'independent-capture-check.json').write_text(json.dumps(receipts,ensure_ascii=False,indent=2)+'\n')
(O/'index.html').write_text('''<!doctype html><meta charset="utf-8"><title>자현 특수 독립 재생 검토</title><style>body{background:#16252b;color:white;font:16px system-ui}video{width:100%}article{max-width:960px;margin:24px auto}</style><h1>실제60Hz 전투120틱 재생: 정상 및0.25속도</h1>'''+''.join('<article><h2>'+v+' '+str(speed)+'x</h2><video controls muted playsinline data-speed="'+str(speed)+'" src="../live-'+v+'-r03/ja-hyun__special.mp4"></video></article>' for v in ['normal','mirror-small'] for speed in [1,.25])+'''<script>document.querySelectorAll('video').forEach(v=>{v.playbackRate=+v.dataset.speed;v.addEventListener('loadedmetadata',()=>v.playbackRate=+v.dataset.speed)})</script>''')
print('240 RGBA frames matched; source mismatches:',[(x['variant'],x['current_source_mismatches']) for x in receipts])
