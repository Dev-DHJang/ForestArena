"""Derive review/snapshot PNGs from actual native Penpot 1920 exports."""
from pathlib import Path
import json,hashlib,re
from PIL import Image,__version__ as pillow_version
TASK=Path(__file__).resolve().parent
records=json.loads((TASK/'export-records.json').read_text())
cache_path=TASK/'derived-snapshots.json'
cache={r['name']:r for r in json.loads(cache_path.read_text())} if cache_path.exists() else {}
rows=[]
for source in records.get('designExports',[]):
 name=source['name'];filename=source['filename']
 assert re.fullmatch(r'[A-Za-z0-9_.-]+-1920\.png',filename),filename
 assert source['outputSize']==[1920,1080],name
 path=TASK/'exports'/filename
 actual_sha=hashlib.sha256(path.read_bytes()).hexdigest()
 assert actual_sha==source['sha256'],name+' native source SHA differs'
 out_name=filename.replace('-v08-1920.png','-v08.png');out=TASK/'exports'/out_name
 prior=cache.get(name)
 if prior and prior['sourceSha256']==actual_sha and prior['nativeSpecHash']==source['nativeSpecHash'] and out.exists():rows.append(prior);continue
 with Image.open(path) as image:
  assert image.size==(1920,1080),name
  image.convert('RGBA').resize((1280,720),Image.Resampling.LANCZOS).save(out,format='PNG')
 rows.append({'name':name,'filename':out_name,'outputSize':[1280,720],'sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'sourceFilename':filename,'sourceSha256':actual_sha,'resizeAlgorithm':f'Pillow {pillow_version} Image.Resampling.LANCZOS; RGBA 1920x1080 -> 1280x720','nativeSpecHash':source['nativeSpecHash']})
cache_path.write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'native1920':len(records.get('designExports',[])),'derived1280':len(rows),'pixelSource':'actual native Penpot PNG'},ensure_ascii=False))
