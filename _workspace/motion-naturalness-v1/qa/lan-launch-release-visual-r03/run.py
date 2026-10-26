"""Prepared-only real LAN renderer. Explicit root authorization is required to run."""
from pathlib import Path
import argparse
import gzip
from PIL import Image
import hashlib
import json
import os
import socket
import subprocess
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--authorized-render-and-sockets', action='store_true', help='use only after root explicitly permits GUI and socket execution')
args = parser.parse_args()
if not args.authorized_render_and_sockets:
    raise SystemExit('PREPARED ONLY: GUI/sockets are forbidden until root explicitly authorizes this flag')

ROOT = Path(__file__).resolve().parents[4]
BASE = Path(__file__).resolve().parent
requested = os.environ.get('LAN_RELEASE_OUTPUT_DIR')
OUT = (Path(requested) if requested else BASE/'runs'/str(time.time_ns())).resolve()
if not OUT.is_relative_to((ROOT/'_workspace').resolve()):
    raise SystemExit('QA output must remain inside _workspace')
if OUT.exists():
    raise SystemExit('QA output already exists; choose a new versioned directory')
PRESENTATION = 'res://scripts/local_fighter_presentation.gd'
if os.environ.get('LAN_RELEASE_PRESENTATION', PRESENTATION) != PRESENTATION:
    raise SystemExit('Visual fixture requires the current public presentation')
if not PRESENTATION.startswith('res://'):
    raise SystemExit('Presentation must use a project-local res:// script')
selected_source = (ROOT/PRESENTATION.removeprefix('res://')).resolve()
if not selected_source.is_relative_to(ROOT) or not selected_source.is_file() or selected_source.suffix != '.gd':
    raise SystemExit('Presentation must resolve to an existing project-local GDScript')
MODES = tuple((target,facing) for target in ('ja-hyun','nabi') for facing in ('normal','mirror'))
CATALOG_SHA256 = '005960d9a5ec54d29a7ca637905eaee64b33ecb6308a527debc53d46bfbed324'
ERROR_MARKERS = ('SCRIPT ERROR', 'ERROR:', 'FAIL', 'Traceback')
def source_file(path):
    # Source/import settings are included; hidden/cache directories and local
    # bytecode/OS files are not executable inputs to this capture.
    relative=path.relative_to(ROOT)
    return path.is_file() and not any(part.startswith('.') or part=='__pycache__' for part in relative.parts[:-1]) and path.name not in {'.DS_Store'} and path.suffix not in {'.pyc','.pyo'}

files = {ROOT/'project.godot'}
for folder in ('assets','forest_arena'):
    files.update(path for path in (ROOT/folder).rglob('*') if source_file(path))
for folder,suffixes in [('scripts',{'.gd'}),('server/game',{'.gd','.tscn','.tres','.json'}),('scenes',{'.gd','.tscn','.tres'})]:
    files.update(path for path in (ROOT/folder).rglob('*') if path.suffix in suffixes and source_file(path))
for value in ['assets/character/manifest.json','forest_arena/data/character_display_layout_v01.json','tests/lan_auth_fixture.py','_workspace/motion-naturalness-v1/import-parity-candidate-frames.gd','_workspace/motion-naturalness-v1/remaining-candidate-catalog-r10.json']:
    files.add(ROOT/value)
catalog=json.loads((ROOT/'_workspace/motion-naturalness-v1/remaining-candidate-catalog-r10.json').read_text())
for e in catalog['assets']:
    files.add(ROOT/e['path'])
    files.add(ROOT/e['sprite_frames_path'].removeprefix('res://'))
files.add(Path(__file__))
files.add(BASE/'client-fixture.gd')
files.add(BASE/'render-relay.gd')
files.add(selected_source)
registry_path=ROOT/'forest_arena/data/resource_registry.json'
files.add(registry_path)
registry=json.loads(registry_path.read_text())
for asset in registry['assets']:
    if asset.get('id') in ('fa.background.combat.training.arena','fa.terrain.combat.forest-ledge'):
        for value in [asset.get('path'),*asset.get('variants',{}).values()]:
            if isinstance(value,str) and value.startswith('res://'): files.add(ROOT/value.removeprefix('res://'))
for row in json.loads((ROOT/'assets/character/manifest.json').read_text())['assets']:
    if row.get('type')=='animation-runtime' and row.get('character_id') in ('ja-hyun','nabi'):
        files.add(ROOT/row['path']);files.add(ROOT/row['sprite_frames_path'].removeprefix('res://'))
