import json,urllib.request,urllib.error
from pathlib import Path
P=Path(__file__).resolve().parent

def call(code):
 req=urllib.request.Request('http://localhost:4403/execute',data=json.dumps({'code':code},ensure_ascii=False).encode(),headers={'Content-Type':'application/json'})
 try:
  with urllib.request.urlopen(req,timeout=150) as r:j=json.load(r)
 except urllib.error.HTTPError as e:raise RuntimeError(e.read().decode()[:2000]) from e
 if not j.get('success'):raise RuntimeError(j)
 return j.get('result')
