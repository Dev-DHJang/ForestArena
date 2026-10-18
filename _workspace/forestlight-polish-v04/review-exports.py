from pathlib import Path
from PIL import Image,ImageDraw
import json,hashlib
root=Path(__file__).resolve().parent
paths=sorted(p for p in (root/'exports').glob('*.png') if p.stem.startswith(('SCR_','CBT_','EXT_','STATE_','CMP20')))
for start in range(0,len(paths),6):
 sheet=Image.new('RGB',(1920,1740),'#DCE8DA');draw=ImageDraw.Draw(sheet)
 for i,p in enumerate(paths[start:start+6]):
  im=Image.open(p).convert('RGB');im.thumbnail((960,540));x=i%2*960;y=i//2*580
  draw.text((x+12,y+8),p.stem,fill='#183D35');sheet.paste(im,(x,y+32))
 sheet.save(root/'exports'/f'review-{start//6+1:02}.jpg')
rows=[{'file':str(p.relative_to(root)),'width':Image.open(p).width,'height':Image.open(p).height,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in paths]
(root/'export-manifest.json').write_text(json.dumps({'count':len(rows),'screens':rows},indent=2)+'\n')
print({'exports':len(paths),'review_sheets':(len(paths)+5)//6})
