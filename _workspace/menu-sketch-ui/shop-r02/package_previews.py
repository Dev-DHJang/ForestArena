from pathlib import Path
import json,hashlib
from PIL import Image,ImageDraw,ImageFont
P=Path(__file__).resolve().parent;D=P/'exports'
keys=['shop-characters-list','shop-character-myo-ryung-light','shop-character-ja-hyun-light','shop-character-yu-ran-light']
for k in keys:
 im=Image.open(D/(k+'.png')).convert('RGB');assert im.size==(1920,1080);im.resize((1280,720),Image.Resampling.LANCZOS).save(D/(k+'-1280.png'))
out=Image.new('RGB',(1280,1544),'#10181C');draw=ImageDraw.Draw(out);font=ImageFont.truetype('/System/Library/Fonts/AppleSDGothicNeo.ttc',28)
for i,(k,t) in enumerate(zip(keys[:2],['캐릭터 목록 · 카드 선택 → 해당 상세','선택 캐릭터 상세 · 뒤로 → 목록'])):
 y=i*772;draw.text((24,y+10),t+' · shop-r02 검토 대기',font=font,fill='#D9C58E');out.paste(Image.open(D/(k+'-1280.png')),(0,y+52))
out.save(D/'character-flow-review.png')
records=[]
for f in sorted(D.glob('*.png')):
 with Image.open(f) as im:w,h=im.size
 src='actual Penpot viewer screenshot' if f.name.startswith('viewer-') else 'LANCZOS reduction of native export' if '-1280' in f.name else 'contact sheet of native reductions' if f.stem=='character-flow-review' else 'actual Penpot native board export'
 records.append(dict(file='exports/'+f.name,width=w,height=h,bytes=f.stat().st_size,sha256=hashlib.sha256(f.read_bytes()).hexdigest(),source=src))
(P/'export-index.json').write_text(json.dumps(dict(native_boards=75,native_exports=8,images=records),ensure_ascii=False,indent=2)+'\n');print('PNG',len(records))
