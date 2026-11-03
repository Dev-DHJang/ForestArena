from pathlib import Path
import json,hashlib
from PIL import Image,ImageDraw,ImageFont
P=Path(__file__).resolve().parent;D=P/'exports';keys=['skills-light','story-1','artifact-all']
for k in keys:
 im=Image.open(D/(k+'.png')).convert('RGB');assert im.size==(1920,1080);im.resize((1280,720),Image.Resampling.LANCZOS).save(D/(k+'-1280.png'))
font=ImageFont.truetype('/System/Library/Fonts/AppleSDGothicNeo.ttc',28)
out=Image.new('RGB',(1280,2316),'#10181C');draw=ImageDraw.Draw(out)
for i,(k,title) in enumerate(zip(keys,['캐릭터 기술 · collection-r01 · 검토 대기','캐릭터 스토리 · collection-r01 · 검토 대기','신기 상세 · collection-r01 · 검토 대기'])):
 y=i*772;draw.text((24,y+10),title,font=font,fill='#D9C58E');out.paste(Image.open(D/(k+'-1280.png')),(0,y+52))
out.save(D/'collection-review.png')
records=[]
for f in sorted(D.glob('*.png')):
 with Image.open(f) as im:size=im.size
 source='actual fresh Penpot viewer screenshot' if f.name.startswith('viewer-') else 'LANCZOS reduction of native export' if '-1280' in f.name else 'contact sheet of three native reductions' if f.stem=='collection-review' else 'actual Penpot native board export'
 records.append(dict(file='exports/'+f.name,width=size[0],height=size[1],bytes=f.stat().st_size,sha256=hashlib.sha256(f.read_bytes()).hexdigest(),source=source))
(P/'export-index.json').write_text(json.dumps(dict(native_boards=46,native_exports=25,images=records),ensure_ascii=False,indent=2)+'\n');print('PNG',len(records),'native25+small3+contact1+viewer12')
