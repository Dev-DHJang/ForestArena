# 자현 잔여 전투 모션 종료 증적

## 현재 상태

- 2026-09-12 사용자 승인: batch-01의 `attack_light_up`, `attack_light_down`, `attack_heavy_side`, `attack_heavy_up`, `attack_heavy_down` r01 검토 시안을 승인했다.
- 2026-09-12 사용자 승인: batch-02의 `attack_dash_light`, `attack_dash_heavy`, `attack_air_light`, `attack_air_heavy` r01 검토 시안을 승인했다.
- 2026-09-12 사용자 승인: batch-03의 `special_neutral`, `special_up` r01 검토 시안을 승인했다.
- 완료: 11종 전투 모션 검토 PNG, 모션별 프롬프트 기록, SHA-256, 128×128 축소 미리보기, 묶음별 QA 증적을 남겼다. `JA_HYUN_REMAINING_COMBAT_MOTION_REVIEW_R01`은 PASS다.
- 검증: `./scripts/verify.sh`를 실행하여 Forest Arena Phase 2 검증을 통과했다. Android 실제 기기 검증은 이번 검토 이미지 범위에서 미실행이며 통과로 기록하지 않는다.
- 후속 범위: 승인된 시안의 런타임용 2048×128 시트 정규화, SpriteFrames·manifest 등록은 별도 요청이다.
- 변경하지 않음: `assets/character/` 런타임 경로, manifest, SpriteFrames, CharacterData, MoveSetData, AttackData, 전투 코드, 판정, Android 설정.
