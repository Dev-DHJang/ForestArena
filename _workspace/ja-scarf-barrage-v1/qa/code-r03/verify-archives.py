"""Read-only independent lossless archive verification; never deletes captures."""
import hashlib,json,subprocess
from pathlib import Path
base=Path('_workspace/ja-scarf-barrage-v1/qa')
results=[]
for folder in ['live-normal-r03','live-mirror-small-r03','live-all-normal-r05']:
 directory=base/folder
 report=directory/'state-report.json'
 archive=json.loads((directory/'raw-archive.json').read_text())
 assert hashlib.sha256(report.read_bytes()).hexdigest()==archive['capture_report_sha256']
 for row in archive['clips']:
  path=directory/row['archive']
  assert hashlib.sha256(path.read_bytes()).hexdigest()==row['archive_sha256']
  frame_bytes=row['dimensions'][0]*row['dimensions'][1]*4
  process=subprocess.Popen(['ffmpeg','-v','error','-i',str(path),'-map','0:v:0','-pix_fmt','rgba','-f','rawvideo','-'],stdout=subprocess.PIPE,stderr=subprocess.PIPE)
  sha=hashlib.sha256();md5=[];size=0
  while True:
   data=process.stdout.read(frame_bytes)
   if not data: break
   assert len(data)==frame_bytes,(path,'partial frame')
   sha.update(data);md5.append(hashlib.md5(data).hexdigest());size+=len(data)
  stderr=process.stderr.read().decode();assert process.wait()==0,stderr
  assert sha.hexdigest()==row['source_raw_sha256'],(path,'original RGBA SHA differs')
  assert md5==row['rgba_md5'],(path,'per-frame RGBA differs')
  assert size==row['source_raw_bytes']
  results.append({'folder':folder,'clip':row['clip'],'frames':len(md5),'rgba_bytes':size,'archive_hash_matches':True,'restored_rgba_sha_matches':True,'every_frame_md5_matches':True})
  print(folder,row['clip'],len(md5),'frames: archive SHA / restored raw SHA / every RGBA frame PASS',flush=True)
Path('_workspace/ja-scarf-barrage-v1/qa/code-r03/archive-decode.json').write_text(json.dumps({'status':'pass','clips':results},indent=2)+'\n')
print('TOTAL',len(results),'clips',sum(r['frames'] for r in results),'frames PASS')
