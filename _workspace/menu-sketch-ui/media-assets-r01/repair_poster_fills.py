"""Restore and reread the Collection poster fills identified by independent QA."""
import json
import sys
from pathlib import Path

P = Path(__file__).resolve().parent
sys.path.insert(0, str(P.parent / 'match-r01'))
from bootstrap import call

rows = json.loads((P / 'qa/penpot-media-discrepancies.json').read_text())
page_name = '31_MENU09_Media_Collection'
call('await penpot.openPage(storage.media09.pages["' + page_name + '"]);return penpot.currentPage.name')
for start in range(0, len(rows), 4):
    batch = rows[start:start + 4]
    result = call('const batch=' + json.dumps(batch) + ''';
const page=penpot.currentPage;
if(page.id!==storage.media09.pages['31_MENU09_Media_Collection'])throw Error('Wrong page');
for(const row of batch){
    const shape=page.getShapeById(row.shape);
    const media=storage.media09.posters[row.slot];
    if(shape?.getPluginData('menu09-video-slot')!==row.slot||media?.id!==row.expected)throw Error('Slot mismatch');
    shape.fills=[{fillImage:media,fillOpacity:1}];
}
return batch.map(row=>({shape:row.shape,id:page.getShapeById(row.shape).fills[0].fillImage?.id}));''')
    assert [r['id'] for r in result] == [r['expected'] for r in batch], result
    print('Restored', start + len(batch), 'of', len(rows), flush=True)
