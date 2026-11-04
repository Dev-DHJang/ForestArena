from pathlib import Path
import json
from bootstrap import call
P=Path(__file__).resolve().parent;j=json.loads((P/'scene-spec.json').read_text());rows=[]
call((P.parent/'shop-r01/make-wide.js').read_text().replace('storage.menu09s','storage.menu09m'))
for e in j['scenes']:
 key=e['key'];k=json.dumps(key);code='const S=storage.menu09m;const result=await S.'+('makeWide' if e.get('comparison_of') else 'make')+'('+k+');const b=S.boards['+k+"];b.setPluginData('menu09-revision','missions-r01');if(S.spec.scenes.find(s=>s.key==="+k+").overlay)b.fills=[];return result;"
 try:r=call(code)
 except Exception as ex:
  (P/'creation-error.txt').write_text(str(ex));raise
 rows.append(r);(P/'creation.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n');print(r,flush=True)
