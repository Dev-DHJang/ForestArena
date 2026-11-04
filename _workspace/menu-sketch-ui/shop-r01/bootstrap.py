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

if __name__=='__main__':
 media=json.loads((P.parent/'preservation-before.json').read_text())['result']['media'];media['pebble-yoyo']=json.loads((P.parent/'collection-r01/yoyo-media.json').read_text())['media']
 call("if(penpot.currentFile.id!=='d8ac01df-6646-81d2-8008-a3696fea940e')throw Error('Wrong file');const A=storage.menu09c||storage.menu09;storage.menu09s={baseline:A.baseline,hash:A.hash,snap:A.snap,media:"+json.dumps(media)+",components:Object.fromEntries(penpot.library.local.components.filter(c=>c.path==='Premium Menu v08').map(c=>[c.name,c]))};return true;")
 j=json.loads((P/'scene-spec.json').read_text());scenes=j.pop('scenes');call('storage.menu09s.spec='+json.dumps(dict(j,scenes=[]),ensure_ascii=False)+';return true;')
 for s in scenes:call('storage.menu09s.spec.scenes.push('+json.dumps(s,ensure_ascii=False)+');return true;')
 code=(P.parent/'render.js').read_text().replace('storage.menu09','storage.menu09s').replace('23_MENU09_Review','26_MENU09_Shop')
 code=code.replace("else if(x.kind==='radar')S.radar(b,x);", "else if(x.kind==='radar')S.radar(b,x);else if(x.kind==='currency')S.currency(b,x);")
 print(call(code))
 print(call((P/'make.js').read_text()))
