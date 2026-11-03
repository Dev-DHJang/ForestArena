import json,urllib.request
from pathlib import Path
P=Path(__file__).resolve().parent

def call(c):
 req=urllib.request.Request('http://localhost:4403/execute',data=json.dumps({'code':c},ensure_ascii=False).encode(),headers={'Content-Type':'application/json'})
 with urllib.request.urlopen(req,timeout=150) as r:j=json.load(r)
 if not j.get('success'):raise RuntimeError(j)
 return j.get('result')

if __name__=='__main__':
 baseline=json.loads((P.parent/'preservation-before.json').read_text())['result']
 if (P/'yoyo-media.json').exists():baseline['media']['pebble-yoyo']=json.loads((P/'yoyo-media.json').read_text())['media']
 call("if(penpot.currentFile.id!=='d8ac01df-6646-81d2-8008-a3696fea940e')throw Error('Wrong file');const A=storage.menu09;storage.menu09c={baseline:A.baseline,hash:A.hash,snap:A.snap,media:"+json.dumps(baseline['media'])+",components:Object.fromEntries(penpot.library.local.components.filter(c=>c.path==='Premium Menu v08').map(c=>[c.name,c]))};return true;")
 spec=json.loads((P/'scene-spec.json').read_text());scenes=spec.pop('scenes')
 call('storage.menu09c.spec='+json.dumps(dict(spec,scenes=[]),ensure_ascii=False)+';return true;')
 for s in scenes:call('storage.menu09c.spec.scenes.push('+json.dumps(s,ensure_ascii=False)+');return true;')
 render=(P.parent/'render.js').read_text().replace('storage.menu09','storage.menu09c').replace('23_MENU09_Review','25_MENU09_Collection')
 print(call(render))
