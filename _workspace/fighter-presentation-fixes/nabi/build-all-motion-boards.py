"""Render unmodified candidate cells in uniform world-size comparison panels."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,math,hashlib
BASE=Path(__file__).resolve().parent;ROOT=BASE.parents[2];catalog=json.loads((BASE/'candidate-catalog-r01.json').read_text());out=BASE/'boards';out.mkdir(exist_ok=True);font=ImageFont.truetype('/System/Library/Fonts/Menlo.ttc',15);preview=Image.new('RGBA',(1800,900),(63,68,76,255));pd=ImageDraw.Draw(preview);files={}
for n,e in enumerate(catalog['assets']):
 count=e['frame_count'];src=Image.open(ROOT/e['path']).convert('RGBA');scale=e['presentation_scale'];board=Image.new('RGBA',(1200,300*math.ceil(count/4)),(72,77,85,255));draw=ImageDraw.Draw(board)
 for i in range(count):
  panel=(i%4*300,i//4*300);cell=src.crop((i%16*128,i//16*128,i%16*128+128,i//16*128+128));size=round(128*scale*2);cell=cell.resize((size,size),Image.Resampling.NEAREST)
  pivot=e.get('foot_pivot_y',128)
  anchors=e.get('frame_anchors',[])
  if len(anchors)==count and 'body_root' in anchors[i]:pivot=anchors[i]['body_root'][1]
  x=panel[0]+150-size//2;y=panel[1]+270-round(pivot*scale*2);board.alpha_composite(cell,(x,y));draw.text((panel[0]+8,panel[1]+6),f'{e["visual_state_id"]} F{i+1}',font=font,fill='white');draw.line((panel[0]+3,panel[1]+270,panel[0]+296,panel[1]+270),fill=(150,180,160))
  if i==0:
   px=n%6*300;py=n//6*300;preview.alpha_composite(cell,(px+150-size//2,py+270-round(pivot*scale*2)));pd.text((px+8,py+6),e['visual_state_id'],font=font,fill='white');pd.text((px+8,py+27),f'scale {scale:.4f}',font=font,fill='white');pd.line((px+3,py+270,px+296,py+270),fill=(150,180,160))
 p=out/(e['visual_state_id']+'.jpg');board.convert('RGB').save(p,quality=95);files[str(p.relative_to(ROOT))]=hashlib.sha256(p.read_bytes()).hexdigest()
p=BASE/'all18-model-size-overview.jpg';preview.convert('RGB').save(p,quality=95)
(BASE/'boards-proof-r01.json').write_text(json.dumps({'kind':'all-candidate-frame-boards','catalog_sha256':hashlib.sha256((BASE/'candidate-catalog-r01.json').read_bytes()).hexdigest(),'motions':18,'frames':312,'world_size_multiplier':2,'foot_or_body_root_attachment':'same metadata convention as public presentation','scope':'static source-cell boards; no combat or real-time playback claim','files':files},indent=2)+'\n')
print('18 world-size boards /312frames; overview prepared')
