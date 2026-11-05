from pathlib import Path
import json
from bootstrap import call
P=Path(__file__).resolve().parent;j=json.loads((P/'scene-spec.json').read_text());out=[]
for e in j['scenes']:
 if e['key'] not in ['code-input','code-filled']:continue
 code='const S=storage.match09,e='+json.dumps(e,ensure_ascii=False)+";const old=S.spec.scenes.find(s=>s.key===e.key),b=S.boards[e.key];if(b.getPluginData('menu09-approval')!=='pending'||b.getPluginData('menu09-ready')!==S.hash(old))throw Error('Inspect pending revision');for(const n of ['CODE / hint','CODE / scope']){const x=e.elements.find(x=>x.name===n),c=b.children.find(c=>c.name===n);c.characters=x.text;}S.spec.scenes[S.spec.scenes.indexOf(old)]=e;b.setPluginData('menu09-ready',S.hash(e));return{key:e.key,copy:'plain Korean input guidance'};"
 out.append(call(code))
(P/'code-copy-refined.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n');print(out)
