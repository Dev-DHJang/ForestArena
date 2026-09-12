# Forest Arena 리소스 규칙

- 밝은 판타지 숲, 조각 나무와 잎 UI, 비픽셀 아트 방향을 사용한다.
- `character/main` 아래의 주인공 토끼 파일은 정체성을 보존하는 기준 리소스다.
- 장신구에는 등급·희귀도·별 티어를 두지 않는다.
- 버튼·프레임의 일반 UI 문구는 네이티브 Godot 텍스트로 유지한다.
- 품질 디렉터리를 하드코딩하지 말고 `ForestArenaResources` 논리 ID를 사용한다.
- 전투와 비전투 UI의 배경·패널·버튼 이미지는 논리 ID로 조립한다. 승인 이미지가 없으면 식별 가능한 플레이스홀더를 등록하고 같은 ID로 최종 자산을 교체한다.
- 전투 전용 플레이스홀더 요구사항은 `assets/ui/combat-asset-requirements.csv`에서 비전투 61개 `IMG/*` 계약과 분리해 관리한다.
- 전투 HUD의 상태 계산과 전용 최종 원화 제작은 이 플레이스홀더 패키지 범위 밖이다.
- 카탈로그 변경 뒤 `python tools/forest_arena/verify_godot_resources.py --project-root .`로 registry·품질·Autoload를 검증한다.