if hashlib.sha256((ROOT/'_workspace/motion-naturalness-v1/remaining-candidate-catalog-r10.json').read_bytes()).hexdigest()!=CATALOG_SHA256:
    raise SystemExit('Frozen r10 catalog hash differs; root review is required before capture')
hashes=lambda:{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(files)}
before=hashes()
pinned=json.loads((BASE/'prepared-source-hashes.json').read_text())
if pinned!=before:
    raise SystemExit('Prepared source hashes changed; root must review and freeze a new capture revision')
OUT.mkdir(parents=True)
(OUT/'source-hashes-before.json').write_text(json.dumps({'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'worktree':str(ROOT),'shared_server_and_clients_source_hashes':before},indent=2)+'\n')
def stop(process):
    if process is not None and process.poll() is None:
        process.terminate()
        try: process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            process.kill(); process.wait(timeout=3)
def file_sha(path):
    h=hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda:stream.read(1<<20),b''):h.update(chunk)
    return h.hexdigest()

def verify_and_archive(report,case,case_dir):
    artifacts=[]
    for slot in (1,2):
        captures=[c for c in report['capture_manifest'] if c['client_slot']==slot]
        assert captures, 'no real rendered frames for a client'
        raw_path=case_dir/(case+f'-client-{slot}.rgba')
        frame_size=640*480*4
        assert raw_path.stat().st_size==len(captures)*frame_size,'raw stream length differs'
        png_dir=case_dir/(case+f'-client-{slot}-png');png_dir.mkdir()
        for index, capture in enumerate(captures):
            assert capture['raw_path']==raw_path.name and capture['raw_offset']==index*frame_size
            assert capture['byte_length']==frame_size and capture['size']==[640,480]
            assert capture['render_tick']==capture['trace']['render_tick']
            assert capture['trace']['client_slot']==slot and capture['trace']['snapshot_unchanged']
            assert capture['trace']['pixel_marker_verified']
            observed=capture['trace']['draw_observation']
            assert observed['sync_pose_matches_native_draw']
            assert observed['sync_stamp']==observed['last_sync_packet']['sync_stamp']
            assert observed['frame_zero_based']==capture['trace']['frame_zero_based']
            with raw_path.open('rb') as source:
                source.seek(capture['raw_offset']);data=source.read(frame_size)
            assert hashlib.sha256(data).hexdigest()==capture['rgba_sha256'],'frame/trace raw hash differs'
            rendered=Image.frombytes('RGBA',(640,480),data)
            decoded=[]
            for byte_index in range(8):
                value=0
                for bit in range(8):
                    rgba=rendered.getpixel((5+(byte_index*8+bit)*2,5))
                    if all(c>127 for c in rgba[:3]):value|=1<<bit
                decoded.append(value)
            assert decoded==observed['marker_bytes'],'RGBA marker differs from native draw observation'
            assert decoded[:2]==[165,90] and (decoded[2]|decoded[3]<<8)==observed['sync_stamp']&65535
            assert decoded[4]==observed['frame_zero_based'] and decoded[5]==slot
            motion_code={'launch':1,'jump':2}.get(observed['animation'],0)
            assert decoded[6]==motion_code|(128 if observed['flip_h'] else 0)

            png=png_dir/f'frame-{index:04d}.png'
            Image.frombytes('RGBA',(640,480),data).save(png)
            with Image.open(png) as decoded:
                assert decoded.mode=='RGBA' and decoded.tobytes()==data,'PNG changed RGBA pixels'
                assert any(lo!=hi for lo,hi in decoded.getextrema()[:3]),'uniform/blank rendered capture'
        active=[c['trace']['frame_zero_based'] for c in captures if c['trace']['release_active']]
        ordered=[value for index,value in enumerate(active) if index==0 or value!=active[index-1]]
        assert ordered==[12,13,14,15], 'archive misses four actually drawn natural release poses'
        assert any(c['trace']['motion']=='launch' and not c['trace']['release_active'] for c in captures),'archive misses launch before bridge'
        assert any(c['trace']['motion']=='jump' and not c['trace']['release_active'] for c in captures),'archive misses jump after bridge'
        compressed=raw_path.with_suffix('.rgba.gz')
        with raw_path.open('rb') as source, compressed.open('wb') as target:
            with gzip.GzipFile(filename='',mode='wb',fileobj=target,mtime=0) as archive:
                for chunk in iter(lambda:source.read(1<<20),b''):archive.write(chunk)
        restored=hashlib.sha256()
        with gzip.open(compressed,'rb') as archive:
            for chunk in iter(lambda:archive.read(1<<20),b''):restored.update(chunk)
        assert restored.hexdigest()==file_sha(raw_path),'archive changed raw RGBA stream'
        artifacts.append({'case':case,'client_slot':slot,'frames':len(captures),'archive':str(compressed.relative_to(OUT)),'target_character':report['target_character'],'archive_sha256':file_sha(compressed),'raw_sha256':file_sha(raw_path),'byte_exact_rgba_verified':True,'png_pixels_equal_raw':True,'png_directory':png_dir.name,'actual_release_samples':active,'consecutive_release_pose_order':ordered})
    return artifacts

auth=None
server=None
results=[]
archives=[]
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
    for target,facing in MODES:
        mode=target+"-"+facing
        case_dir=OUT/mode;case_dir.mkdir()
        caseenv=env.copy()
        caseenv.update(LAN_RELEASE_MODE='natural',LAN_RELEASE_VISUAL_CASE=facing,LAN_RELEASE_TARGET_CHARACTER=target,LAN_RELEASE_VISUAL_AUTHORIZED='root-reviewed-render-and-sockets',LAN_RELEASE_OUTPUT_DIR=str(case_dir),LAN_RELEASE_PRESENTATION=PRESENTATION,FOREST_ARENA_LAN_OUTBOX_PATH=str(OUT/(mode+'-outbox.json')))
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
            result=subprocess.run(['godot','--path',str(ROOT),'--rendering-method','gl_compatibility','--rendering-driver','opengl3','--max-fps','60','--resolution','1280x512','--script',str(BASE/'client-fixture.gd')],cwd=ROOT,env=caseenv,stdout=log,stderr=subprocess.STDOUT,timeout=22)
            report_path=case_dir/(facing+'-report.json')
            try:
                report=json.loads(report_path.read_text())
            except (OSError,ValueError):
                report={}
            text=(OUT/(mode+'-client.log')).read_text()
            valid_report=report.get('status')=='pass' and report.get('errors')==[] and report.get('checks',0)>0 and report.get('presentation')==PRESENTATION and report.get('mode')=='natural' and report.get('visual_case')==facing and report.get('target_character')==target and report.get('catalog_sha256')==CATALOG_SHA256 and len(report.get('capture_manifest',[]))>0
            valid_log=('LAN_LAUNCH_RELEASE_VISUAL '+facing+': PASS') in text and not any(mark in text for mark in ERROR_MARKERS)
            archive_valid=False
            if result.returncode==0 and valid_report and valid_log:
                archived=verify_and_archive(report,facing,case_dir)
                archives.extend(archived)
                archive_valid=len(archived)==2 and all(row['byte_exact_rgba_verified'] for row in archived)
            results.append({'mode':mode,'client_exit_code':result.returncode,'report_valid':valid_report,'archive_valid':archive_valid,'log_valid':valid_log,'checks':report.get('checks',0),'presentation':report.get('presentation'),'report_sha256':hashlib.sha256(report_path.read_bytes()).hexdigest() if report_path.exists() else None})
        finally:
            stop(server);server=None
        server_text=(OUT/(mode+'-server.log')).read_text()
        results[-1]['server_log_valid']=not any(mark in server_text for mark in ERROR_MARKERS)
        print(mode,results[-1]['client_exit_code'],flush=True)
        if results[-1]['client_exit_code']!=0 or not results[-1]['report_valid'] or not results[-1]['log_valid'] or not results[-1]['server_log_valid'] or not results[-1]['archive_valid']:break
finally:
    stop(server)
    stop(auth)
    for h in handles:h.close()
    after=hashes()
    equal=before==after
    (OUT/'source-hashes-after.json').write_text(json.dumps({'unchanged':equal,'changed':[p for p,v in before.items() if after[p]!=v],'files':after},indent=2)+'\n')
    auth_log_valid=not any(mark in (OUT/'auth.log').read_text() for mark in ERROR_MARKERS) if (OUT/'auth.log').exists() else False
    passed=len(results)==4 and all(r['client_exit_code']==0 and r['report_valid'] and r['log_valid'] and r['server_log_valid'] and r['archive_valid'] for r in results) and equal and auth_log_valid
    (OUT/'run-report.json').write_text(json.dumps({'status':'pass' if passed else 'fix','cases':results,'rgba_archives':archives,'source_files_unchanged':equal,'auth_log_valid':auth_log_valid,'cleanup':'only child server/auth processes started by this runner were terminated','presentation_source':PRESENTATION,'output':str(OUT.relative_to(ROOT)),'scope':'real-socket public-presentation fixture, not actual app HUD footage; native Sprite.draw marker and frame_post_draw RGBA pose pairing, immediate receive apply with sync/draw states logged; lossless archive verified separately from semantic/device QA'},indent=2)+'\n')
raise SystemExit(0 if passed else 1)
