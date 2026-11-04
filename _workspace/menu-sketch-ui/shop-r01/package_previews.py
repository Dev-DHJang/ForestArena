from pathlib import Path
import json,hashlib
from PIL import Image,ImageDraw,ImageFont
P=Path(__file__).resolve().parent;D=P/'exports';j=json.loads((P/'scene-spec.json').read_text());keys=j['base_keys']
for k in keys:
 im=Image.open(D/(k+'.png')).convert('RGB');assert im.size==(1920,1080);im.resize((1280,720),Image.Resampling.LANCZOS).save(D/(k+'-1280.png'))
font=ImageFont.truetype('/System/Library/Fonts/AppleSDGothicNeo.ttc',28);out=Image.new('RGB',(1280,772*5),'#10181C');draw=ImageDraw.Draw(out)
for i,(k,title) in enumerate(zip(keys,['상점 · 캐릭터','상점 · 신기 목록','상점 · 신기 상세','상점 · 조약돌','상점 · 무지개돌'])):
 y=i*772;draw.text((24,y+10),title+' · shop-r01 · 검토 대기',font=font,fill='#D9C58E');out.paste(Image.open(D/(k+'-1280.png')),(0,y+52))
out.save(D/'shop-review.png')
records=[]
for f in sorted(D.glob('*.png')):
 with Image.open(f) as im:w,h=im.size
 src='actual newly opened Penpot viewer screenshot' if f.name.startswith('viewer-') else 'LANCZOS reduction of native export' if '-1280' in f.name else 'contact sheet of five native reductions' if f.stem=='shop-review' else 'actual Penpot native board export'
 records.append(dict(file='exports/'+f.name,width=w,height=h,bytes=f.stat().st_size,sha256=hashlib.sha256(f.read_bytes()).hexdigest(),source=src))
(P/'export-index.json').write_text(json.dumps(dict(native_boards=73,native_exports=19,images=records),ensure_ascii=False,indent=2)+'\n');print('PNG',len(records),'native19; reduced5; contact1; viewer',sum(r['file'].startswith('exports/viewer-') for r in records))
