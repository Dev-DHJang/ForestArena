"""No sockets/processes: isolate runner control flow with temporary mock outputs."""
from pathlib import Path
import contextlib
import hashlib
import io
import json
import os
import runpy
import subprocess
import tempfile
from unittest.mock import patch

BASE=Path(__file__).resolve().parent
ROOT=BASE.parents[3]
RUNNER=BASE/'run.py'
OUT=Path(tempfile.mkdtemp(prefix='mock-only-independent-',dir=BASE))
(OUT/'MOCK_ONLY.txt').write_text('All child run reports here are synthetic mocked subprocess tests. No server, auth process or socket was used.\n')
rows=[]
class FakeSocket:
    def __enter__(self):return self
    def __exit__(self,*args):pass
    def bind(self,address):pass
class FakeProcess:
    def __init__(self,args,**kw):
        self.ended=False
        if args[0]=='python3' and scenario=='auth-error':
            kw['stdout'].write('Traceback: injected auth fixture fault\n');kw['stdout'].flush()
        if args[0]=='godot':
            kw['stdout'].write('FOREST_ARENA_LAN_READY mock-only\n')
            if scenario=='server-error':kw['stdout'].write('SCRIPT ERROR: injected server fault\n')
            kw['stdout'].flush()
    def poll(self):return 0 if self.ended else None
    def terminate(self):self.ended=True
    def kill(self):self.ended=True
    def wait(self,**kw):return 0

scenario=''
def fake_run(args,**kw):
    env=kw['env'];mode=env['LAN_RELEASE_MODE'];out=Path(env['LAN_RELEASE_OUTPUT_DIR'])
    report={'status':'pass','errors':[],'checks':1,'presentation':env['LAN_RELEASE_PRESENTATION'],'mode':mode,'catalog_sha256':'005960d9a5ec54d29a7ca637905eaee64b33ecb6308a527debc53d46bfbed324'}
    if scenario=='report-fix':report['status']='fix'
    if scenario=='report-errors':report['errors']=['injected failure']
    if scenario=='zero-checks':report['checks']=0
    if scenario=='wrong-presentation':report['presentation']='res://wrong.gd'
    if scenario=='wrong-mode':report['mode']='other-case'
    if scenario=='wrong-catalog':report['catalog_sha256']='0'*64
    if scenario=='missing-catalog':report.pop('catalog_sha256')
    if scenario!='missing-report':(out/(mode+'-report.json')).write_text(json.dumps(report))
    text='LAN_LAUNCH_RELEASE '+mode+': PASS\n'
    if scenario=='missing-pass-log':text='no completion sentinel\n'
    if scenario=='client-error':text+='SCRIPT ERROR: injected client fault\n'
    kw['stdout'].write(text);kw['stdout'].flush()
    return subprocess.CompletedProcess(args,1 if scenario=='nonzero-client' else 0)

def execute(name,expected_pass=False,environment=None):
    global scenario
    scenario=name
    dest=OUT/name
    env={'LAN_RELEASE_OUTPUT_DIR':str(dest)}
    if environment:env.update(environment)
    stdout=io.StringIO()
    code=0
    try:
        with patch.dict(os.environ,env,clear=True),patch('socket.socket',FakeSocket),patch('subprocess.Popen',FakeProcess),patch('subprocess.run',side_effect=fake_run),patch('subprocess.check_output',return_value='mock-head\n'),patch('time.sleep',lambda n:None),contextlib.redirect_stdout(stdout):
            runpy.run_path(str(RUNNER),run_name='__mock_runner__')
    except SystemExit as e:
        code=e.code
    passed=(code==0)
    report=json.loads((dest/'run-report.json').read_text()) if (dest/'run-report.json').exists() else None
    rows.append({'case':name,'expected_pass':expected_pass,'actual_pass':passed,'expectation_met':passed==expected_pass,'exit':code,'runner_status':None if report is None else report['status'],'mock_only':True})

