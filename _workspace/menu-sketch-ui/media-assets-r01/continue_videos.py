import sys,json
from pathlib import Path
P=Path(__file__).resolve().parent;sys.path.insert(0,str(P.parent/'match-r01'));from bootstrap import call
results=[]
for name in ['32_MENU09_Media_Shop','33_MENU09_Media_Match']:
 call('await penpot.openPage(storage.media09.pages['+json.dumps(name)+']);return penpot.currentPage.name')
 keys=call("return penpot.currentPage.root.children.map(b=>b.getPluginData('menu09-key'))")
 for i in range(0,len(keys),8):
  call('storage.media09.onlyKeys='+json.dumps(keys[i:i+8])+';return true')
  r=call((P/'integrate-videos.js').read_text());results.append(r);print(name,i,r,flush=True)
call('storage.media09.onlyKeys=null;return true')
(P/'video-integration.json').write_text(json.dumps(results,ensure_ascii=False,indent=2));(P/'placements.json').write_text(json.dumps(call('return storage.media09.placements'),ensure_ascii=False,indent=2))
