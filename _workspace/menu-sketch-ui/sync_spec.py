import json,urllib.request
from pathlib import Path
base=Path(__file__).resolve().parent
spec=json.loads((base/'scene-spec.json').read_text());scenes=spec.pop('scenes')
codes=['storage.menu09.spec='+json.dumps(dict(spec,scenes=[]),ensure_ascii=False)+'; return true;']
codes+=['storage.menu09.spec.scenes.push('+json.dumps(s,ensure_ascii=False)+'); return true;' for s in scenes]
for code in codes:
 req=urllib.request.Request('http://localhost:4403/execute',data=json.dumps({'code':code},ensure_ascii=False).encode(),headers={'Content-Type':'application/json'})
 with urllib.request.urlopen(req,timeout=120) as r:result=json.load(r)
 if not result.get('success'):raise RuntimeError(result)
print('loaded',len(scenes),'scenes')
