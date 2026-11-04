from pathlib import Path
import json
from bootstrap import call
P=Path(__file__).resolve().parent
call("if(penpot.currentFile.id!=='d8ac01df-6646-81d2-8008-a3696fea940e')throw Error('Wrong file');const A=storage.menu09m;storage.menu09l={baseline:A.baseline,hash:A.hash,snap:A.snap,media:A.media,components:A.components};return true;")
j=json.loads((P/'scene-spec.json').read_text());scenes=j.pop('scenes');call('storage.menu09l.spec='+json.dumps(dict(j,scenes=[]),ensure_ascii=False)+';return true;')
for s in scenes:call('storage.menu09l.spec.scenes.push('+json.dumps(s,ensure_ascii=False)+');return true;')
code=(P.parent/'render.js').read_text().replace('storage.menu09','storage.menu09l').replace('23_MENU09_Review','28_MENU09_Life');(P/'render.js').write_text(code);print(call(code))
