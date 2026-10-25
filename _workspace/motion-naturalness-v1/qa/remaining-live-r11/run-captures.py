"""Fresh actual-render captures; archive only after per-frame lossless verification."""
from pathlib import Path
import subprocess,json,time
BASE=Path(__file__).resolve().parent
ROOT=BASE.parents[3]
assert (ROOT/'project.godot').is_file()
results=[]
try:
 for suffix,flags in [('normal',[]),('mirror-small',['--flip','--small'])]:
  for label,script,args,marker in [('state','render-state-transitions-r11.gd',[],'STATE_TRANSITIONS_LIVE_RENDER: PASS'),('ja-attacks','render-attacks-r11.gd',['--character','ja-hyun'],'PILOT_LIVE_RENDER: PASS'),('nabi-attacks','render-attacks-r11.gd',['--character','nabi'],'PILOT_LIVE_RENDER: PASS')]:
   name=label+'-'+suffix;out=BASE/name;assert not out.exists(),str(out)
   log=BASE/(name+'.log');assert not log.exists()
   command=['godot','--path',str(ROOT),'--rendering-method','gl_compatibility','--script','res://_workspace/motion-naturalness-v1/'+script,'--','--output','res://'+str(out.relative_to(ROOT)),*args,*flags]
   with log.open('w') as handle: p=subprocess.run(command,cwd=ROOT,stdout=handle,stderr=subprocess.STDOUT,timeout=600)
   text=log.read_text();report=json.loads((out/'state-report.json').read_text())
   assert p.returncode==0 and marker in text and report['errors']==[] and not any(s in text for s in ['SCRIPT ERROR','ERROR:','FAIL','Traceback']),name+' failed'
   archive_log=BASE/(name+'-archive.log')
   with archive_log.open('w') as handle: a=subprocess.run(['python3',str(BASE/'archive-raw.py'),str(out),'--remove-verified-raw'],cwd=ROOT,stdout=handle,stderr=subprocess.STDOUT,timeout=600)
   assert a.returncode==0 and not list(out.rglob('*.rgba')),name+' archive failed'
   results.append({'name':name,'status':'pass','checks':report['checks'],'frames':sum(s['frame_count'] for s in report['scenarios']),'clips':len(report['scenarios']),'raw_removed_after_verified_lossless_archive':True})
   print(name,results[-1],flush=True)
finally:
 (BASE/'run-report.json').write_text(json.dumps({'status':'pass' if len(results)==6 else 'incomplete','results':results,'scope':'actual rendered candidate gameplay, not independent visual verdict or device test'},indent=2)+'\n')
