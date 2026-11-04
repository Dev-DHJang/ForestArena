from pathlib import Path
import json
from bootstrap import call
P=Path(__file__).resolve().parent;j=json.loads((P/'scene-spec.json').read_text());rows=[]
for s in j['scenes']:
 k=json.dumps(s['key']);status=call("const S=storage.menu09m;let b=S.page.root.children.find(b=>b.getPluginData('menu09-key')==="+k+");if(b)S.boards["+k+"]=b;return b?{ready:b.getPluginData('menu09-ready')===S.hash(S.spec.scenes.find(s=>s.key==="+k+")),children:b.children.length}:null;")
 if not status or not status['ready']:
  if s.get('comparison_of'):r=call('return await storage.menu09m.makeWide('+k+');')
  else:
   call("const S=storage.menu09m,e=S.spec.scenes.find(s=>s.key==="+k+");let b=S.boards[e.key];if(b)throw Error('Inspect incomplete before resuming');b=penpot.createBoard();b.name=e.name;b.resize(e.w,e.h);b.fills=[{fillColor:S.color('bg'),fillOpacity:1}];b.clipContent=true;const i=S.spec.scenes.indexOf(e);S.put(S.page.root,b,(i%3)*2640,Math.floor(i/3)*1320);b.setPluginData('menu09-owned','true');b.setPluginData('menu09-key',e.key);b.setPluginData('menu09-canonical',e.canonical);b.setPluginData('menu09-approval','pending');S.boards[e.key]=b;return b.id;")
   for n in range(0,len(s['elements']),4):
    call("const S=storage.menu09m,e=S.spec.scenes.find(s=>s.key==="+k+"),b=S.boards[e.key];for(const x of e.elements.slice("+str(n)+','+str(n+4)+")){if(b.children.some(c=>c.name===x.name))throw Error('Inspect duplicate');if(x.kind==='text')S.text(b,x);else if(x.kind==='rect')S.rect(b,x.name,x.x,x.y,x.w,x.h,x.color,x.opacity,x.radius);else if(x.kind==='button')S.button(b,x);else if(x.kind==='image')S.image(b,x);}return b.children.length;")
   r=call("const S=storage.menu09m,e=S.spec.scenes.find(s=>s.key==="+k+"),b=S.boards[e.key];if(b.children.length!==e.elements.length)throw Error('Incomplete');b.setPluginData('menu09-ready',S.hash(e));return{key:e.key,id:b.id,elements:b.children.length};")
 else:r=dict(key=s['key'],existing=True)
 call("const S=storage.menu09m,b=S.boards["+k+"];b.setPluginData('menu09-revision','missions-r01');if(S.spec.scenes.find(s=>s.key==="+k+").overlay)b.fills=[];return true;")
 rows.append(r);(P/'creation-final.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n');print(r,flush=True)
