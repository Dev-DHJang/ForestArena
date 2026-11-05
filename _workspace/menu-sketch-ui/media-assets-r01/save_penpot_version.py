"""Record one named checkpoint for the reviewed media revision."""
import json
import sys
from pathlib import Path

P = Path(__file__).resolve().parent
sys.path.insert(0, str(P.parent / 'match-r01'))
from bootstrap import call

label = 'MENU09 미디어 29종 반영 · 검토 대기 · 2026-11-05'
file_id = 'd8ac01df-6646-81d2-8008-a3696fea940e'
check = f'''const f=penpot.currentFile;
if(f.id!=={json.dumps(file_id)})throw Error('Wrong file');
const versions=await f.findVersions();
return {{file:f.id,revn:f.revn,versions:versions.filter(v=>v.label==={json.dumps(label)}).map(v=>({{id:v.id,label:v.label,createdAt:v.createdAt,isAutosave:v.isAutosave}}))}};'''
result = call(check)
if not result['versions'] and '--check-only' not in sys.argv:
    try:
        call(f'''const f=penpot.currentFile;if(f.id!=={json.dumps(file_id)})throw Error('Wrong file');
await f.saveVersion({json.dumps(label)});return true;''')
    except RuntimeError as error:
        print('Checking the checkpoint after the save response:', error, flush=True)
    result = call(check)
if len(result['versions']) != 1:
    raise SystemExit('Named checkpoint is not confirmed. Use --check-only before retrying.')
(P / 'saved-version.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
print(result, flush=True)
