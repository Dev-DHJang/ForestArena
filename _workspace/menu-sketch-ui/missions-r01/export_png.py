import json,sys,hashlib
from pathlib import Path
from bootstrap import call
P=Path(__file__).resolve().parent;key=sys.argv[1]
r=call("const S=storage.menu09m;const b=S.boards["+json.dumps(key)+"];if(!b)throw Error('Missing board');return Array.from(await b.export({type:'png',scale:1}));")
data=bytes(r);d=P/'exports';d.mkdir(exist_ok=True);f=d/(key+'.png');f.write_bytes(data)
rec=dict(key=key,file=f.name,bytes=len(data),sha256=hashlib.sha256(data).hexdigest(),source='actual Penpot native board export')
(d/(key+'.json')).write_text(json.dumps(rec,indent=2)+'\n');print(key,len(data))
