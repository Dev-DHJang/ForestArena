"""Export the changed media layouts from the live Penpot file."""
import hashlib
import json
import sys
from pathlib import Path

P = Path(__file__).resolve().parent
sys.path.insert(0, str(P.parent / 'match-r01'))
from bootstrap import call

selection = {
    '30_MENU09_Media_Review': ['media-overview'],
    '31_MENU09_Media_Collection': ['skills-light', 'artifact-all', 'skills-light-wide', 'skills-heavy-pending'],
    '32_MENU09_Media_Shop': ['shop-artifacts-all', 'shop-artifact-iron-armor-from-all', 'shop-character-ja-hyun-light'],
    '33_MENU09_Media_Match': ['rank-lobby', 'rank-lobby-wide'],
}
exports = P / 'exports'
exports.mkdir(exist_ok=True)
index = exports / 'index.json'
records = json.loads(index.read_text()) if index.exists() else []
completed = {r['key'] for r in records if (exports / r['file']).exists() and hashlib.sha256((exports / r['file']).read_bytes()).hexdigest() == r['sha256']}
for page in json.loads((P / 'penpot-audit.json').read_text()):
    keys = [key for key in selection[page['name']] if key not in completed]
    if not keys:
        continue
    call('await penpot.openPage(' + json.dumps(page['id']) + ');return penpot.currentPage.name')
    boards = {board['key']: board for board in page['boards']}
    for key in keys:
        board = boards[key]
        name = key + '.png'
        target = exports / name
        code = (
            'const b=penpot.currentPage.getShapeById(' + json.dumps(board['id']) + ');'
            'if(!b||b.getPluginData("menu09-approval")!=="review-pending-media")throw Error("Wrong review board");'
            'return Array.from(await b.export({type:"png",scale:1}));'
        )
        try:
            data = bytes(call(code))
        except RuntimeError as error:
            print('Retrying export', key, str(error), flush=True)
            try:
                data = bytes(call(code))
            except RuntimeError as error:
                print('Export unavailable', key, str(error), flush=True)
                continue
        target.write_bytes(data)
        records.append({'key': key, 'page': page['id'], 'board': board['id'], 'file': name,
                        'sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
                        'width': board['w'], 'height': board['h']})
        (exports / 'index.json').write_text(json.dumps(records, ensure_ascii=False, indent=2) + '\n')
        print('exported', name, flush=True)
