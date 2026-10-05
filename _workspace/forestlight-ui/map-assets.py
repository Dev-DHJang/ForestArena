"""기존 슬롯 ID를 유지하면서 실제 파일과 숲빛 대체 자산을 대조한다."""
import csv
import json
from pathlib import Path

root = Path(__file__).resolve().parents[2]
rows = list(csv.DictReader((root / 'assets/ui/asset-requirements.csv').open()))
registry = json.loads((root / 'forest_arena/data/resource_registry.json').read_text())['assets']
out = []
for row in rows:
    name = Path(row['output_path']).name
    matches = []
    for asset in registry:
        candidate = asset.get('variants', {}).get('high', asset.get('path', ''))
        if Path(candidate).name == name and (root / candidate.removeprefix('res://')).is_file():
            matches.append((asset['id'], candidate.removeprefix('res://')))
    slot = row['asset_slot']
    use = '기존 파일 있음 · 이 설계에서는 미사용'
    source = ''
    if slot in ['IMG/bg/splash', 'IMG/bg/lobby']:
        use = '승인 배경 재사용'
        source = matches[0][1]
    if slot.startswith('IMG/icon/'):
        source = f"assets/ui/forestlight-v01/icon-{slot.rsplit('/', 1)[1]}.svg"
        use = '새 숲빛 벡터로 디자인 대체 · 기존 ID 유지'
    if slot.startswith('IMG/char/mouse/'):
        source = 'assets/character/ja-hyun/concept/ja-hyun-concept-v01.png'
        use = '승인 자현 콘셉트 재사용 · bust/face 별도 원화 미사용'
    if slot.startswith('IMG/char/rabbit/'):
        source = 'assets/character/myo-ryung/concept/myo-ryung-concept-v01.png'
        use = '승인 묘령 콘셉트 재사용 · bust/face 별도 원화 미사용'
    if slot.startswith('IMG/char/roster/'):
        use = '신규 로스터 승인 전 · UI에 노출하지 않음'
    if slot.startswith('IMG/logo/'):
        use = '편집 가능한 FOREST ARENA 텍스트로 표시'
    out.append({'asset_slot':slot, 'legacy_output':row['output_path'], 'existing_id':matches[0][0] if matches else '', 'existing_file':matches[0][1] if matches else '', 'forestlight_use':use, 'design_source':source, 'file_missing':not bool(matches)})
dest = root / '_workspace/forestlight-ui/image-mapping.csv'
with dest.open('w') as f:
    w = csv.DictWriter(f,fieldnames=out[0].keys(),lineterminator='\n');w.writeheader();w.writerows(out)
(dest.parent / 'missing-assets.json').write_text(json.dumps({'legacy_slots':len(out),'missing_existing_files':[r['asset_slot'] for r in out if r['file_missing']], 'design_limitations':['자현 콘셉트는 검정 배경을 포함한다. 투명 컷아웃을 새로 제작하지 않았다.', '직업·경기장·Story 챕터의 확정 콘텐츠 원화는 미정이다. 의미 아이콘과 준비 중 표시를 사용한다.'], 'new_ui_assets':87},ensure_ascii=False,indent=2)+'\n')
print(f'{len(out)} original slots; {sum(r["file_missing"] for r in out)} missing existing files')
