"""Call the official local Penpot MCP REPL after its UI connection is enabled."""
import urllib.request,urllib.error,json,sys
from pathlib import Path
if sys.argv[1]=='--file':code=Path(sys.argv[2]).read_text()
else:code=sys.argv[1]
request=urllib.request.Request('http://localhost:4403/execute',data=json.dumps({'code':code}).encode(),headers={'Content-Type':'application/json'})
try:
 data=urllib.request.urlopen(request,timeout=150).read().decode()
except urllib.error.HTTPError as e:
 print(e.read().decode());sys.exit(1)
response=json.loads(data)
print(json.dumps(response,ensure_ascii=False)[:6000])
if not response.get('success'):sys.exit(1)
