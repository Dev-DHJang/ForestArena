from pathlib import Path
import json
from bootstrap import call
P=Path(__file__).resolve().parent
for key in ['rank-lobby','rank-lobby-wide']:
 call('const S=storage.match09,b=S.boards['+json.dumps(key)+"];b.children.find(c=>c.name==='MISSING / rank emblem').setPluginData('menu09-image-slot','IMG/rank/emblem/silver-3');return true;")
r=call((P/'audit.js').read_text());(P/'native-audit.json').write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n');print('native',r['status'],r['counts'],r['issues']);assert r['status']=='pass'
a=call((P/'preservation.js').read_text());(P/'preservation-after.json').write_text(json.dumps(a,ensure_ascii=False,indent=2)+'\n');b=json.loads((P/'preservation-before.json').read_text());assert a==b,'protected snapshot changed';r=dict(status='pass',approved_boards=sum(len(x['boards']) for x in a['pages']),original_pages=len(a['originalPages']),original_roots=sum(x['current'] for x in a['originalPages']),components=len(a['components']));(P/'preservation-summary.json').write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n');print('preservation',r)
code="const S=storage.match09;const rows=[];for(const e of S.spec.scenes){const b=S.boards[e.key];for(const x of e.elements.filter(x=>x.kind==='image')){const c=b.children.find(c=>c.name===x.name);rows.push({key:e.key,name:x.name,slot:x.slot,media:c.fills[0]?.fillImage?.id,expected:S.media[x.key]?.id});}}const errors=rows.filter(x=>x.media!==x.expected);return{status:errors.length?'fix':'pass',placements:rows,issues:errors,missingSlots:S.spec.missing_assets};"
r=call(code);assert r['status']=='pass';(P/'asset-audit.json').write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n');print('media',len(r['placements']))
r=call("const v=await penpot.currentFile.saveVersion('MENU09 생활 r02 승인 · 대전 준비3종 match-r01 검토대기');return{label:v.label,revn:penpot.currentFile.revn,createdAt:v.createdAt,page:storage.match09.page.id,file:penpot.currentFile.id};");(P/'saved-version.json').write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n');print('saved',r)
