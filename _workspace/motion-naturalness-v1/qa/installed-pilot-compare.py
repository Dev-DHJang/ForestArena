"""Compare installed playback to independently reviewed candidate scenario evidence."""
import json,sys
from pathlib import Path
Q=Path(__file__).resolve().parent
old=json.loads(Path(sys.argv[1]).read_text()); new=json.loads(Path(sys.argv[2]).read_text())
R=Q.parents[2]
manifest=json.loads((R/'assets/character/manifest.json').read_text())
registered={(r['character_id'],r.get('visual_state_id',Path(r.get('sprite_frames_path','')).stem)):r for r in manifest['assets'] if r.get('type')=='animation-runtime'}
checks=[]
def ck(v,label): checks.append({'pass':bool(v),'label':label})
ck(not old['errors'] and not new['errors'],'both scenario runs have no errors')
ck(new.get('installed_runtime_without_injection') is True,'new playback uses actual installed resources')
ck(len(old['scenarios'])==len(new['scenarios'])==6,'six matching real-input clips')
for left,right in zip(old['scenarios'],new['scenarios']):
 name=left['name']; ck(name==right['name'],'same scenario '+name)
 ck(left['inputs']==right['inputs'],'same submitted inputs '+name)
 ck(left['attacks_seen']==right['attacks_seen'],'same actual attacks '+name)
 ck(len(left['states'])==len(right['states']),'same clip tick count '+name)
 for a,b in zip(left['states'],right['states']):
  label=name+' tick '+str(a['frame'])
  ck(a['match']==b['match'],'full combat snapshot unchanged '+label)
  ck(a['snapshot_unchanged'] and b['snapshot_unchanged'],'rendering remains read-only '+label)
  for olddraw,newdraw in zip(a['drawn'],b['drawn']):
   ck(all(newdraw[k]==v for k,v in olddraw.items()),'same shown pose, scale, root and facing '+label+' '+olddraw['fighter_id'])
   cid=right['character_id'] if newdraw['fighter_id']=='pilot-player' else ('nabi' if right['character_id']=='ja-hyun' else 'ja-hyun')
   actual=registered[cid,newdraw['shown_motion']]
   ck(newdraw['sprite_frames_path']==actual['sprite_frames_path'],'actual shown resource is installed consumer '+label+' '+newdraw['fighter_id'])
   ck(newdraw['atlas_path']=='res://'+actual['path'],'actual shown atlas is installed PNG '+label+' '+newdraw['fighter_id'])
report={'kind':'installed-vs-reviewed-candidate-playback','checks':len(checks),'failures':[x for x in checks if not x['pass']],'old_report':sys.argv[1],'installed_report':sys.argv[2],'results':checks}
out=Path(sys.argv[3]); out.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(f"INSTALLED_VS_REVIEWED: {'PASS' if not report['failures'] else 'FAIL'} ({len(checks)} checks; {len(report['failures'])} failures)")
for failure in report['failures'][:10]: print(failure)
raise SystemExit(bool(report['failures']))
