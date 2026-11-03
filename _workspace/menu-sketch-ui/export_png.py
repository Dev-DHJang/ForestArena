"""Export actual Penpot boards via the official local REPL; print metadata only."""
import json,sys,urllib.request,urllib.error,hashlib
from pathlib import Path
base=Path(__file__).resolve().parent
key=sys.argv[1]
code="const S=storage.menu09;const b=S.boards["+json.dumps(key)+"];if(!b)throw Error('Missing board');if(penpot.currentPage.id!==S.page.id)await penpot.openPage(S.page);const bytes=await b.export({type:'png',scale:1});return Array.from(bytes);"
req=urllib.request.Request('http://localhost:4403/execute',data=json.dumps({'code':code}).encode(),headers={'Content-Type':'application/json'})
try:
 with urllib.request.urlopen(req,timeout=150) as r:result=json.load(r)
except urllib.error.HTTPError as e:
 print(e.read().decode());sys.exit(1)
if not result.get('success'):raise RuntimeError(result)
data=bytes(result['result']);target=base/'exports'/f'{key}-1920.png';target.parent.mkdir(exist_ok=True);target.write_bytes(data)
record={'key':key,'file':target.name,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest(),'source':'actual Penpot board export'}
(base/'exports'/f'{key}.json').write_text(json.dumps(record,indent=2)+'\n');print(json.dumps(record))
