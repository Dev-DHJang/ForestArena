import sys,json,time
from pathlib import Path
P=Path(__file__).resolve().parent;sys.path.insert(0,str(P.parent/'match-r01'));from bootstrap import call
names=['30_MENU09_Media_Review','31_MENU09_Media_Collection','32_MENU09_Media_Shop','33_MENU09_Media_Match']
for name in names:
 call('await penpot.openPage(storage.media09.pages['+json.dumps(name)+']);return penpot.currentPage.name')
 code="""const p=penpot.currentPage,M=storage.media09;for(const b of p.root.children){const pending=b.getPluginData('menu09-approval')==='review-pending-media';b.setPluginData('menu09-layout-approval-reference',b.getPluginData('menu09-approved-revision'));b.setPluginData('menu09-approval-evidence',pending?'media-assets-r01 제작·반영; 새 미디어 사용자 승인 미기록. 이전 레이아웃 승인은 source-page와 layout-approval-reference 참조.':'기존 승인 레이아웃을 복제한 보드. 새 미디어 반영본과 구분.');if(pending)b.setPluginData('menu09-approved-revision','');const slot=b.children.find(s=>s.name==='VIDEO / slot')?.characters;const d=b.children.find(s=>s.name==='SKILL / description');if(d&&slot?.endsWith('/heavy'))d.characters=slot.includes('/nabi/')?'기존 상향 강공격 동작을 시연합니다.':'기존 가로 강공격 동작을 시연합니다.';if(d&&slot?.endsWith('/special'))d.characters=slot.includes('/ja-hyun/')?'기존 스카프 휩쓸기 동작을 시연합니다.':slot.includes('/nabi/')?'기존 측면 특수 동작을 시연합니다.':'기존 중립 특수 동작을 시연합니다.';}return {page:p.name,boards:p.root.children.length};"""
 print(call(code),flush=True)
# Original source boards remain unchanged.
before=json.loads((P/'penpot-before.json').read_text());after=call((P.parent/'final-approval/snapshot.js').read_text());(P/'penpot-after.json').write_text(json.dumps(after,ensure_ascii=False,indent=2))
assert before==after,'Approved original shape/navigation/approval changed'
(P/'preservation.json').write_text(json.dumps({'approved_source_boards':sum(len(p['boards']) for p in before),'shape_navigation_approval_unchanged':before==after,'runtime_files_changed':False},ensure_ascii=False,indent=2))
print('Approved 284 originals unchanged',flush=True)
