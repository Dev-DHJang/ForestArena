"""Reuse the unchanged localhost auth fixture and server; own and clean children."""
from pathlib import Path
import hashlib
import json
import os
import socket
import subprocess
import time

ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parent
MODES = ('natural', 'attack', 'jump')
files = set()
for folder, pattern in [('scripts','*.gd'),('server/game','*.gd'),('scenes','*.tscn'),('assets/combat','*.tres')]:
    files.update(p for p in (ROOT/folder).rglob(pattern))
for value in ['assets/character/manifest.json','forest_arena/data/character_display_layout_v01.json','tests/lan_auth_fixture.py','_workspace/motion-naturalness-v1/import-parity-candidate-frames.gd','_workspace/motion-naturalness-v1/remaining-candidate-catalog-r09.json','_workspace/motion-naturalness-v1/qa/launch-release-prototype-r04/presentation-prototype.gd','_workspace/motion-naturalness-v1/qa/launch-release-prototype-r04/release-clock.gd']:
    files.add(ROOT/value)
catalog=json.loads((ROOT/'_workspace/motion-naturalness-v1/remaining-candidate-catalog-r09.json').read_text())
for e in catalog['assets']:
    files.add(ROOT/e['path'])
    files.add(ROOT/e['sprite_frames_path'].removeprefix('res://'))
files.add(Path(__file__))
files.add(OUT/'client-fixture.gd')
hashes=lambda:{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(files)}
before=hashes()
(OUT/'source-hashes-before.json').write_text(json.dumps({'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'worktree':str(ROOT),'shared_server_and_clients_source_hashes':before},indent=2)+'\n')
def stop(process):
    if process is not None and process.poll() is None:
        process.terminate()
        try: process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            process.kill(); process.wait(timeout=3)
auth=None
server=None
results=[]
handles=[]
try:
    for port in (18081,17819):
        with socket.socket() as probe:
            probe.bind(('127.0.0.1',port))
    env=os.environ.copy()
    env.update(FOREST_ARENA_LAN_TEST_RECEIPTS=str(OUT/'receipts.jsonl'),FOREST_ARENA_LAN_API_URL='http://127.0.0.1:18081',FOREST_ARENA_SERVICE_TOKEN='lan-runtime-test-service',FOREST_ARENA_ALLOWED_CIDR='127.0.0.0/8',FOREST_ARENA_LAN_BIND_HOST='127.0.0.1',FOREST_ARENA_LAN_ADVERTISED_WS_URL='ws://127.0.0.1:17819',FOREST_ARENA_LAN_TEST_WS_URL='ws://127.0.0.1:17819',FOREST_ARENA_LAN_PORT='17819')
    log=(OUT/'auth.log').open('w');handles.append(log)
    auth=subprocess.Popen(['python3','tests/lan_auth_fixture.py'],cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT)
    time.sleep(.25)
    assert auth.poll() is None,'unchanged localhost auth fixture did not start'
    for mode in MODES:
        caseenv=env.copy()
        caseenv.update(LAN_RELEASE_MODE=mode,FOREST_ARENA_LAN_OUTBOX_PATH=str(OUT/(mode+'-outbox.json')))
        log=(OUT/(mode+'-server.log')).open('w');handles.append(log)
        server=subprocess.Popen(['godot','--headless','--path',str(ROOT),'res://server/game/lan_game_server.tscn'],cwd=ROOT,env=caseenv,stdout=log,stderr=subprocess.STDOUT)
        deadline=time.monotonic()+5
        while time.monotonic()<deadline:
            assert server.poll() is None,'server stopped during startup'
            if 'FOREST_ARENA_LAN_READY' in (OUT/(mode+'-server.log')).read_text():break
            time.sleep(.05)
        else:raise AssertionError('server ready timeout')
        log=(OUT/(mode+'-client.log')).open('w');handles.append(log)
        try:
            result=subprocess.run(['godot','--headless','--path',str(ROOT),'--script',str(OUT/'client-fixture.gd')],cwd=ROOT,env=caseenv,stdout=log,stderr=subprocess.STDOUT,timeout=22)
            results.append({'mode':mode,'client_exit_code':result.returncode})
        finally:
            stop(server);server=None
        print(mode,results[-1]['client_exit_code'],flush=True)
        if results[-1]['client_exit_code']!=0:break
finally:
    stop(server)
    stop(auth)
    for h in handles:h.close()
    after=hashes()
    equal=before==after
    (OUT/'source-hashes-after.json').write_text(json.dumps({'unchanged':equal,'changed':[p for p,v in before.items() if after[p]!=v],'files':after},indent=2)+'\n')
    passed=len(results)==3 and all(r['client_exit_code']==0 for r in results) and equal
    (OUT/'run-report.json').write_text(json.dumps({'status':'pass' if passed else 'fix','cases':results,'source_files_unchanged':equal,'cleanup':'only child server/auth processes started by this runner were terminated','scope':'actual localhost socket QA with unchanged production auth fixture/server; presentation clone in clients only'},indent=2)+'\n')
raise SystemExit(0 if passed else 1)
