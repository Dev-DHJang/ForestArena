"""검토된 후보의 등록 대상만 명시한다. 게임 파일에는 쓰지 않는다."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'_workspace/pebble-yoyo'

def main():
 catalog=json.loads((BASE/'candidate-catalog.json').read_text())
 rows=catalog['assets']
 expected={('ja-hyun','equipment_yoyo_ground'),('ja-hyun','equipment_yoyo_air'),('nabi','equipment_yoyo_ground'),('nabi','equipment_yoyo_air'),('nabi','idle')}
 if {(r['character_id'],r['visual_state_id']) for r in rows}!=expected:
  raise SystemExit('수정 요요4종과 나비 idle 보정의 정확한5개 검토 범위가 필요합니다.')
 current={(r.get('character_id'),r.get('visual_state_id')):r for r in json.loads((ROOT/'assets/character/manifest.json').read_text())['assets'] if r.get('type')=='animation-runtime'}
 targets=[]
 for r in rows:
  cid,motion=r['character_id'],r['visual_state_id'];n=r['frame_count'];runtime=f'assets/character/{cid}/animation/runtime'
  existing=current.get((cid,motion))
  targets.append({'character_id':cid,'motion':motion,'asset_id':existing['asset_id'] if existing else f'{cid}-{motion.replace("_","-")}-{n}f-v01',
   'png_path':f'{runtime}/{motion}_{n}f_'+('yoyo-anchor-v01' if existing else 'v01')+'.png',
   'sprite_frames_path':existing['sprite_frames_path'] if existing else f'res://{runtime}/{motion}.tres'})
 path=BASE/'registration-targets-r03.json'
 path.write_text(json.dumps({'schema_version':1,'kind':'motion-registration-targets','approval_record':'_workspace/pebble-yoyo/user-motion-approval-r03.json','motions':targets},ensure_ascii=False,indent=2)+'\n')
 print('등록 대상5개 작성; 게임 파일 변경 없음:',path)

if __name__=='__main__':main()
