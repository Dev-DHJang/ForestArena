from pathlib import Path
import json
from bootstrap import call
P=Path(__file__).resolve().parent;old=json.loads((P/'construction-spec.json').read_text());new=json.loads((P/'scene-spec.json').read_text());prior={s['key']:s for s in old['scenes']};rows=[]
for e in new['scenes']:
 a=prior.get(e['key'])
 if not a or a==e:continue
 call('const S=storage.menu09l,e='+json.dumps(e,ensure_ascii=False)+',old='+json.dumps(a,ensure_ascii=False)+";const b=S.boards[e.key];if(!b||b.getPluginData('menu09-approval')!=='pending'||b.getPluginData('menu09-ready')!==S.hash(old))throw Error('Inspect revision '+e.key);return true;")
 for n in range(0,len(e['elements']),4):
  code='const S=storage.menu09l,e='+json.dumps(e,ensure_ascii=False)+',old='+json.dumps(a,ensure_ascii=False)+";const b=S.boards[e.key];const cmp=x=>{const q={...x};delete q.dest;delete q.action;return JSON.stringify(q);};for(const x of e.elements.slice("+str(n)+','+str(n+4)+")){const prev=old.elements.find(y=>y.name===x.name);let c=b.children.find(c=>c.name===x.name);if(c&&(!prev||cmp(prev)!==cmp(x))){c.remove();c=null;}if(!c)c=S.draw(b,x);if(x.kind==='button')c.setPluginData('menu09-control',JSON.stringify({dest:x.dest,state:x.state,action:x.action}));}return true;"
  call(code)
 r=call('const S=storage.menu09l,e='+json.dumps(e,ensure_ascii=False)+";const b=S.boards[e.key];for(const c of [...b.children])if(!e.elements.some(x=>x.name===c.name))c.remove();for(let i=0;i<e.elements.length;i++){const c=b.children.find(c=>c.name===e.elements[i].name);if(b.children[i]?.id!==c.id)c.setParentIndex(i);}b.setPluginData('menu09-ready',S.hash(e));return{key:e.key,elements:b.children.length};")
 rows.append(r);print(r,flush=True)
head={k:v for k,v in new.items() if k!='scenes'};head['scenes']=[];call('storage.menu09l.spec='+json.dumps(head,ensure_ascii=False)+';return true;')
for s in new['scenes']:call('storage.menu09l.spec.scenes.push('+json.dumps(s,ensure_ascii=False)+');return true;')
(P/'refinements.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
