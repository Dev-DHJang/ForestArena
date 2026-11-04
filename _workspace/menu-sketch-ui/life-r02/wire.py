from pathlib import Path
import json
from bootstrap import call
P=Path(__file__).resolve().parent;spec=json.loads((P/'scene-spec.json').read_text());rows=[]
for s in spec['scenes']:
 call('storage.life02.wireKey='+json.dumps(s['key'])+';return true;');rows.append(call((P/'wire-one.js').read_text()))
(P/'wire-counts.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n');r=call((P/'finish.js').read_text());(P/'wiring.json').write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n');print({'boards':len(r['boards']),'links':sum(s['links'] for s in rows),'page':r['page']})
