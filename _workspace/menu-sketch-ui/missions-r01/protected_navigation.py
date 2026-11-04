from pathlib import Path
import json
from bootstrap import call
P=Path(__file__).resolve().parent;groups=[]
for rel,page in [('../scene-spec.json','23_MENU09_Review'),('../collection-r01/scene-spec.json','25_MENU09_Collection'),('../shop-r02/scene-spec.json','26_MENU09_Shop')]:
 j=json.loads((P/rel).read_text());groups.append(dict(page=page,scenes=[dict(key=s['key'],overlay=s.get('overlay',False),buttons=[dict(name=e['name'],dest=e.get('dest'),action=e.get('action'),state=e.get('state')) for e in s['elements'] if e['kind'] in ['button','card']]) for s in j['scenes']]))
# Feed one page at a time to keep the official local REPL request below 100KB.
results=[]
for g in groups:
 code='const g='+json.dumps(g,ensure_ascii=False)+";const issues=[];let controls=0,links=0;const p=penpotUtils.getPageByName(g.page),boards=Object.fromEntries(p.root.children.map(b=>[b.getPluginData('menu09-key'),b]));for(const s of g.scenes){for(const e of s.buttons){controls++;const c=boards[s.key].children.find(c=>c.name===e.name);const ints=c.interactions||[];if(e.action==='close-overlay'){links++;if(ints.length!==1||ints[0].action.type!=='close-overlay')issues.push([s.key,e.name,'close']);}else if(e.dest&&e.state!=='disabled'){links++;const expected=g.scenes.find(x=>x.key===e.dest).overlay?'open-overlay':'navigate-to';if(ints.length!==1||ints[0].action.type!==expected||ints[0].action.destination.id!==boards[e.dest].id)issues.push([s.key,e.name,'destination']);}else if(ints.length)issues.push([s.key,e.name,'unexpected']);}}return{page:g.page,boards:g.scenes.length,controls,links,issues};"
 results.append(call(code))
r=dict(status='fix' if any(x['issues'] for x in results) else 'pass',protected_boards=sum(x['boards'] for x in results),controls=sum(x['controls'] for x in results),links=sum(x['links'] for x in results),pages=results)
(P/'protected-navigation.json').write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n');print({k:v for k,v in r.items() if k!='pages'})
