"""Create review sheets from unchanged real Godot captures and publish SHA-256."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import hashlib,json
ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).resolve().parent
FOLDER=HERE/'qa-captures'
OUT=HERE/'qa-review'
OUT.mkdir(exist_ok=True)
records=[]
for path in sorted(FOLDER.glob('*.png')):
    with Image.open(path) as image:
        records.append({'file':str(path.relative_to(ROOT)),'width':image.width,'height':image.height,
                        'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'bytes':path.stat().st_size,
                        'kind':'font_probe' if 'proof' in path.name else 'native_ui_capture',
                        'review':'pending'})
frames=[r for r in records if r['kind']=='native_ui_capture']
assert len(frames)==60, len(frames)
font=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',20)
contacts=[]
for start in range(0,len(frames),6):
    sheet=Image.new('RGB',(1920,792),'#283038')
    draw=ImageDraw.Draw(sheet)
    for index,record in enumerate(frames[start:start+6]):
        source=ROOT/record['file']
        with Image.open(source) as image:
            thumb=image.copy().convert('RGB')
            thumb.thumbnail((640,360))
            left=(index%3)*640; top=(index//3)*396
            sheet.paste(thumb,(left,top+32))
            draw.text((left+8,top+5),source.name,fill='#FFFFFF',font=font)
    path=OUT/f'contact-{start//6+1:02}.png'
    sheet.save(path)
    contacts.append({'file':str(path.relative_to(ROOT)),'frames':[r['file'] for r in frames[start:start+6]],'review':'pending'})
(HERE/'qa-capture-index.json').write_text(json.dumps({'source':'actual RenderingServer.frame_post_draw native Godot 4.7.1', 'ui_frames':60,'font_proofs':2,'files':records,'contacts':contacts},ensure_ascii=False,indent=2)+'\n')
print(f'Recorded {len(records)} real source images and {len(contacts)} review sheets.')
