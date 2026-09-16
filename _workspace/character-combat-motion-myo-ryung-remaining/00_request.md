# 묘령 잔여 전투 모션 검토 시안 요청

## 범위

- 기준: Phase 2 `assets/combat/movesets/myo_ryung_moveset.tres`, `docs/contracts/character-appearance-v01.json`, 승인 콘셉트 `myo-ryung-concept-v01`, 승인된 `attack_light_combo_01~04` 시트.
- 대상: 아직 시각 자산이 없는 `attack_light_up`, `attack_light_down`, `attack_heavy_side`, `attack_heavy_up`, `attack_heavy_down`, `attack_dash_light`, `attack_dash_heavy`, `attack_air_light`, `attack_air_heavy`, `special_neutral`, `special_up`.
- 산출: 우향, 좌→우·상→하 순서의 4×4·16포즈 transparent RGBA 검토 시트. 프레임은 연기용이며 실제 전투 타이밍과 판정을 정하지 않는다.

## 승인과 변경 금지 범위

- 일반 지상 5종 → 대시·공중 4종 → 특수기 2종 순으로 제작한다. 각 묶음의 모든 모션은 개별 사용자 승인 후에만 다음 묶음으로 진행한다.
- 검토 PNG·프롬프트·QA 증적만 포함한다. `assets/character/*/animation/runtime/`, manifest, SpriteFrames, CharacterData, MoveSetData, AttackData, 전투 코드와 판정은 변경하지 않는다.
- 외형은 은백색 머리, 긴 흰 토끼 귀 2개와 분홍색 안쪽, 인간형 손발, 분홍·흰 운동복, 큰 하이탑 운동화, 장미색 리본과 발차기 중심 자세를 유지한다.
- 토끼 주둥이·동물 얼굴·털 팔다리·paw 손발·역관절 다리·긴 꼬리·추가 귀·브랜드형 문양·상대·무기·문자·워터마크·판정/VFX는 금지한다. 작은 둥근 흰 토끼 꼬리는 측·후면에서만 허용한다.
