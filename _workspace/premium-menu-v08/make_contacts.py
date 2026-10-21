"""Create inspection sheets from exported PNGs without altering source files."""
from pathlib import Path
import json,math,textwrap
from PIL import Image,ImageDraw,ImageFont
TASK=Path(__file__).resolve().parent
spec=json.loads((TASK/'scene-spec.json').read_text());records=json.loads((TASK/'export-records.json').read_text())
by_name={r['name']:r for r in records.get('scenes',[])}
out=TASK/'review-sheets';out.mkdir(exist_ok=True)
font_path=Path('/System/Library/Fonts/AppleSDGothicNeo.ttc')
font=ImageFont.truetype(str(font_path),18) if font_path.exists() else ImageFont.load_default()
index=[]
def sheet(filename,items,cols=3,width=640):
 height=round(width*9/16);cellh=height+56;rows=math.ceil(len(items)/cols)
 if not items:return
 canvas=Image.new('RGB',(cols*width,rows*cellh),'#10181C');draw=ImageDraw.Draw(canvas)
 for i,(name,record) in enumerate(items):
  path=TASK/'exports'/record['filename']
  if not path.exists():continue
  with Image.open(path) as image:
   image=image.convert('RGB');image.thumbnail((width,height),Image.Resampling.LANCZOS);canvas.paste(image,((i%cols)*width,(i//cols)*cellh))
  label=f'{i+1:02}  {name}'
  label=label.replace('MENU08 / ','').replace('SCR_','').replace('EXT_','').replace('CBT_','')
  for j,line in enumerate(textwrap.wrap(label,52 if width>=600 else 38)[:2]):draw.text(((i%cols)*width+8,(i//cols)*cellh+height+3+j*22),line,font=font,fill='#BBC6C6')
  index.append({'sheet':filename,'cell':i+1,'scene':name,'file':record['filename']})
 canvas.save(out/filename)
base=[(n,by_name[n]) for n in spec['base'] if n in by_name]
sheet('base-14.png',base)
states=[(s['name'],by_name[s['name']]) for s in spec['scenes'] if s['name'] not in spec['base'] and s['name'] in by_name]
for start in range(0,len(states),20):sheet(f'states-{start//20+1:02}.png',states[start:start+20],4,480)
wide=[(r['name'],r) for r in records.get('comparisons',[])]
sheet('wide-5.png',wide,1,1600)
(out/'index.json').write_text(json.dumps(index,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'base':len(base),'states':len(states),'wide':len(wide),'sheets':len(set(x['sheet'] for x in index))},ensure_ascii=False))
