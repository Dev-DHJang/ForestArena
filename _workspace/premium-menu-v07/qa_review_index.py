"""Independent QA contact sheets and image inventory; never changes producer files."""
from pathlib import Path
import hashlib,json
from PIL import Image,ImageDraw
TASK=Path(__file__).resolve().parent
records=json.loads((TASK/'export-records.json').read_text())
spec=json.loads((TASK/'scene-spec.json').read_text())
base=set(spec['base'])
entries=records['scenes']+records['comparisons']
out=TASK/'qa-review';out.mkdir(exist_ok=True)
prior={e['filename']:e for e in json.loads((out/'image-index.json').read_text())} if (out/'image-index.json').exists() else {}
index=[]
for i,r in enumerate(entries):
 p=TASK/'exports'/r['filename']
 im=Image.open(p);im.verify();im=Image.open(p)
 digest=hashlib.sha256(p.read_bytes()).hexdigest()
 reviewed=prior.get(r['filename'],{}).get('visually_reviewed',False) and prior.get(r['filename'],{}).get('sha256')==digest
 index.append({'index':i,'name':r['name'],'filename':r['filename'],'category':'comparison' if r in records['comparisons'] else 'base' if r['name'] in base else 'state','size':list(im.size),'recorded_size':r['outputSize'],'sha256':digest,'visually_reviewed':reviewed,'review_result':prior.get(r['filename'],{}).get('review_result','PASS') if reviewed else 'NOT-REVIEWED'})
for k in range(0,len(entries),6):
 canvas=Image.new('RGB',(1280,1176),'#10181C');draw=ImageDraw.Draw(canvas)
 for j,r in enumerate(entries[k:k+6]):
  x=(j%2)*640;y=(j//2)*392;im=Image.open(TASK/'exports'/r['filename']).convert('RGB');im.thumbnail((640,360));canvas.paste(im,(x+(640-im.width)//2,y))
  draw.text((x+8,y+364),f"{k+j:02d} {r['name']}"[:86],fill='#F2F3ED')
 canvas.save(out/f'contact-{k//6+1:02d}.png')
(out/'image-index.json').write_text(json.dumps(index,ensure_ascii=False,indent=2))
print(json.dumps({'images':len(index),'base':sum(x['category']=='base' for x in index),'states':sum(x['category']=='state' for x in index),'comparison':sum(x['category']=='comparison' for x in index),'sheets':(len(entries)+5)//6},ensure_ascii=False))
