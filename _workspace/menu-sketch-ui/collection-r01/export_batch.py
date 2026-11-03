"""Export reference screens and distinct visual states; native prototype holds all46 boards."""
from pathlib import Path
import json,subprocess,sys,time
P=Path(__file__).resolve().parent
keys=['collection-home','collection-stats','skills-light','skills-heavy','skills-jump-light','skills-jump-heavy','skills-special','story-1','story-2','artifact-all','artifact-defense','artifact-attack','artifact-equipped','artifact-empty','artifact-equip-confirm','artifact-all-yoyo','artifact-defense-yoyo','artifact-empty-yoyo','video-artifact-yoyo-equipped','video-loading','video-error','skills-light-wide','story-1-wide','artifact-all-wide','collection-handoff']
(P/'export-selection.json').write_text(json.dumps(dict(native_boards=46,export_keys=keys,reason='21 references require per-screen PNG; this batch exports all 3 reference screens, tab variants and distinct equipment/empty/loading/error states. Repeated modal underlays remain editable native boards with full native audit and actual viewer navigation evidence.'),ensure_ascii=False,indent=2)+'\n')
failed=[]
for k in keys:
 if (P/'exports'/(k+'.png')).exists():continue
 for attempt in range(2):
  r=subprocess.run([sys.executable,str(P/'export_png.py'),k],capture_output=True,text=True)
  if r.returncode==0:print(r.stdout.strip(),flush=True);break
  with (P/'export-errors.log').open('a') as f:f.write(k+' attempt '+str(attempt+1)+'\n'+r.stdout+r.stderr+'\n')
  print('retry' if attempt==0 else 'failed',k,flush=True)
 else:failed.append(k)
if failed:raise SystemExit('Failed exports '+str(failed))
