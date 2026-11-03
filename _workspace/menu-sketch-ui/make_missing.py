import json,urllib.request
from pathlib import Path
base=Path(__file__).resolve().parent
results=[]
for key in ['character-from-room','character-from-room-pending','character-from-room-ready','character-from-room-ready-pending']:
 code='return await storage.menu09.make('+json.dumps(key)+');'
 req=urllib.request.Request('http://localhost:4403/execute',data=json.dumps({'code':code}).encode(),headers={'Content-Type':'application/json'})
 with urllib.request.urlopen(req,timeout=120) as r:result=json.load(r)
 if not result.get('success'):raise RuntimeError(result)
 results.append(result['result']);print(key,flush=True)
(base/'context-states-created.json').write_text(json.dumps(results,indent=2)+'\n')
