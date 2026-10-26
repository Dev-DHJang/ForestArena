"""Run only the existing pure archive-verification function on disposable synthetic records."""
from pathlib import Path
from PIL import Image
import ast,json,gzip,hashlib,tempfile,copy
ROOT=Path(__file__).resolve().parents[4];OUTBASE=Path(__file__).resolve().parent
source=(OUTBASE/'input-r01/run.py').read_text();tree=ast.parse(source)
funcs=[x for x in tree.body if isinstance(x,ast.FunctionDef) and x.name in ['file_sha','verify_and_archive']]
ns={'Path':Path,'Image':Image,'gzip':gzip,'hashlib':hashlib};exec(compile(ast.Module(body=funcs,type_ignores=[]),'<isolated archive functions>','exec'),ns)
checks=[]
def marker(stamp,frame,slot,motion):
 b=[165,90,stamp&255,(stamp>>8)&255,frame,slot,{'launch':1,'jump':2}.get(motion,0),0]
 for v in b[:7]:b[7]^=v
 return b
def case_data(case_dir,variant):
 cap=[]
 for slot in [1,2]:
  chunks=[]
  poses=[(4,False,'launch'),(12,True,'launch'),(13,True,'launch'),(14,True,'launch'),(15,True,'launch'),(10,False,'jump')]
  if variant=='missing_pose14':poses.pop(3)
  for i,(frame,active,motion) in enumerate(poses):
   stamp=i+1;b=marker(stamp,frame,slot,motion);im=Image.new('RGBA',(640,480),(26,45,62,255))
   for k in range(64):
    color=(255,255,255,255) if b[k//8]&(1<<(k%8)) else (0,0,0,255)
    for x in range(4+k*2,6+k*2):
     for y in range(4,8):im.putpixel((x,y),color)
   data=im.tobytes();rawname=f'normal-client-{slot}.rgba';trace={'render_tick':i,'client_slot':slot,'snapshot_unchanged':True,'pixel_marker_verified':True,'frame_zero_based':frame,'release_active':active,'motion':motion,'draw_observation':{'sync_pose_matches_native_draw':True,'sync_stamp':stamp,'last_sync_packet':{'sync_stamp':stamp},'frame_zero_based':frame,'marker_bytes':b,'animation':motion,'flip_h':False}}
   if variant=='stale_pixels' and i==3:trace['draw_observation']['marker_bytes']=marker(stamp+1,frame,slot,motion);trace['draw_observation']['sync_stamp']=stamp+1;trace['draw_observation']['last_sync_packet']['sync_stamp']=stamp+1
   if variant=='wrong_trace_frame' and i==3:trace['frame_zero_based']=12
   if variant=='mutated_snapshot' and i==3:trace['snapshot_unchanged']=False
   cap.append({'client_slot':slot,'raw_path':rawname,'raw_offset':i*640*480*4,'byte_length':640*480*4,'size':[640,480],'render_tick':i,'trace':trace,'rgba_sha256':hashlib.sha256(data).hexdigest()});chunks.append(data)
  (case_dir/rawname).write_bytes(b''.join(chunks))
 return {'capture_manifest':cap,'target_character':'ja-hyun'}
with tempfile.TemporaryDirectory(dir=OUTBASE,prefix='synthetic-archive-') as temp:
 root=Path(temp);ns['OUT']=root
 for variant in ['valid','stale_pixels','wrong_trace_frame','missing_pose14','mutated_snapshot']:
  case=root/variant;case.mkdir();report=case_data(case,variant)
  try:result=ns['verify_and_archive'](report,'normal',case);accepted=True
  except AssertionError:accepted=False
  expected=variant=='valid';assert accepted==expected,(variant,accepted)
  checks.append({'variant':variant,'accepted':accepted,'expected_accepted':expected,'pass':True})
result={'status':'pass','cases':checks,'function_source':'input-r01/run.py:verify_and_archive + file_sha only','synthetic_records':True,'no_gui_no_ports':True,'temporary_fixture_files_removed':True,'scope':'Isolated archive guards, not real LAN/pixels or visual quality evidence.'}
(OUTBASE/'archive-guards-result-r01.json').write_text(json.dumps(result,indent=2)+'\n');print('ISOLATED_ARCHIVE_GUARDS_INDEPENDENT: PASS5cases (valid +4negative), no GUI/ports')
