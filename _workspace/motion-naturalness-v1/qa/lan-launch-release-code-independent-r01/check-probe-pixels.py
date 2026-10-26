from pathlib import Path
from PIL import Image
import json,hashlib,math
ROOT=Path(__file__).resolve().parents[4];BASE=ROOT/'_workspace/motion-naturalness-v1/qa/lan-launch-release-visual-r02';OUT=Path(__file__).resolve().parent
checks=[];records=[]
def ck(n,ok):checks.append({'check':n,'pass':bool(ok)});assert ok,n
def hashbytes(b):return hashlib.sha256(b).hexdigest()
def decode(im):
 return [sum(1<<bit for bit in range(8) if all(x>127 for x in im.getpixel((5+(byte*8+bit)*2,5))[:3])) for byte in range(8)]
for mode in ['fps60-r02','fps30-r02']:
 b=BASE/'drawstamp-probe-r01'/mode;r=json.loads((b/'report.json').read_text());previous=None;frame_records=[];active=[];stales=0
 for i,s in enumerate(r['samples']):
  path=b/s['file'];im=Image.open(path);ck(mode+' RGBA/size '+str(i),im.mode=='RGBA' and im.size==(384,256));data=decode(im);o=s['observed'];p=s['packet']
  ck(mode+' pixels equal native observation '+str(i),data==o['bytes']);ck(mode+' native equals sync packet '+str(i),o['frame']==p['frame'] and o['stamp']==p['stamp'] and o['animation']==p['animation'] and o['packet']==p)
  ck(mode+' marker identity '+str(i),data[:2]==[165,90] and data[2]+256*data[3]==o['stamp']%65536 and data[4]==o['frame'] and data[5]==1)
  xor=0
  for v in data:xor^=v
  ck(mode+' checksum '+str(i),xor==0)
  ck(mode+' pose/motion marker '+str(i),data[6]=={'launch':1,'jump':2}.get(o['animation'],0))
  ck(mode+' actual finite delta '+str(i),math.isfinite(p['dt']) and p['dt']>=0)
  if previous is not None:ck(mode+' old pixels reject current stamp '+str(i),previous!=data);stales+=1
  previous=data
  if p['release']:active.append(p['frame'])
  frame_records.append({'file':str(path.relative_to(ROOT)),'png_sha256':hashbytes(path.read_bytes()),'rgba_sha256':hashbytes(im.tobytes()),'decoded_marker':data})
 ordered=[v for i,v in enumerate(active) if i==0 or v!=active[i-1]]
 ck(mode+' exact reported release frames',active==r['release_frames'])
 ck(mode+' no clock stretch',4/60-1e-6<=r['release_end_elapsed']<=4/60+r['maximum_release_delta']+1e-6)
 ck(mode+' stale count honest',stales==r['stale_previous_rgba_rejections'])
 if mode=='fps60-r02':ck('60fps4pose pass',r['status']=='pass' and ordered==[12,13,14,15] and r['all_four_release_poses'])
 else:ck('30fps omission remains FIX',r['status']=='fix' and ordered==[12,13,15] and not r['all_four_release_poses'])
 records.append({'case':mode,'observed_status':r['status'],'unique_actual_release_frames':ordered,'clock_end_seconds':r['release_end_elapsed'],'maximum_actual_release_delta':r['maximum_release_delta'],'frames':frame_records})
# Reproduce current pre-guard lexical boundary, without opening/creating anything there.
workspace=str(ROOT/'_workspace')+'/'
traversal=workspace+'../outside-qa-placeholder'
ck('pre-guard client lexical prefix admits traversal',traversal.startswith(workspace) and not Path(traversal).resolve().is_relative_to(Path(workspace).resolve()))
ck('supported runner resolve guard rejects traversal',not Path(traversal).resolve().is_relative_to((ROOT/'_workspace').resolve()))
result={'status':'pass for offline pixel/clock checks; client entry guard separately needs fix','checks':checks,'checks_count':len(checks),'cases':records,'no_gui_no_ports':True,'pre_guard_path_counterexample':{'input':traversal,'prefix_passes':True,'canonical_outside_workspace':True},'probe_scope':'This redecodes existing GPU evidence. Probe directly uses three static Fixture helpers, with its own on_draw/on_post_draw wrappers. It does not execute the LAN on_sprite_draw/on_frame_post_draw callbacks.'}
(OUT/'probe-pixel-result-r01.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print('OFFLINE_PROBE_PIXELS_INDEPENDENT: PASS',len(checks),'checks;60pass/30FIX preserved; no GUI/ports')
