import sys,json
from pathlib import Path
P=Path(__file__).resolve().parent;sys.path.insert(0,str(P.parent/'match-r01'));from bootstrap import call
results=[]
for name in ['30_MENU09_Media_Review','31_MENU09_Media_Collection','32_MENU09_Media_Shop','33_MENU09_Media_Match']:
 call('await penpot.openPage(storage.media09.pages['+json.dumps(name)+']);return penpot.currentPage.name')
 results.append(call((P/'integrate-videos.js').read_text()));print(results[-1],flush=True)
(P/'video-integration.json').write_text(json.dumps(results,ensure_ascii=False,indent=2))
(P/'placements.json').write_text(json.dumps(call('return storage.media09.placements'),ensure_ascii=False,indent=2))
