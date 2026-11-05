from pathlib import Path
import json
from bootstrap import call
P=Path(__file__).resolve().parent;j=json.loads((P/'scene-spec.json').read_text());rows=[]
for e in j['scenes']:
 if e['key'] not in ['room-team','room-team-ready','room-team-leave','room-team-ready-leave']:continue
 code='const S=storage.match09,e='+json.dumps(e,ensure_ascii=False)+";const old=S.spec.scenes.find(x=>x.key===e.key),b=S.boards[e.key];if(b.getPluginData('menu09-approval')!=='pending'||b.getPluginData('menu09-ready')!==S.hash(old))throw Error('Inspect pending team revision');for(let i=0;i<e.elements.length;i++){const c=b.children.find(c=>c.name===e.elements[i].name);if(b.children[i]?.id!==c.id)c.setParentIndex(i);}S.spec.scenes[S.spec.scenes.indexOf(old)]=e;b.setPluginData('menu09-ready',S.hash(e));return{key:e.key,memberIndex:b.children.findIndex(c=>c.name==='IMG / ja-hyun'),slotIndex:b.children.findIndex(c=>c.name==='PARTY / slot 5')};"
 rows.append(call(code))
(P/'team-layer-fix.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n');print(rows)
