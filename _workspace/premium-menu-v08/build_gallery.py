"""Build a local review gallery and hash every exported Penpot PNG."""
from pathlib import Path
import json,hashlib,struct,html
TASK=Path(__file__).resolve().parent
spec=json.loads((TASK/'scene-spec.json').read_text())
records=json.loads((TASK/'export-records.json').read_text())
rows=[];problems=[];cards=[]
for section,key,expected in [('1280 × 720','scenes',(1280,720)),('1920 × 1080','designExports',(1920,1080)),('20:9 비교','comparisons',(1600,720))]:
 group=[]
 for record in records.get(key,[]):
  file=TASK/'exports'/record['filename']
  if not file.exists():problems.append('missing '+record['filename']);continue
  data=file.read_bytes();size=struct.unpack('>II',data[16:24])
  if size!=expected:problems.append('size '+record['filename'])
  row={'scene':record['name'],'file':'exports/'+record['filename'],'width':size[0],'height':size[1],'sha256':hashlib.sha256(data).hexdigest(),'bytes':len(data),'kind':key};rows.append(row)
  group.append('<figure><a href="'+html.escape(row['file'])+'"><img loading="lazy" src="'+html.escape(row['file'])+'" alt="'+html.escape(row['scene'])+'"></a><figcaption>'+html.escape(row['scene'])+'</figcaption></figure>')
 cards.append('<section><h2>'+section+'</h2><div class="grid">'+''.join(group)+'</div></section>')
summary={'expectedScenes':len(spec['scenes']),'export1280':len(records.get('scenes',[])),'export1920':len(records.get('designExports',[])),'comparisonCount':len(records.get('comparisons',[])),'errors':problems,'files':rows}
(TASK/'export-hashes.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
body='<!doctype html><html lang="ko"><meta charset="utf-8"><title>Forest Arena 메뉴 v08 출력 검토</title><style>body{font:16px system-ui;background:#10181c;color:#f2f3ed;margin:32px}h1{color:#d9c58e}h2{margin-top:48px}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(380px,1fr));gap:24px}figure{margin:0}img{width:100%;height:auto;border:1px solid #455455}figcaption{padding:8px 0;overflow-wrap:anywhere;color:#bbc6c6}</style><h1>Forest Arena · 메뉴 v08</h1><p>Penpot에서 내보낸 실제 화면입니다. 이미지를 누르면 원본 크기로 열립니다. 출력 수: '+str(summary['export1280'])+' / '+str(len(spec['scenes']))+' (1280), '+str(summary['export1920'])+' / '+str(len(spec['scenes']))+' (1920), 비교 '+str(summary['comparisonCount'])+' / 5. 시각·클릭·보존 검사의 최종 판정은 04_closeout.md를 확인합니다.</p>'+''.join(cards)+'</html>'
(TASK/'gallery.html').write_text(body)
print(json.dumps({k:v for k,v in summary.items() if k!='files'},ensure_ascii=False))
