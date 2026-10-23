"""Lossless archival of already captured PNGs; never rerender or edit artwork."""
import argparse,hashlib,json,subprocess
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('capture',type=Path);p.add_argument('--remove-frames',action='store_true');a=p.parse_args()
topic=Path(__file__).resolve().parent;base=a.capture.resolve();assert base.is_relative_to((topic/'review').resolve())
report=json.loads((base/'state-report.json').read_text());assert report['errors']==[]
receipt=base/'rgba-archive.json';assert not receipt.exists(),'archive already exists; never overwrite evidence'
def frame_hashes(args):
 raw=subprocess.check_output(['ffmpeg','-v','error',*args,'-pix_fmt','rgba','-f','framemd5','-']).decode()
 return [line.rsplit(',',1)[1].strip() for line in raw.splitlines() if line and not line.startswith('#')]
records=[];removal=[]
for clip in report['scenarios']:
 folder=base/clip['name'];frames=sorted(folder.glob('frame-*.png'))
 assert [f.name for f in frames]==[f'frame-{i:03d}.png' for i in range(clip['frame_count'])],'incomplete captured frames'
 source=str(folder/'frame-%03d.png');movie=base/(clip['name']+'-lossless-rgb.mkv');assert not movie.exists()
 original=frame_hashes(['-framerate','60','-i',source])
 subprocess.run(['ffmpeg','-v','error','-framerate','60','-i',source,'-c:v','libx264rgb','-crf','0','-preset','slow','-pix_fmt','rgb24',str(movie)],check=True)
 restored=frame_hashes(['-i',str(movie)]);assert original==restored and len(original)==clip['frame_count'],'RGBA pixels changed'
 records.append({'clip':clip['name'],'frame_count':len(frames),'codec':'lossless H.264 RGB CRF0','archive':movie.name,'archive_sha256':hashlib.sha256(movie.read_bytes()).hexdigest(),'png_sha256':{f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in frames},'rgba_md5':original})
 removal.append((folder,frames))
receipt.write_text(json.dumps({'capture_report_sha256':hashlib.sha256((base/'state-report.json').read_bytes()).hexdigest(),'status':'capture pixels archived; semantic QA status is separate','clips':records},ensure_ascii=False,indent=2)+'\n')
if a.remove_frames:
 for folder,frames in removal:
  for frame in frames:frame.unlink()
  folder.rmdir()
print(f'archived {len(records)} clips; every original RGBA frame verified; removed_pngs={a.remove_frames}')
