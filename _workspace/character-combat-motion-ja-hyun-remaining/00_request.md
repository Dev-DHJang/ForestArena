# 자현 잔여 전투 모션 검토 시안 요청

## 범위

- 기준: Phase 2 `assets/combat/movesets/ja_hyun_moveset.tres`, `docs/character-appearance-v01.json`, 승인 콘셉트 `ja-hyun-concept-v01`, 승인된 `attack_light_combo_01~03` 시트.
- 대상: 아직 시각 자산이 없는 `attack_light_up`, `attack_light_down`, `attack_heavy_side`, `attack_heavy_up`, `attack_heavy_down`, `attack_dash_light`, `attack_dash_heavy`, `attack_air_light`, `attack_air_heavy`, `special_neutral`, `special_up`.
- 산출: 우향, 좌→우·상→하 순서의 4×4·16포즈 transparent RGBA 검토 시트. 각 모션은 12 FPS one-shot 후보이며 이 프레임은 권위 전투 타이밍이 아니다.

## 승인·경계

- 일반 지상 5종 → 대시·공중 4종 → 특수기 2종 순으로 시안을 생성한다. 각 묶음은 모션별 사용자 명시 승인 후에만 다음 묶음으로 진행한다.
- 이번 요청은 검토 PNG·프롬프트·QA 증적까지만 포함한다. 승인 전후를 막론하고 `assets/character/*/animation/runtime/`, `assets/character/manifest.json`, SpriteFrames, CharacterData, MoveSetData, AttackData, 전투 코드 및 판정은 변경하지 않는다.
- 외형은 은백색 머리, 둥근 쥐 귀 2개, 가는 쥐 꼬리 1개, 인간형 손발, 흰색·검정·코발트 스트리트웨어와 긴 파란 리본을 유지한다. 동물 주둥이·털 팔다리·발·추가 꼬리·브랜드형 문양·상대 캐릭터·문자·워터마크·판정/VFX는 금지한다.
