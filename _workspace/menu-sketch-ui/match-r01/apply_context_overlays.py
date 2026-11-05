from pathlib import Path
import json
from bootstrap import call
P=Path(__file__).resolve().parent;j=json.loads((P/'scene-spec.json').read_text());rows=[]
for e in j['scenes']:
 if e['key'] not in ['code-input','code-filled','create-room','create-team'] and not e['key'].startswith(('ai-room','room-normal','room-solo','room-team')):continue
 code='const S=storage.match09,e='+json.dumps(e,ensure_ascii=False)+";const b=S.boards[e.key],old=S.spec.scenes.find(x=>x.key===e.key);if(b.getPluginData('menu09-approval')!=='pending'||b.getPluginData('menu09-ready')!==S.hash(old))throw Error('Inspect pending context revision');for(const x of e.elements.filter(x=>x.kind==='button')){b.children.find(c=>c.name===x.name).setPluginData('menu09-control',JSON.stringify({dest:x.dest,state:x.state,action:x.action}));}S.spec.scenes[S.spec.scenes.indexOf(old)]=e;b.setPluginData('menu09-ready',S.hash(e));return{key:e.key,overlay:true};"
 rows.append(call(code))
(P/'context-overlays-applied.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n');print('context overlays',len(rows))
