from pathlib import Path
import hashlib,json
from PIL import Image
ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).resolve().parent
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
b=json.loads((OUT/'baseline-90.json').read_text())
for r in [b['manifest'],b['appearance_contract']]+[f for m in b['motions']+b['reference_motions'] for f in (m['runtime'],m['sprite_frames'])]:
 assert sha(ROOT/r['path'])==r['sha256'],r['path']
s=json.loads((OUT/'review-selection.json').read_text())
for row in s['samples']:
 for r in row['files']:assert sha(ROOT/r['path'])==r['sha256'],r['path']
 p=ROOT/row['current_review_sheet'];im=Image.open(p);assert im.mode=='RGBA' and im.size==(512,512)
 fs=[im.crop(((i%4)*128,(i//4)*128,(i%4+1)*128,(i//4+1)*128)) for i in range(16)]
 assert len({hashlib.sha256(f.tobytes()).hexdigest() for f in fs})==16
 assert im.getchannel('A').getextrema()[0]==0
 g=Image.open(ROOT/row.get('current_review_gif',str(Path('_workspace/title-loading-proportions/character-review')/row['character_id']/'idle-review.gif')));assert g.n_frames==16
print('HEAD_WIDTH_EDIT_REVIEW_R02: PASS; 90 target and 30 reference runtime PNG/SpriteFrames + manifest + appearance unchanged; active r02 sample hashes and RGBA sheets verified.')
