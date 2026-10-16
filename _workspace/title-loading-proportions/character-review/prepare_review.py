"""Copy previously generated review candidates; compose review boards without editing sprite pixels."""
from pathlib import Path
from PIL import Image, ImageDraw
import json, hashlib, shutil, subprocess
ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).resolve().parent
PREV=Path('/Users/jdh/Desktop/workspace/ForestArena/_workspace/character-motion-proportion-unification')
if (OUT/'edits-r02/report.json').exists():
    raise SystemExit('Baseline already frozen; use verify_review.py for the active corrected selection.')
IDS=('ja-hyun','myo-ryung','nabi','yu-ran')
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def record(p): return {'path':str(p.relative_to(ROOT)),'sha256':sha(p)}
def copy(p,d):
 d.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(p,d); assert sha(p)==sha(d); return record(d)
def frames(path,strip=False):
 im=Image.open(path).convert('RGBA')
 return [im.crop((i*128,0,(i+1)*128,128)) if strip else im.crop(((i%4)*128,(i//4)*128,(i%4+1)*128,(i//4+1)*128)) for i in range(16)]
def matte(im,bg='#344154'):
 o=Image.new('RGBA',im.size,bg);o.alpha_composite(im);return o.convert('RGB')
def pack(fs):
 out=Image.new('RGBA',(512,512))
 for i,f in enumerate(fs):out.alpha_composite(f,((i%4)*128,(i//4)*128))
 return out
manifest=ROOT/'assets/character/manifest.json'
base={'git_head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'manifest':record(manifest),'appearance_contract':record(ROOT/'docs/contracts/character-appearance-v01.json'),'motions':[],'reference_motions':[]}
for a in json.loads(manifest.read_text())['assets']:
 if a['type']!='animation-runtime':continue
 row={'character_id':a['character_id'],'visual_state_id':a['visual_state_id'],'asset_id':a['asset_id'],'runtime':record(ROOT/a['path']),'sprite_frames':record(ROOT/a['sprite_frames_path'].removeprefix('res://')),'fps':a['fps'],'loop':a['loop'],'frame_count':a['frame_count']}
 if a['character_id']=='ja-hyun':base['reference_motions'].append(row)
 else:base['motions'].append(row)
assert len(base['motions'])==90 and len(base['reference_motions'])==30
(OUT/'baseline-90.json').write_text(json.dumps(base,ensure_ascii=False,indent=2)+'\n')
copy(PREV/'03_sample_approval.json',OUT/'provenance/previous-idle-approval.json')
copy(PREV/'03_landmarks.json',OUT/'provenance/previous-landmarks.json')
copy(PREV/'06_myo_ryung-style-locked/approval-proof-3.json',OUT/'provenance/previous-myo-style-approval.json')
copy(PREV/'06_myo_ryung-style-locked/landmarks-r01.json',OUT/'provenance/previous-myo-landmarks.json')
ref=ROOT/'assets/character/ja-hyun/animation/runtime/idle_16f.png'
copy(ref,OUT/'ja-hyun/idle-reference-16f.png')
after={'ja-hyun':frames(ref,True)}; before={cid:frames(ROOT/f'assets/character/{cid}/animation/runtime/idle_16f.png',True) for cid in IDS}
pack(after['ja-hyun']).save(OUT/'ja-hyun/idle-reference-4x4.png')
selection={'myo-ryung':(PREV/'06_myo_ryung-style-locked/04_review/idle/idle-r01-clean.png',PREV/'06_myo_ryung-style-locked/04_review/idle/idle-r01.gif',PREV/'06_myo_ryung-style-locked/03_alpha/idle-r01-alpha.png'),'nabi':(PREV/'03_sample_review/nabi/idle-proportion-r01-clean.png',PREV/'03_sample_review/nabi/idle-proportion-r01.gif',PREV/'02_samples/nabi/idle-r07-alpha.png'),'yu-ran':(PREV/'03_sample_review/yu-ran/idle-proportion-r01-clean.png',PREV/'03_sample_review/yu-ran/idle-proportion-r01.gif',PREV/'02_samples/yu-ran/idle-r05-alpha.png')}
rows=[]
for cid,(sheet,gif,source) in selection.items():
 dest=OUT/cid
 files=[copy(sheet,dest/'idle-review-4x4.png'),copy(gif,dest/'idle-review.gif'),copy(source,dest/'idle-source-alpha.png')]
 after[cid]=frames(dest/'idle-review-4x4.png'); after[cid][0].save(dest/'idle-preview-128.png')
 im=Image.open(dest/'idle-review-4x4.png');g=Image.open(dest/'idle-review.gif');dur=[]
 for i in range(g.n_frames):g.seek(i);dur.append(g.info['duration'])
 assert im.size==(512,512) and im.mode=='RGBA' and im.getchannel('A').getextrema()[0]==0
 assert len({hashlib.sha256(f.tobytes()).hexdigest() for f in after[cid]})==16
 assert g.n_frames==16 and sum(dur)==2000
 for f in after[cid]:
  assert f.getbbox() and f.getbbox()[0]>=2 and f.getbbox()[1]>=2 and f.getbbox()[2]<=126 and f.getbbox()[3]<=126
 rows.append({'character_id':cid,'state':'idle','status':'current-review-pending','prior_recorded_approval':'2026-10-15; hash-bound to copied records only; no new approval inferred','files':files,'original_source_path':str(source),'review_sha256':sha(dest/'idle-review-4x4.png'),'frames':16,'unique_frames':16,'gif_duration_ms':sum(dur),'source_bytes_preserved':True,'packing_note':'Existing review sheet and GIF copied byte-for-byte; no new scaling or image edit.'})
board=Image.new('RGB',(1100,720),'#1e2734');d=ImageDraw.Draw(board)
d.text((24,12),'Current develop Ja-Hyun reference / same 128px cells / no added sprite scale',fill='white')
for col,cid in enumerate(IDS):
 x=45+260*col;d.text((x,42),cid,fill='white')
 for y,fs,label in ((78,before[cid],'current runtime'),(370,after[cid],'selected review candidate')):
  d.text((x,y-20),label,fill='#b5c8e0');board.paste(matte(fs[0]).resize((256,256),Image.Resampling.NEAREST),(x,y))
board.save(OUT/'comparison-before-after.png')
for bg,name in (('#f2f4f7','light'),('#243044','dark')):
 strip=Image.new('RGBA',(512,128),bg)
 for col,cid in enumerate(IDS):strip.alpha_composite(after[cid][0],(col*128,0))
 strip.convert('RGB').save(OUT/f'same-size-128-{name}.png')
 strip.convert('RGB').resize((2048,512),Image.Resampling.NEAREST).save(OUT/f'same-size-4x-{name}.png')
# Larger first pose board is solely for reading visible anatomical landmarks.
strip=Image.new('RGBA',(512,128),'#344154')
for col,cid in enumerate(IDS):strip.alpha_composite(after[cid][0],(col*128,0))
strip.resize((4096,1024),Image.Resampling.NEAREST).convert('RGB').save(OUT/'landmark-inspection-8x.png')
(OUT/'review-selection.json').write_text(json.dumps({'status':'review-pending','samples':rows,'runtime_changed':False,'new_generation':False,'reference_idle_sha256':sha(ref),'full_joint_10_percent_compliance_proven':False},ensure_ascii=False,indent=2)+'\n')
print('CHARACTER_CURRENT_PROPORTION_REVIEW_R01: PASS: frozen 90 target + 30 reference runtime motions; 3 byte-identical copied candidate sheets; 48 unique RGBA frames; GIF 8 FPS; no runtime writes')
