# 나비 v06 모션 시안 제작

## 제작 기준

- 참조: 사용자 제공 `nabi-concept-v01` 교체 콘셉트.
- 모든 시안은 우향·전신·4×4 16포즈·실제 RGBA 알파를 요구했다.
- 외형 고정: 짙은 귀 2개, 짙은 꼬리 1개, 보라빛 흑발, 보라·검정·흰 의상, 방울·리본·고양이/발바닥 표식, 보라 발톱.
- 시안은 런타임 경로가 아닌 `01_drafts/`에만 저장했다.

## 시안 목록

- 기본: `idle`, `run`, `jump`
- 지상 공격: `attack_light_combo_01`, `attack_light_combo_02`, `attack_light_up`, `attack_light_down`, `attack_heavy_charge`, `attack_heavy_side`, `attack_heavy_up`, `attack_heavy_down`, `attack_dash_light`, `attack_dash_heavy`
- 공중·특수: `attack_air_light`, `attack_air_heavy`, `special_neutral`, `special_side`, `special_up`, `special_down`
- 상태·연출: `guard`, `evade`, `hitstun`, `launch`, `knock_down`, `wake_up`, `death`, `spawn`, `ring_out`, `ultimate`

29개 고유 시안으로 31개 물리 PNG를 교체한다. 기존 `attack_light_combo_01/02`의 일반 경로와 `local_ai_v01` 경로는 각각 같은 이름의 승인 시안을 사용한다.

## 승인 뒤 처리

사용자가 목록의 모든 모션을 명시 승인하면 기존 v01 PNG를 같은 경로에서 128×128 셀·2048×128 런타임 시트로 정규화하고, 각 manifest 해시와 기존 SpriteFrames 연결을 검증한다.
