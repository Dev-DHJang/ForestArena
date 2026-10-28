"""Independent local PNG provenance/pixel check; does not modify production files."""
import hashlib,json,datetime
from pathlib import Path
from PIL import Image,ImageChops
P=Path(__file__).resolve().parent
r=json.loads((P/'export-records.json').read_text());d=json.loads((P/'derived-snapshots.json').read_text())
report={'checkedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'scope':'Only actual local PNGs in export-records/derived-snapshots captured at start; no Penpot, prototype, physical-device, or full-completion claim','recordCounts':{k:len(v)for k,v in r.items()},'derivedCount':len(d),'specSha256AtStart':hashlib.sha256((P/'scene-spec.json').read_bytes()).hexdigest(),'records':[],'errors':[]}
(P/'qa-r08-records-snapshot.json').write_text(json.dumps({'exports':r,'derived':d},ensure_ascii=False,indent=2)+'\n')
by={x['name']:x for x in r['designExports']}
for section,items,size in [('designExports',r['designExports'],(1920,1080)),('scenes',r['scenes'],(1280,720)),('derived',d,(1280,720))]:
 seen=set()
 for x in items:
  errors=[];f=P/'exports'/x['filename'];b=f.read_bytes();sha=hashlib.sha256(b).hexdigest()
  if x['name']in seen:errors.append('duplicate-name')
  seen.add(x['name'])
  if sha!=x['sha256']:errors.append('sha256')
  if 'bytes'in x and len(b)!=x['bytes']:errors.append('byte-count')
  with Image.open(f)as im:
   im.load();actual_size=im.size;mode=im.mode
   if im.size!=size or x['outputSize']!=list(size):errors.append('dimensions')
   if section!='designExports':
    src=by.get(x['name'])
    if not src:errors.append('missing-native-record')
    else:
     if src['filename']!=x['sourceFilename']or src['sha256']!=x['sourceSha256']:errors.append('source-reference')
     if src['nativeSpecHash']!=x['nativeSpecHash']:errors.append('native-spec-hash')
     with Image.open(P/'exports'/src['filename'])as native:
      expected=native.convert('RGBA').resize(size,Image.Resampling.LANCZOS)
      if ImageChops.difference(expected,im.convert('RGBA')).getbbox(alpha_only=False):errors.append('LANCZOS-pixels')
  row={'section':section,'name':x['name'],'filename':x['filename'],'sha256':sha,'bytes':len(b),'size':list(actual_size),'mode':mode,'errors':errors};report['records'].append(row)
  if errors:report['errors'].append(row)
report['status']='PASS_WITHIN_RECORDED_SCOPE'if not report['errors']else'FIX'
(P/'qa-r08-pixel-check.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items()if k not in['records','errors']},ensure_ascii=False));print('errors',len(report['errors']))
