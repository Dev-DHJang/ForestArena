"""내보낸 화면을 검토용 시트로 모으고 조작 영역을 수치 대조한다."""
import csv
import json
from pathlib import Path
from PIL import Image, ImageDraw

folder=Path(__file__).resolve().parent
rows=[('move_4way',152,690,320,320,8,'left-bottom'),('light',1584,804,176,176,4,'right-bottom'),('heavy',1408,648,144,144,4,'right-bottom'),('special',1616,616,144,144,4,'right-bottom'),('jump',1384,872,128,128,4,'right-bottom'),('dash',1200,848,120,120,4,'right-bottom')]
result=[]
for name,x,y,w,h,expand,anchor in rows:
 result.append(dict(control=name,x=x,y=y,width=w,height=h,touch_x=x-expand,touch_y=y-expand,touch_width=w+2*expand,touch_height=h+2*expand,anchor=anchor,logical_x=round(x*2/3,3),logical_y=round(y*2/3,3),logical_width=round(w*2/3,3),logical_height=round(h*2/3,3)))
with (folder/'touch-layout.csv').open('w') as f:
 writer=csv.DictWriter(f,fieldnames=result[0].keys(),lineterminator='\n');writer.writeheader();writer.writerows(result)
overlaps=[];outside=[]
for i,a in enumerate(result):
 x,y,w,h=(a[k] for k in ['touch_x','touch_y','touch_width','touch_height'])
 if not (x>=125 and y>=54 and x+w<=1795 and y+h<=1026):outside.append(a['control'])
 for b in result[i+1:]:
  bx,by,bw,bh=(b[k] for k in ['touch_x','touch_y','touch_width','touch_height'])
  if min(x+w,bx+bw)>max(x,bx) and min(y+h,by+bh)>max(y,by):overlaps.append([a['control'],b['control']])
paths=sorted((folder/'exports').glob('*.png'))
for start in range(0,len(paths),6):
 sheet=Image.new('RGB',(1920,1740),'#dfe9df');draw=ImageDraw.Draw(sheet)
 for i,p in enumerate(paths[start:start+6]):
  im=Image.open(p).convert('RGB');im.thumbnail((960,540));x=(i%2)*960;y=(i//2)*580
  draw.text((x+12,y+8),p.stem,fill='black');sheet.paste(im,(x,y+32))
 sheet.save(folder/'exports'/f'review-{start//6+1:02}.jpg')
size_checks=[]
for scale in [.85,1.0,1.1]:
 boxes=[]
 for name,x,y,w,h,expand,anchor in rows:
  sw,sh=w*scale,h*scale
  # 왼쪽 또는 오른쪽 변과 아래쪽 변을 유지한다. 자유 이동이 아니다.
  sx=x if anchor=='left-bottom' else x+w-sw
  sy=y+h-sh
  boxes.append((name,sx-expand,sy-expand,sw+2*expand,sh+2*expand))
 clipped=[n for n,x,y,w,h in boxes if x<125 or y<54 or x+w>1795 or y+h>1026]
 collisions=[]
 for i,(n,x,y,w,h) in enumerate(boxes):
  for m,bx,by,bw,bh in boxes[i+1:]:
   if min(x+w,bx+bw)>max(x,bx) and min(y+h,by+bh)>max(y,by):collisions.append([n,m])
 size_checks.append({'scale':scale,'outside':clipped,'overlap':collisions})
audit={'export_count':len(paths),'export_names':[p.stem for p in paths], 'control_touch_overlap':overlaps,'control_outside_safe_area':outside,'anchored_size_checks':size_checks,'android_device_tested':False,'note':'수치 대조와 정적 PNG는 실제 멀티터치·카메라 동작 검증을 대신하지 않는다.'}
(folder/'geometry-audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:v for k,v in audit.items() if k!='export_names'},ensure_ascii=False))
