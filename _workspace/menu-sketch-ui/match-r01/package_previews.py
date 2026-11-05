from pathlib import Path
import json,hashlib
from PIL import Image,ImageDraw,ImageFont
P=Path(__file__).resolve().parent;D=P/'exports';j=json.loads((P/'scene-spec.json').read_text());keys=j['base_keys']
for k in keys:
 im=Image.open(D/(k+'.png')).convert('RGB');assert im.size==(1920,1080);im.resize((1280,720),Image.Resampling.LANCZOS).save(D/(k+'-1280.png'))
out=Image.new('RGB',(1280,772*3),'#10181C');draw=ImageDraw.Draw(out);font=ImageFont.truetype('/System/Library/Fonts/AppleSDGothicNeo.ttc',28)
for i,(k,title) in enumerate(zip(keys,['일반대전 선택 · 3개 진입','방 목록 · 선택·필터·코드','랭킹 로비 · 등급 예시·미정 기능'])):
 y=i*772;draw.text((24,y+10),title+' · match-r01 검토 대기',font=font,fill='#D9C58E');out.paste(Image.open(D/(k+'-1280.png')),(0,y+52))
out.save(D/'match-review.png')
records=[]
for f in sorted(D.glob('*.png')):
 with Image.open(f) as im:w,h=im.size
 source='actual Penpot viewer screenshot' if f.name.startswith('viewer-') else 'LANCZOS reduction of native export' if '-1280' in f.name else 'contact sheet of three native reductions' if f.stem=='match-review' else 'actual Penpot native board export'
 records.append(dict(file='exports/'+f.name,width=w,height=h,bytes=f.stat().st_size,sha256=hashlib.sha256(f.read_bytes()).hexdigest(),source=source))
(P/'export-index.json').write_text(json.dumps(dict(native_boards=51,native_exports=len(json.loads((P/'export-selection.json').read_text())),images=records),ensure_ascii=False,indent=2)+'\n');print('PNG',len(records))
