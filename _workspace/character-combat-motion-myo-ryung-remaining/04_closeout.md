# 묘령 잔여 전투 모션 종료 증적

## 현재 상태

- batch-01 일반 지상 공격 5종의 true-alpha r01 검토 시안, 128×128 미리보기, 프롬프트와 SHA-256을 기록했다.
- 2026-09-12: 이미지 생성 차단 해제 후 내장 도구로 각 체크무늬 원본의 배경만 alpha 처리했다.
- 2026-09-13 사용자 승인: batch-01의 `attack_light_up`, `attack_light_down`, `attack_heavy_side`, `attack_heavy_up`, `attack_heavy_down` r01 검토 시안을 승인했다.
- 2026-09-13: batch-02의 `attack_dash_light`, `attack_dash_heavy`, `attack_air_light`, `attack_air_heavy` r01 검토 시안과 품질 확인 기록을 만들었다.
- 2026-09-13 사용자 승인: batch-02의 `attack_dash_light`, `attack_dash_heavy`, `attack_air_light`, `attack_air_heavy` r01 검토 시안을 승인했다.
- 2026-09-13: batch-03의 `special_neutral`, `special_up` r01 검토 시안과 품질 확인 기록을 만들었다.
- 2026-09-14: 11개 clean PNG의 파일명·PNG 디코딩·RGBA·실제 alpha를 다시 확인했고, `./scripts/verify-docs.sh`와 `./scripts/verify.sh`가 통과했다.
- 2026-09-14 사용자 승인: batch-03의 `special_neutral`, `special_up` r01 검토 시안을 승인했다.
- 완료: `myo_ryung_moveset.tres`에 정의된 대상 11종의 검토 PNG, 128×128 미리보기, 프롬프트, SHA-256과 QA 기록을 모두 남겼다.
- 후속 범위: 승인 시안의 2048×128 런타임 정규화, SpriteFrames·manifest 등록과 전투 연결은 별도 요청으로 진행한다.
- 변경하지 않음: `assets/character/` 런타임 경로, manifest, SpriteFrames, CharacterData, MoveSetData, AttackData, 전투 코드, 판정, Android 설정.
