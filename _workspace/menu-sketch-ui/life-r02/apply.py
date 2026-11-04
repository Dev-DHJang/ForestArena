from pathlib import Path
import json
from bootstrap import call
P=Path(__file__).resolve().parent;spec=json.loads((P/'scene-spec.json').read_text());old=json.loads((P.parent/'life-r01/scene-spec.json').read_text());prev={s['key']:s for s in old['scenes']};changes=json.loads((P/'updates.json').read_text());rows=[]
call("const S=storage.life02;S.boards['settings-discard-graphics']=S.boards['settings-discard-view'];S.boards['settings-effects-wide']=S.boards['settings-profile-wide'];return true;")
for item in changes:
 key=item['key'];oldkey=item['oldKey'];oldspec=prev[oldkey]
 call('const S=storage.life02,old='+json.dumps(oldspec,ensure_ascii=False)+',key='+json.dumps(key)+";const b=S.boards[key];if(!b||b.getPluginData('menu09-approval')!=='pending'||b.getPluginData('menu09-ready')!==S.hash(old))throw Error('Inspect revision '+key);return true;")
 for n in range(0,len(item['edits']),3):
  edits=item['edits'][n:n+3];code='const S=storage.life02,key='+json.dumps(key)+',xs='+json.dumps(edits,ensure_ascii=False)+',prev='+json.dumps(oldspec['elements'],ensure_ascii=False)+";const b=S.boards[key],cmp=x=>{const q={...x};delete q.dest;delete q.action;return JSON.stringify(q);};for(const e of xs){let c=b.children.find(c=>c.name===e.name);const a=prev.find(x=>x.name===e.name);if(e.kind==='text'&&c){c.characters=e.text;}else if(e.kind==='button'){if(c&&a&&cmp(a)===cmp(e)){}else{if(c)c.remove();c=S.button(b,e);}c.setPluginData('menu09-control',JSON.stringify({dest:e.dest,state:e.state,action:e.action}));}else throw Error('Unexpected correction kind '+e.kind);}return true;"
  call(code)
 new=next(s for s in spec['scenes'] if s['key']==key)
 r=call('const S=storage.life02,key='+json.dumps(key)+',e='+json.dumps(new,ensure_ascii=False)+',remove='+json.dumps(item['remove'])+";const b=S.boards[key];for(const n of remove){const c=b.children.find(c=>c.name===n);if(c)c.remove();}for(let i=0;i<e.elements.length;i++){const c=b.children.find(c=>c.name===e.elements[i].name);if(!c)throw Error('Missing '+e.elements[i].name);if(b.children[i]?.id!==c.id)c.setParentIndex(i);}b.name=e.name;b.setPluginData('menu09-key',e.key);b.setPluginData('menu09-revision','life-r02');b.setPluginData('menu09-ready',S.hash(e));return{key:e.key,id:b.id,elements:b.children.length};")
 rows.append(r);(P/'changes-applied.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n');print(r,flush=True)
# Replace only the pending comparison's contents while keeping its board ID.
wide=next(s for s in spec['scenes'] if s['key']=='settings-effects-wide')
r=call('const S=storage.life02,e='+json.dumps(wide,ensure_ascii=False)+";const b=S.boards[e.key];if(b.getPluginData('menu09-approval')!=='pending')throw Error('Protected');const tmp=S.boards['settings-effects'].clone();tmp.setPluginData('menu09-key','temporary-r02-comparison');const parts=tmp.children.map(c=>({c,x:c.parentX,y:c.parentY}));for(const c of [...b.children])c.remove();for(const a of parts){b.appendChild(a.c);if(['IMG / character-room','ATMOSPHERE','HEADER','FOOTER'].includes(a.c.name)){a.c.resize(2400,a.c.height);penpotUtils.setParentXY(a.c,a.x,a.y);}else penpotUtils.setParentXY(a.c,a.x+240,a.y);for(const i of a.c.interactions||[])i.remove();}tmp.remove();b.name=e.name;b.setPluginData('menu09-key',e.key);b.setPluginData('menu09-revision','life-r02');b.setPluginData('menu09-ready',S.hash(e));return{key:e.key,id:b.id,elements:b.children.length};")
rows.append(r);print(r,flush=True)
# Retire one obsolete, owned and unapproved confirmation; r01 named version1026 is preserved.
r=call("const S=storage.life02,b=S.boards['settings-discard-profile'];if(!b||b.getPluginData('menu09-approval')!=='pending'||b.getPluginData('menu09-owned')!=='true')throw Error('Protected');const id=b.id;for(const f of [...S.page.flows])if(f.startingBoard?.id===id)f.remove();b.remove();delete S.boards['settings-discard-profile'];delete S.boards['settings-discard-view'];delete S.boards['settings-profile-wide'];return{retired:id};")
(P/'obsolete-retired.json').write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n');print(r,flush=True)
# Load the final spec and update pending metadata only; content of other screens is unchanged.
for e in spec['scenes']:
 call('const S=storage.life02,e='+json.dumps(e,ensure_ascii=False)+";S.spec.scenes.push(e);const b=S.boards[e.key];if(b.getPluginData('menu09-approval')!=='pending')throw Error('Protected');b.name=e.name;b.setPluginData('menu09-revision','life-r02');b.setPluginData('menu09-ready',S.hash(e));return true;")
(P/'changes-applied.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n');print('final',len(spec['scenes']),flush=True)
