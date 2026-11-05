from pathlib import Path
import json,sys
from bootstrap import call
P=Path(__file__).resolve().parent;r=call((P/'protected-navigation.js').read_text());phase=sys.argv[1];(P/('protected-navigation-'+phase+'.json')).write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n');print(phase,'approved controls',len(r))
if phase=='after':
 assert r==json.loads((P/'protected-navigation-before.json').read_text()),'approved navigation changed'
 (P/'protected-navigation-summary.json').write_text(json.dumps(dict(status='pass',controls=len(r),links=sum(len(c['links']) for c in r)),indent=2)+'\n')
