"""Read saved IDs and original fingerprints into a fresh plugin session."""
import json,urllib.request
from pathlib import Path
P=Path(__file__).resolve().parent
before=json.loads((P/'preservation-before.json').read_text())['result']
def call(code):
 req=urllib.request.Request('http://localhost:4403/execute',data=json.dumps({'code':code},ensure_ascii=False).encode(),headers={'Content-Type':'application/json'})
 with urllib.request.urlopen(req,timeout=150) as r:j=json.load(r)
 if not j.get('success'):raise RuntimeError(j)
 return j.get('result')
code="""const S=storage.menu09={baseline:[],originalComponents:[]};S.hash=o=>{let h=2166136261;for(const c of JSON.stringify(o)){h^=c.charCodeAt(0);h=Math.imul(h,16777619);}return(h>>>0).toString(16);};S.snap=s=>({id:s.id,name:s.name,type:s.type,x:s.x,y:s.y,w:s.width,h:s.height,hidden:s.hidden,opacity:s.opacity,fill:s.fills,stroke:s.strokes,text:s.type==='text'?s.characters:undefined,children:s.children?.map(S.snap)});return true;"""
call(code)
for page in before['pages']:
 entry={**page,'boards':[]};call('storage.menu09.baseline.push('+json.dumps(entry,ensure_ascii=False)+');return true;')
 for i in range(0,len(page['boards']),100):call('storage.menu09.baseline.at(-1).boards.push(...'+json.dumps(page['boards'][i:i+100],ensure_ascii=False)+');return true;')
for i in range(0,len(before['components']),100):call('storage.menu09.originalComponents.push(...'+json.dumps(before['components'][i:i+100],ensure_ascii=False)+');return true;')
result=call("const S=storage.menu09;S.page=penpotUtils.getPageByName('23_MENU09_Review');S.boards=Object.fromEntries(S.page.root.children.filter(b=>b.getPluginData('menu09-key')).map(b=>[b.getPluginData('menu09-key'),b]));return{file:penpot.currentFile.id,revn:penpot.currentFile.revn,page:S.page.id,boards:Object.fromEntries(Object.entries(S.boards).map(([k,b])=>[k,{id:b.id,ready:b.getPluginData('menu09-ready'),approval:b.getPluginData('menu09-approval')}])),handoff:penpotUtils.getPageByName('24_MENU09_Handoff').root.children.map(b=>({id:b.id,name:b.name})),flows:S.page.flows.map(f=>({id:f.id,name:f.name})),tokens:penpot.library.local.tokens.sets.map(s=>({name:s.name,active:s.active}))};")
(P/'persistence-reload.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print('reloaded',len(result['boards']),'boards')
