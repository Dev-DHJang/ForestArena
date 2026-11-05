from pathlib import Path
import json
from bootstrap import call
P=Path(__file__).resolve().parent
print(call((P/'init.js').read_text()))
call("const p=penpotUtils.getPageByName('29_MENU09_Match');if(p&&p.root.children.some(b=>b.getPluginData('menu09-approval')!=='pending'))throw Error('Approved match revision: do not modify');return true;")
spec=json.loads((P/('scene-spec.json' if (P/'code-copy-refined.json').exists() else 'construction-spec.json')).read_text());head={**spec,'scenes':[]};call('storage.match09.spec='+json.dumps(head,ensure_ascii=False)+';return true;')
for s in spec['scenes']:call('storage.match09.spec.scenes.push('+json.dumps(s,ensure_ascii=False)+');return true;')
orig=json.loads((P/'preservation-before.json').read_text())['originalPages'];call('storage.match09.baseline='+json.dumps(orig)+';return true;')
old=json.loads((P.parent/'scene-spec.json').read_text());ext={'approved-room':next(s for s in old['scenes'] if s['key']=='room'),'approved-lobby':next(s for s in old['scenes'] if s['key']=='lobby')};call('storage.match09.externalSpecs='+json.dumps(ext,ensure_ascii=False)+';return true;')
print(call((P/'render.js').read_text()))

# Match each existing board to a recorded pending specification before continuing any partial correction.
for candidate in ['pre-context-spec.json','construction-spec.json']:
 cs=json.loads((P/candidate).read_text())['scenes']
 call('const S=storage.match09,xs='+json.dumps(cs,ensure_ascii=False)+";for(const e of xs){const b=S.boards[e.key];if(b&&b.getPluginData('menu09-ready')===S.hash(e))S.spec.scenes[S.spec.scenes.findIndex(s=>s.key===e.key)]=e;}return true;")
print(call("const S=storage.match09;return{matching:S.spec.scenes.filter(e=>S.boards[e.key]?.getPluginData('menu09-ready')===S.hash(e)).length,total:S.spec.scenes.length};"))
