# 묘령 전체 모션 등록 QA r01

## 결과

- 묘령 기본 MoveSet의 공격 표현은 18/18, 상태 표현은 13/13이다.
- 모든 신규 시트는 승인 원본을 보존한 채 16개 128×128 RGBA 셀과 2048×128
  runtime 시트로 정규화했다.
- 정규화 접촉 시트에서 긴 귀·발·리본 잘림과 이웃 셀 조각이 없는지 확인했다.
- 공격 준비·활성·회복은 기존 AttackData가 소유하며 모션 등록 전후 전투 판정은
  변경하지 않았다.

## 자동 검사

- Godot 전체 import: 통과.
- `character_motion_contract.gd`: 통과.
- `character_attack_motion_contract.gd`: 통과.
- `local_fighter_presentation.gd`: 통과.
- `verify-docs.sh`: 통과.
- Godot 리소스 검사: 논리 자산 345개 통과.
- 등록 도구 재실행: 신규 등록 0개로 끝나 중복 등록하지 않음을 확인했다.

## 남은 확인

- Android 에뮬레이터의 통합 재생은 나비 모션까지 등록한 뒤 최종 묶음에서 검사한다.
- 실제 Android 기기 재생과 성능은 사용자 지시에 따라 나중으로 미루며 미확인이다.
