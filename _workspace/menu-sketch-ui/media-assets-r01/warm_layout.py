import sys,json
from pathlib import Path
P=Path(__file__).resolve().parent;sys.path.insert(0,str(P.parent/'match-r01'));from bootstrap import call
rows=[]
for page in json.loads((P/'penpot-audit.json').read_text()):
 call('await penpot.openPage('+json.dumps(page['id'])+');return penpot.currentPage.name')
 keys=[b['key'] for b in page['boards'] if b['status']=='review-pending-media']
 for i in range(0,len(keys),5):
  code='const keys='+json.dumps(keys[i:i+5])+";const out=[];for(const key of keys){const b=penpot.currentPage.root.children.find(b=>b.getPluginData('menu09-key')===key);if(b.getPluginData('menu09-approval')!=='review-pending-media')throw Error('Protected');penpot.selection=[b];penpot.viewport.zoom=.35;penpot.viewport.center={x:b.x+b.width/2,y:b.y+b.height/2};const t=b.children.find(c=>c.type==='text');const text=t?.characters;if(t)t.characters=text+' ';await new Promise(r=>setTimeout(r,400));if(t)t.characters=text;await new Promise(r=>setTimeout(r,160));out.push({page:penpot.currentPage.id,key,restored:!t||t.characters===text});}return out;"
  rows+=call(code);print('painted',len(rows),flush=True)
(P/'layout-warmed.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2))
