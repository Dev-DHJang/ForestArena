"""Preserve failed capture pixels losslessly before removing bulky PNG intermediates."""
from pathlib import Path
import hashlib,json,subprocess
base=Path(__file__).resolve().parent/'review/live-pilot-r01'
if (base/'failed-capture-archive.json').exists(): raise SystemExit('archive already exists; refusing to overwrite its evidence')
records=[]
def hashes(args):
 data=subprocess.check_output(['ffmpeg','-v','error',*args,'-pix_fmt','rgba','-f','framemd5','-']).decode()
 return [r.rsplit(',',1)[1].strip() for r in data.splitlines() if r and not r.startswith('#')]
for folder in sorted(p for p in base.iterdir() if p.is_dir()):
 frames=sorted(folder.glob('frame-*.png'))
 if not frames:continue
 movie=base/f'{folder.name}-failed-rgb.mkv';source=str(folder/'frame-%03d.png')
 original=hashes(['-framerate','60','-i',source])
 subprocess.run(['ffmpeg','-v','error','-y','-framerate','60','-i',source,'-c:v','libx264rgb','-crf','0','-preset','slow','-pix_fmt','rgb24',str(movie)],check=True)
 restored=hashes(['-i',str(movie)])
 assert original==restored and len(original)==len(frames),'lossless archive mismatch'
 records.append({'clip':folder.name,'status':'failed capture; OS focus paused match; not QA pass','codec':'H.264 RGB lossless CRF0; every original RGBA frame verified','frames':len(frames),'png_sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in frames},'rgba_md5':original,'lossless_archive':movie.name,'archive_sha256':hashlib.sha256(movie.read_bytes()).hexdigest()})
 for frame in frames:frame.unlink()
 folder.rmdir()
(base/'failed-capture-archive.json').write_text(json.dumps({'status':'failed','reason':'OS focus callback paused the match. Partial captures are retained as lossless RGB video; RGBA hashes match every original frame. Never use as approval evidence.','clips':records},ensure_ascii=False,indent=2)+'\n')
print('lossless failed capture archive verified',len(records))
