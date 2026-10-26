"""Independent check of exact planned runtime installation, without writes to assets."""
from pathlib import Path
import hashlib,json
R=Path(__file__).resolve().parents[3]
Q=Path(__file__).resolve().parent
B=Q.parent
read=lambda p:json.loads(p.read_text())
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
before=read(Q/'installed-pilot-before-r01.json')
plan=read(B/'registration-plan.json')['plan']
manifest=read(R/'assets/character/manifest.json')
catalog=read(B/'candidate-catalog.json')
checks=[]
def ck(value,label):
 checks.append({'label':label,'pass':bool(value)})
 if not value: print('FAIL',label)

def key(row):return row.get('character_id'),row.get('visual_state_id')
old={key(r):r for r in before['manifest']['assets'] if r.get('type')=='animation-runtime'}
new={key(r):r for r in manifest['assets'] if r.get('type')=='animation-runtime'}
candidates={key(r):r for r in catalog['assets']}
outputs={r['path'] for r in plan['outputs']}
for out in plan['outputs']:
 ck((R/out['path']).is_file() and sha(R/out['path'])==out['after_sha256'],'planned exact output: '+out['path'])
for path,digest in before['protected_files'].items():
 if path not in outputs:
  ck((R/path).is_file() and sha(R/path)==digest,'unrelated approved file unchanged: '+path)
selected={(r['character_id'],r['motion']) for r in plan['motions']}
ck(len(manifest['assets'])==len(before['manifest']['assets'])+1,'exactly one new manifest asset')
ck(len(new)==len(old)+1,'exactly one new runtime motion')
ck(set(new)-set(old)=={('ja-hyun','attack_light_combo_04')},'only new motion is Ja-Hyun finisher')
for row in before['manifest']['assets']:
 if row.get('type')!='animation-runtime' or key(row) not in selected:
  ck(row in manifest['assets'],'unrelated manifest entry preserved: '+row.get('asset_id',''))
fields=('frame_count','atlas_columns','cell_size','frame_durations','fps','loop','phase_frame_ranges','jump_frame_ranges','descent_frame_range','landing_frame_range','landing_down_frame_range','run_stride_px','frame_anchors','presentation_scale','foot_pivot_y','state_hold_frame')
for target in plan['motions']:
 k=target['character_id'],target['motion']; entry=new[k]; source=candidates[k]
 ck(entry['asset_id']==target['asset_id'],'stable logical ID: '+str(k))
 ck(entry['consumer_path']==entry['sprite_frames_path']==target['sprite_frames_path'],'stable consumer path: '+str(k))
 ck((R/entry['path']).read_bytes()==(R/source['path']).read_bytes(),'installed bytes equal approved candidate: '+str(k))
 for f in fields:
  ck(entry.get(f)==source.get(f),'display metadata preserved '+str(k)+' '+f)
 ck(entry['motion_registration']['approval_record']=='_workspace/motion-naturalness-v1/user-motion-registration-approval.json','explicit approval linked: '+str(k))
 if k in old:
  ck(old[k]['asset_id']==entry['asset_id'],'existing ID unchanged: '+str(k))
  ck(old[k]['sprite_frames_path']==entry['sprite_frames_path'],'existing SpriteFrames consumer unchanged: '+str(k))
  ck((R/old[k]['path']).is_file() and sha(R/old[k]['path'])==old[k]['sha256'],'original approved PNG remains intact: '+str(k))
 if k[1]=='jump':ck(entry['frame_count']==24,'expanded jump actually declares 24: '+str(k))
report={'kind':'independent-installed-pilot-static-qa','checks':len(checks),'failures':[r for r in checks if not r['pass']],'results':checks,'manifest_sha256':sha(R/'assets/character/manifest.json'),'plan_sha256':sha(B/'registration-plan.json'),'before_git_head':before['git_head'],'android_device_test':False}
(Q/'installed-pilot-static-r01.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(f"INSTALLED_PILOT_STATIC: {'PASS' if not report['failures'] else 'FAIL'} ({len(checks)} checks)")
raise SystemExit(bool(report['failures']))