execute('positive-control',expected_pass=True)
for name in ['missing-report','report-fix','report-errors','zero-checks','wrong-presentation','missing-pass-log','client-error','nonzero-client']:
    execute(name)
# Deliberately test missing checks for scope: these expose holes if accepted.
execute('wrong-mode')
execute('server-error')
execute('auth-error')
execute('wrong-catalog')
execute('missing-catalog')

def reject_before_work(name,dest,presentation=None):
    env={'LAN_RELEASE_OUTPUT_DIR':str(dest)}
    if presentation is not None:env['LAN_RELEASE_PRESENTATION']=presentation
    calls=[];code=0
    before={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in dest.rglob('*') if p.is_file()} if dest.exists() and dest.is_dir() else {}
    try:
        with patch.dict(os.environ,env,clear=True),patch('socket.socket',side_effect=lambda: calls.append('socket')),patch('subprocess.Popen',side_effect=lambda *a,**k:calls.append('process')),contextlib.redirect_stdout(io.StringIO()):
            runpy.run_path(str(RUNNER),run_name='__mock_runner__')
    except SystemExit as e:code=e.code
    after={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in dest.rglob('*') if p.is_file()} if dest.exists() and dest.is_dir() else {}
    good=code!=0 and not calls and before==after
    rows.append({'case':name,'expectation_met':good,'exit':code,'before_after_equal':before==after,'no_socket_or_process_call':not calls,'mock_only':True})

existing=OUT/'existing';existing.mkdir();(existing/'sentinel.txt').write_text('keep exact original')
reject_before_work('existing-output-refused',existing)
outside=Path(tempfile.mkdtemp(prefix='forest-lan-boundary-outside-'))
reject_before_work('outside-workspace-refused',outside/'new-output')
link=OUT/'escape-link';link.symlink_to(outside,target_is_directory=True)
reject_before_work('symlink-output-escape-refused',link/'new-output')
reject_before_work('non-res-presentation-refused',OUT/'invalid-present-a','/tmp/file.gd')
reject_before_work('traversal-presentation-refused',OUT/'invalid-present-b','res://../../outside.gd')
reject_before_work('missing-presentation-refused',OUT/'invalid-present-c','res://does-not-exist.gd')


# A default runs symlink must be resolved too; abort before any outside write.
default_link=BASE/'runs'
if not default_link.exists() and not default_link.is_symlink():
    default_link.symlink_to(outside,target_is_directory=True)
    seen=[]
    original_mkdir=Path.mkdir
    class ProbeAbort(Exception):pass
    def guarded_mkdir(path,*args,**kwargs):
        seen.append(str(path.resolve()))
        raise ProbeAbort()
    try:
        with patch.dict(os.environ,{},clear=True),patch.object(Path,'mkdir',new=guarded_mkdir),patch('time.time_ns',return_value=12345678901234567890):
            runpy.run_path(str(RUNNER),run_name='__mock_runner__')
    except SystemExit as e:
        rejected=True
    except ProbeAbort:
        rejected=False
    finally:
        default_link.unlink()
    rows.append({'case':'default-output-symlink-escape-refused','expectation_met':rejected,'resolved_mkdir_target':seen,'no_outside_write':True,'mock_only':True})
else:
    rows.append({'case':'default-output-symlink-escape-refused','expectation_met':False,'blocked':'existing runs folder preserved; no probe executed','mock_only':True})

report={'scope':'mock-only; subprocess and socket constructors replaced; no actual socket ports used','output_directory':str(OUT.relative_to(ROOT)),'checks':len(rows),'passed_expectations':sum(r['expectation_met'] for r in rows),'findings':[r for r in rows if not r['expectation_met']],'cases':rows}
(BASE/'independent-boundaries-r03.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'checks':report['checks'],'passed_expectations':report['passed_expectations'],'findings':report['findings']},ensure_ascii=False,indent=2))
# Do not hide findings behind a successful shell status.
raise SystemExit(0 if all(r['expectation_met'] for r in rows) else 1)
