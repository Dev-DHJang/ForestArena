"""명시 승인과 독립 QA의 고정 대상이 일치할 때만 네 후보를 등록한다."""
from pathlib import Path
import argparse,json,hashlib,sys,shutil
ROOT=Path(__file__).resolve().parents[2];BASE=ROOT/'_workspace/pebble-yoyo'
sys.path.insert(0,str(ROOT/'tools/forest_arena'))
from review_motion_actions import validate

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--approval',type=Path,required=True);args=ap.parse_args()
 approval=args.approval.resolve();record=json.loads(approval.read_text());catalog=BASE/'candidate-catalog.json';scope=BASE/'candidate-scope.json';review=BASE/'review-r03/motion-review.json'
 rows=json.loads(catalog.read_text())['assets'];keys=sorted(r['character_id']+'/'+r['visual_state_id'] for r in rows)
 if record.get('decision')!='approved' or not str(record.get('evidence','')).strip() or record.get('catalog_sha256')!=sha(catalog) or sorted(record.get('motion_keys',[]))!=keys:raise SystemExit('승인 대상·명시 발언·카탈로그 해시가 일치하지 않습니다.')
 errors=validate(ROOT,review,True,catalog,scope,None)
 if errors:raise SystemExit('\n'.join(errors))
 manifest_path=ROOT/'assets/character/manifest.json';manifest=json.loads(manifest_path.read_text());prepared=[]
 for row in rows:
  key=(row['character_id'],row['visual_state_id'])
  if any((a.get('character_id'),a.get('visual_state_id'))==key and a.get('type')=='animation-runtime' for a in manifest['assets']):raise SystemExit('기존 승인 모션 덮어쓰기 금지: '+str(key))
  dest=ROOT/'assets/character'/key[0]/'animation/runtime';png=dest/(key[1]+'_16f.png');tres=dest/(key[1]+'.tres')
  if png.exists() or tres.exists():raise SystemExit('기존 파일 덮어쓰기 금지: '+str(png))
  source_png=ROOT/row['path'];source_tres=ROOT/row['sprite_frames_path'][6:]
  text=source_tres.read_text().replace('res://'+row['path'],'res://'+str(png.relative_to(ROOT)))
  if '_workspace/' in text or sha(source_png)!=row['sha256']:raise SystemExit('후보 경로 또는 확인값 불일치')
  entry=dict(row,type='animation-runtime',asset_id=key[0]+'-'+key[1].replace('_','-')+'-16f-v01',path=str(png.relative_to(ROOT)),sprite_frames_path='res://'+str(tres.relative_to(ROOT)),consumer_path='res://'+str(tres.relative_to(ROOT)),source_paths=[row['path'],str(source_tres.relative_to(ROOT))],creation={'method':'built-in image_gen using approved v01 references; common scale0.32 and recorded translation; frames not individually rescaled'},rights={'basis':'Original AI-generated project motion using project-approved reference images'},approval={'status':'approved','record':str(approval.relative_to(ROOT)),'catalog_sha256':sha(catalog)},qa={'status':'pass','record':str(review.relative_to(ROOT)),'sha256':sha(review)})
  prepared.append((png,tres,source_png,text,entry))
 # Everything above is read-only preflight. All four share the exact reviewed scope.
 for png,tres,source_png,text,entry in prepared:
  png.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source_png,png);tres.write_text(text);manifest['assets'].append(entry)
 manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
 (BASE/'registration.json').write_text(json.dumps({'approval':str(approval.relative_to(ROOT)),'approval_sha256':sha(approval),'qa_sha256':sha(review),'registered':[p[4]['asset_id'] for p in prepared]},ensure_ascii=False,indent=2)+'\n')
 print('Registered4 explicitly approved and independently reviewed motions.')
if __name__=='__main__':main()
