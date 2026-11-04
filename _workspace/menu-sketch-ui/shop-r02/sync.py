import json
from pathlib import Path
from bootstrap import call
P=Path(__file__).resolve().parent
j=json.loads((P/'scene-spec.json').read_text());scenes=j.pop('scenes');call('storage.menu09s.spec='+json.dumps(dict(j,scenes=[]),ensure_ascii=False)+';return true;')
for s in scenes:call('storage.menu09s.spec.scenes.push('+json.dumps(s,ensure_ascii=False)+');return true;')
print('synced',len(scenes))
