"""생성 원화를 그대로 보존하고 균일 배율/중심 배치만 런타임 크기로 변환."""
from pathlib import Path
from PIL import Image
import hashlib,json,shutil
root=Path(__file__).resolve().parents[3]
here=Path(__file__).resolve().parent
sources=root/'assets/accessory/pebble-yoyo/source'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
records=[]
for name,size,target,logical in [('representative',1024,'pebble_yoyo.png','fa.accessory.pebble.yoyo'),('combat',128,'pebble_yoyo_combat.png','fa.accessory.pebble.yoyo.combat')]:
 src=here/f'{name}-source.png';saved=sources/f'{name}-r03.png';shutil.copyfile(src,saved)
 im=Image.open(src).convert('RGBA')
 if name=='combat':
  box=im.getchannel('A').point(lambda v:255 if v>32 else 0).getbbox()
  # Center the circular generated face. Do not warp or repaint it.
  cropped=im.crop(box);ratio=120/max(cropped.size);w,h=(round(x*ratio) for x in cropped.size)
  out=Image.new('RGBA',(128,128));out.alpha_composite(cropped.resize((w,h),Image.Resampling.LANCZOS),((128-w)//2,(128-h)//2))
 else:
  box=(0,0,*im.size);ratio=size/im.width
  out=im.resize((size,size),Image.Resampling.LANCZOS)
 dest=root/'forest_arena/assets/common/accessory'/target;out.save(dest)
 records.append({'id':logical,'source':str(saved.relative_to(root)),'source_sha256':sha(saved),'source_crop':list(box),'uniform_scale':ratio,'runtime_path':str(dest.relative_to(root)),'runtime_sha256':sha(dest),'runtime_size':list(out.size)})
p=root/'assets/accessory/pebble-yoyo/manifest.json';m=json.loads(p.read_text())
m['creation_method']='OpenAI built-in image_gen; user-requested round polished-pebble redesign r03; generated face-on combat disc, uniform resize and centering only'
m['revision_request']='2026-10-30: 조약돌 모양 개선과 원형 회전 표현'
for rec in records:
 for row in m['assets']:
  if row.get('id')==rec['id']:row['sha256']=rec['runtime_sha256'];row['source_path']=rec['source'];row['source_sha256']=rec['source_sha256']
 source_row={'type':'source','path':rec['source'],'sha256':rec['source_sha256']}
 existing=next((row for row in m['assets'] if row.get('type')=='source' and row.get('path')==rec['source']),None)
 if existing is None:m['assets'].append(source_row)
 else:existing.update(source_row)
p.write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n')
(here/'conversion.json').write_text(json.dumps({'method':'uniform resize, alpha-bounds crop/center only; generated RGBA preserved','assets':records},ensure_ascii=False,indent=2)+'\n')
print('Installed revised representative and centered circular combat disc')
