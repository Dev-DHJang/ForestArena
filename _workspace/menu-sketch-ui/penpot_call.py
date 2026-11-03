"""Official loopback Penpot MCP REPL client; responses remain local."""
import json,sys,urllib.request,urllib.error
from pathlib import Path
code=Path(sys.argv[1]).read_text()
req=urllib.request.Request('http://localhost:4403/execute',data=json.dumps({'code':code}).encode(),headers={'Content-Type':'application/json'})
try:
 with urllib.request.urlopen(req,timeout=150) as r: result=json.load(r)
except urllib.error.HTTPError as e:
 print(e.read().decode());sys.exit(1)
if len(sys.argv)>2: Path(sys.argv[2]).write_text(json.dumps(result,ensure_ascii=False,indent=2))
if not result.get('success'): print(result);sys.exit(1)
r=result.get('result'); print(json.dumps(r,ensure_ascii=False)[:6000])
