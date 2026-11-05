from pathlib import Path
import json
from bootstrap import call
P=Path(__file__).resolve().parent;spec=json.loads((P/'scene-spec.json').read_text());rows=[]
for offset in range(0,len(spec['scenes']),4):
 keys=[s['key'] for s in spec['scenes'][offset:offset+4]]
 code='const S=storage.match09,keys='+json.dumps(keys)+";const out=[];if(penpot.currentFile.id!=='d8ac01df-6646-81d2-8008-a3696fea940e')throw Error('Wrong file');if(penpot.currentPage.id!==S.page.id)await penpot.openPage(S.page);for(const key of keys){const b=S.boards[key],e=S.spec.scenes.find(s=>s.key===key);if(b.getPluginData('menu09-approval')!=='pending')throw Error('Protected');penpot.selection=[b];penpot.viewport.zoom=.35;penpot.viewport.center={x:b.x+b.width/2,y:b.y+540};const t=b.children.find(c=>c.type==='text');const original=t?e.elements.find(x=>x.name===t.name)?.text:null;if(t&&original===undefined)throw Error('Unknown text');if(t)t.characters=original+' ';await new Promise(r=>setTimeout(r,400));if(t)t.characters=original;await new Promise(r=>setTimeout(r,160));out.push({key,id:b.id,temporaryTextRestored:!t||t.characters===original,texts:penpotUtils.findShapes(x=>x.type==='text',b).length});}return out;"
 rows+=call(code);(P/'layout-warmed.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n');print('painted',len(rows),flush=True)
