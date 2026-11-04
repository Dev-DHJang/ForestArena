from pathlib import Path
import json
from bootstrap import call
P=Path(__file__).resolve().parent;groups=[]
for rel,page in [('../scene-spec.json','23_MENU09_Review'),('../collection-r01/scene-spec.json','25_MENU09_Collection')]:
 j=json.loads((P/rel).read_text());groups.append(dict(page=page,scenes=[dict(key=s['key'],buttons=[dict(name=e['name'],dest=e.get('dest')) for e in s['elements'] if e['kind']=='button']) for s in j['scenes']]))
r=call('const groups='+json.dumps(groups,ensure_ascii=False)+";const issues=[];let controls=0,links=0;for(const g of groups){const p=penpotUtils.getPageByName(g.page);const boards=Object.fromEntries(p.root.children.map(b=>[b.getPluginData('menu09-key'),b]));for(const s of g.scenes){for(const e of s.buttons){controls++;const c=boards[s.key].children.find(c=>c.name===e.name);const ints=c.interactions||[];if(e.dest){links++;if(ints.length!==1||ints[0].action.type!=='navigate-to'||ints[0].action.destination.id!==boards[e.dest].id)issues.push({page:g.page,key:s.key,button:e.name});}else if(ints.length)issues.push({page:g.page,key:s.key,button:e.name,error:'unexpected link'});}}}return{status:issues.length?'fix':'pass',protected_boards:63,controls,links,issues};")
(P/'protected-navigation.json').write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n');print(r)
