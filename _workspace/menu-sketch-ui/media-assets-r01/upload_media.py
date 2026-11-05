#!/usr/bin/env python3
"""공식 Penpot uploadMediaData를 사용. 입력 크기에 맞춰 원본 바이트를 나누어 전달."""
import sys,json,base64
from pathlib import Path
P=Path(__file__).resolve().parent
sys.path.insert(0,str(P.parent/'match-r01'))
from bootstrap import call

def upload(slot,path,kind):
 encoded=base64.b64encode(Path(path).read_bytes()).decode()
 call('storage.media09.upload=[];return true')
 for i in range(0,len(encoded),60000):call('storage.media09.upload.push('+json.dumps(encoded[i:i+60000])+');return true')
 code="const s=storage.media09.upload.join('');const b=Uint8Array.from(atob(s),c=>c.charCodeAt(0));const m=await penpot.uploadMediaData(NAME,b,'image/png');storage.media09[KIND][SLOT]=m;storage.media09.upload=[];return {id:m.id,w:m.width,h:m.height};"
 return call(code.replace('NAME',json.dumps('MENU09 media-r01 '+slot)).replace('KIND',json.dumps(kind)).replace('SLOT',json.dumps(slot)))
if __name__=='__main__':
 rows=[]
 for r in json.loads((P/'images/manifest.json').read_text()):
  result=upload(r['slot'],P.parents[2]/r['path'],'images');rows.append({'slot':r['slot'],'kind':'image','media':result});print(r['slot'],result,flush=True)
 (P/'penpot-media.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2))
