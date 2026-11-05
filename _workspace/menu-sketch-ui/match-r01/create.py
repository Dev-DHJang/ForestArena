from pathlib import Path
import json
from bootstrap import call
P=Path(__file__).resolve().parent;j=json.loads((P/'scene-spec.json').read_text());rows=[]
call((P.parent/'shop-r01/make-wide.js').read_text().replace('storage.menu09s','storage.match09'))
call("const S=storage.match09;S.draw=(b,x)=>{if(x.kind==='text')return S.text(b,x);if(x.kind==='rect')return S.rect(b,x.name,x.x,x.y,x.w,x.h,x.color,x.opacity,x.radius);if(x.kind==='button')return S.button(b,x);if(x.kind==='image')return S.image(b,x);throw Error('Unsupported '+x.kind);};return true;")
for s in j['scenes']:
 k=json.dumps(s['key']);state=call("const S=storage.match09;let b=S.page.root.children.find(b=>b.getPluginData('menu09-key')==="+k+");if(b)S.boards["+k+"]=b;return b?{id:b.id,ready:b.getPluginData('menu09-ready')===S.hash(S.spec.scenes.find(s=>s.key==="+k+")),building:b.getPluginData('match-building')}:null;")
 if state and state['ready']:rows.append(dict(key=s['key'],existing=True));continue
 if s.get('comparison_of'):r=call('return await storage.match09.makeWide('+k+');')
 else:
  code="const S=storage.match09,e=S.spec.scenes.find(s=>s.key==="+k+");if(penpot.currentPage.id!==S.page.id)await penpot.openPage(S.page);let b=S.boards[e.key];if(b){if(b.getPluginData('match-building')!==S.hash(e)||b.getPluginData('menu09-approval')!=='pending')throw Error('Inspect partial');}else{if(e.clone_of&&S.boards[e.clone_of]){b=S.boards[e.clone_of].clone();}else b=penpot.createBoard();b.name=e.name;b.resize(e.w,e.h);b.clipContent=true;b.fills=e.overlay?[]:[{fillColor:S.color('bg'),fillOpacity:1}];const i=S.spec.scenes.indexOf(e);S.put(S.page.root,b,i%3*2640,Math.floor(i/3)*1320);b.setPluginData('menu09-owned','true');b.setPluginData('menu09-key',e.key);b.setPluginData('menu09-canonical',e.canonical);b.setPluginData('menu09-approval','pending');b.setPluginData('match-building',S.hash(e));b.setPluginData('menu09-ready','');S.boards[e.key]=b;for(const c of [...b.children])if(!e.elements.some(x=>x.name===c.name))c.remove();}return b.id;"
  call(code)
  for n in range(0,len(s['elements']),4):
   code="const S=storage.match09,e=S.spec.scenes.find(s=>s.key==="+k+"),b=S.boards[e.key],src=(S.spec.scenes.find(s=>s.key===e.clone_of)||S.externalSpecs[e.clone_of]);const cmp=x=>{const c={...x};delete c.dest;delete c.action;return JSON.stringify(c);};for(const x of e.elements.slice("+str(n)+','+str(n+4)+")){let c=b.children.find(c=>c.name===x.name);const old=src?.elements.find(y=>y.name===x.name);if(c&&(!old||cmp(old)!==cmp(x))){c.remove();c=null;}if(!c)c=S.draw(b,x);if(x.kind==='button')c.setPluginData('menu09-control',JSON.stringify({dest:x.dest,state:x.state,action:x.action}));}return b.children.length;"
   call(code)
  r=call("const S=storage.match09,e=S.spec.scenes.find(s=>s.key==="+k+"),b=S.boards[e.key];for(let i=0;i<e.elements.length;i++){const c=b.children.find(c=>c.name===e.elements[i].name);if(!c)throw Error('Incomplete');if(b.children[i]?.id!==c.id)c.setParentIndex(i);}if(b.children.length!==e.elements.length)throw Error('Extra children');b.setPluginData('menu09-ready',S.hash(e));b.setPluginData('menu09-revision','match-r01');return{key:e.key,id:b.id,elements:b.children.length};")
 rows.append(r);(P/'creation.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n');print(r,flush=True)
