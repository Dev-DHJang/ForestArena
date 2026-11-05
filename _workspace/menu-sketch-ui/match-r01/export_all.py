from pathlib import Path
import json,subprocess,sys,time
P=Path(__file__).resolve().parent;log=[]
if (P/'export-attempts.json').exists():log=json.loads((P/'export-attempts.json').read_text())
for key in json.loads((P/'export-selection.json').read_text()):
 if (P/'exports'/(key+'.png')).exists() and (P/'exports'/(key+'.json')).exists():continue
 for attempt in range(1,4):
  r=subprocess.run([sys.executable,str(P/'export_png.py'),key],capture_output=True,text=True)
  log.append(dict(key=key,attempt=attempt,status='pass' if r.returncode==0 else 'failed',detail=r.stdout.strip() if r.returncode==0 else r.stderr[-800:]));(P/'export-attempts.json').write_text(json.dumps(log,ensure_ascii=False,indent=2)+'\n')
  if r.returncode==0:print(r.stdout.strip(),flush=True);break
  if 'http error' not in r.stderr or attempt==3:raise RuntimeError('Export failed; see export-attempts.json: '+key)
  print(key,'transient exporter HTTP failure; retrying only failed export',flush=True);time.sleep(2)
