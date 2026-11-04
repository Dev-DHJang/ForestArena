from pathlib import Path
import json,subprocess,sys
P=Path(__file__).resolve().parent
keys=['shop-character-myo-ryung-light','shop-artifacts-all','shop-artifact-pebble-yoyo-from-all','shop-stone','shop-rainbow','shop-character-ja-hyun-light','shop-artifacts-attack','shop-artifacts-defense','shop-artifacts-special','shop-artifact-iron-armor-from-all','shop-artifact-boxing-gloves-from-all','shop-artifact-thorns-from-all','shop-character-myo-ryung-light-wide','shop-artifacts-all-wide','shop-rainbow-wide','shop-loading','shop-empty','shop-missing','shop-handoff']
(P/'export-selection.json').write_text(json.dumps(dict(native_boards=73,export_keys=keys,reason='All five reference screens, free/owned character, category lists, representative legacy details, loading/empty, guides and three20:9 comparisons. Shared overlay composition is verified by actual viewer screenshots rather than duplicated background exports.'),ensure_ascii=False,indent=2)+'\n')
failed=[]
for key in keys:
 if (P/'exports'/(key+'.png')).exists():continue
 for n in range(2):
  r=subprocess.run([sys.executable,str(P/'export_png.py'),key],capture_output=True,text=True)
  if not r.returncode:print(r.stdout.strip(),flush=True);break
  with (P/'export-errors.log').open('a') as f:f.write(key+' attempt '+str(n+1)+'\n'+r.stdout+r.stderr+'\n')
  print('retry' if n==0 else 'failed',key,flush=True)
 else:failed.append(key)
if failed:raise SystemExit('Export failures '+str(failed))
