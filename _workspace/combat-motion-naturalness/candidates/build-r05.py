"""자현 특수기의 기존 PNG와 시간을 보존하는 공통 배율 후보 추가."""
from pathlib import Path
import copy,hashlib,json,shutil
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
catalog=json.loads((OUT/'catalog-r04.json').read_text())
manifest=json.loads((ROOT/'assets/character/manifest.json').read_text())
row=copy.deepcopy(next(a for a in manifest['assets'] if a.get('character_id')=='ja-hyun' and a.get('visual_state_id')=='special_scarf_sweep'))
original=copy.deepcopy(row)
for k in ['motion_registration','registration_history','status','consumer_path','layout_revision']:row.pop(k,None)
png=OUT/'ja-hyun-special_scarf_sweep-r01.png';tres=png.with_suffix('.tres')
shutil.copy2(ROOT/original['path'],png)
tres.write_text((ROOT/original['sprite_frames_path'].removeprefix('res://')).read_text().replace('res://'+original['path'],'res://'+str(png.relative_to(ROOT))))
row.update(type='animation-candidate',asset_id='ja-hyun-special-scarf-sweep-naturalness-r01',layout_only_from_asset_id=original['asset_id'],path=str(png.relative_to(ROOT)),sprite_frames_path='res://'+str(tres.relative_to(ROOT)),sha256=sha(png),presentation_scale=original['presentation_scale']*1.18,expected_action='전투 대기와 같은 체형 크기로 목도리를 준비하고 연속 휘두르기 뒤 회수한다. 준비/종료 때 얼굴·머리 크기가 줄었다 커지지 않는다.',action_source='docs/gameplay/two-fighter-combat-v2.md')
catalog['assets'].append(row)
p=OUT/'catalog-r05.json';p.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')
(OUT/'scope-r05.json').write_text(json.dumps({'schema_version':1,'kind':'candidate-motion-review','catalog_sha256':sha(p),'motions':[{'character_id':r['character_id'],'motion':r['visual_state_id']} for r in catalog['assets']]},ensure_ascii=False,indent=2)+'\n')
