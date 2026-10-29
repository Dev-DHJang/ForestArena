"""고정 크기 비교 카드: 대표, 현재 대기, 관찰의 양끝 문제 프레임."""
import json,sys
from pathlib import Path
from PIL import Image,ImageDraw
P=Path(__file__).resolve().parent;ROOT=P.parents[1]
sys.path.insert(0,str(ROOT/'tools/forest_arena'))
from audit_motion_consistency import composite
from motion_layout import layout,frame_box
review=json.load(open(P/'motion-review.json'));timeline=json.load(open(P/'timeline.json'))
bykey={(r['character_id'],r['motion']):r for r in timeline['motions']}
manifest=json.load(open(ROOT/'assets/character/manifest.json'))
entries={(r['character_id'],r['visual_state_id']):r for r in manifest['assets'] if r.get('type')=='animation-runtime'}
(P/'comparisons').mkdir(exist_ok=True)

def frame(cid,mid,number):
 row=entries[cid,mid];spec=layout(row);cell=Image.open(ROOT/row['path']).convert('RGBA').crop(frame_box(number-1,spec))
 samples=[s for v in bykey[cid,mid]['variants'] for s in v['samples']]
 sample=next((s for s in samples if s['frame']==number-1),None)
 if sample is None:return None
 return composite(cell,sample['sprite_scale'][0],sample['sprite_position'],sample['sprite_offset'])

for issue in review['findings']:
 cid=issue['character_id'];mid=issue['motion_id'];row=next(r for r in review['motions'] if r['character_id']==cid and r['motion_id']==mid)
 note=next(n for n in row['observations'] if n['finding_id']==issue['finding_id']);frames=note.get('comparison_frames',note['frames'])
 selected=[f for f in frames if frame(cid,mid,f) is not None]
 if not selected:selected=[s['frame']+1 for s in bykey[cid,mid]['variants'][0]['samples']]
 reference=Image.open(ROOT/'assets/character'/cid/'reference/v01/combat.png').convert('RGBA').resize((128,128),Image.Resampling.LANCZOS)
 ref=Image.new('RGBA',(160,160),'#9ca5ad');ref.alpha_composite(reference,(16,20))
 panels=[ref.convert('RGB'),frame(cid,'idle',1),frame(cid,mid,selected[0]),frame(cid,mid,selected[-1])]
 labels=['REFERENCE COMBAT 1/8','CURRENT IDLE F1',f'{mid} F{selected[0]}',f'{mid} F{selected[-1]}']
 board=Image.new('RGB',(1280,370),'#293440');draw=ImageDraw.Draw(board)
 draw.text((6,6),f'{cid} | {note["category"]} | {note["confidence"]} | all panels enlarged uniformly 2x; no pose fitting',fill='white')
 for i,(panel,label) in enumerate(zip(panels,labels)):
  draw.text((i*320+8,30),label,fill='white');board.paste(panel.resize((320,320),Image.Resampling.NEAREST),(i*320,50))
 board.save(P/'comparisons'/(issue['finding_id'].replace('/','--')+'.jpg'),quality=95)
