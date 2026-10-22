# 대표 모션 등록 준비와 후속 26종 전달

2026-10-23. 대표 10종의 독립 QA는 완료했다. 사용자 모션별 승인과 실제 등록은 아직 없다. 이 문서는 승인 뒤 적용할 파일을 미리 확인한 결과다.

## 등록 전 점검

`python3 _workspace/motion-naturalness-v1/prepare-registration.py`는 현재 후보·QA·manifest에서 등록 대상을 만든 뒤 실제 등록 도구를 쓰기 없는 모드로 두 번 실행한다. 같은 입력에서 같은 계획이 나오는지, 승인 자산과 연결 파일 246개가 그대로인지, 새 런타임 PNG와 사용자 승인 기록이 생기지 않았는지 확인했다.

- 대상과 최종 경로: [registration-targets.json](registration-targets.json).
- 출력 파일별 변경 전·후 해시: [registration-plan.json](registration-plan.json).
- 점검 결과와 재현 명령: [qa/registration-plan-check-r01.json](qa/registration-plan-check-r01.json).
- 고정 계획 해시: `24877d86d3de0d531da75509f2ab1802521dc17653107be95569721846854669`.

기존 9종은 논리 ID와 SpriteFrames 소비 경로(게임에서 읽는 파일 위치)를 유지한다. 나비의 일부 파일은 기존 `runtime/local_ai_v01/` 경로를 그대로 쓴다. 자현의 `attack_light_combo_04`만 새 항목이다. 계획상 출력은 새 PNG 10개·SpriteFrames 10개·manifest 1개이며, 이전 승인 PNG는 덮어쓰거나 삭제하지 않는다. 실제로 이 출력 파일을 쓰지는 않았다.

점프 그림은 24장이지만 기존 논리 ID에 들어 있는 `16f` 문자열은 호환을 위해 유지한다. 그림 수는 `frame_count`와 새 파일 이름으로 구분한다. 후보 목록의 임시 ID를 그대로 복사해 기존 나비 올려할퀴기의 논리 ID를 바꾸지 않는다.

등록 도구는 현재 `explicit per-motion human approval record is missing`을 반환한다. 실제 사용자 메시지 없이 승인 기록을 만들거나 `--install`을 실행하지 않았다. 승인 뒤에도 후보·QA·대상 경로가 달라지면 계획과 해시를 다시 확인해야 한다. 등록 직전의 전체36종 구성에 따라 이 대표10종 계획을 최종 계획으로 다시 묶을 수 있으며, 이 준비 결과를 아직 만들지 않은26종의 승인으로 쓰지 않는다.

## 후속 26종

[remaining-motion-brief.json](remaining-motion-brief.json)은 기존 전체36종 범위에서 대표10종을 정확히 제외한 목록이다. 제작을 시작한 상태가 아니며, 대표 세트의 사용자 검토 뒤 진행한다. 새 그림 수는 16·24·32 중 실제 자세와 상태 수명에 맞춰 정한다.

두 캐릭터 공통으로 각각 9종이 남는다: `idle`, `guard`, `hitstun`, `launch`, `knock_down`, `wake_up`, `death`, `ring_out`, `spawn`.

| 캐릭터 | 남은 공격 모션 | 실제 준비/판정/회복 틱 |
| --- | --- | --- |
| 자현 | 공중 약 `attack_air_light` | 8/4/18 |
| 자현 | 공중 강 `attack_air_heavy` | 12/5/22 |
| 자현 | 지상 강 `special_neutral` | 12/5/20 |
| 자현 | 좌·우·위 특수 `special_scarf_sweep` | 12/60/24 |
| 나비 | 공중 약 `attack_air_light` | 8/4/18 |
| 나비 | 공중 강 `attack_air_heavy` | 12/5/22 |
| 나비 | 지상 강 `attack_heavy_up` | 12/5/20 |
| 나비 | 등 뒤 단타 특수 `special_side` | 10/24/20 |

공통 상태18종과 공격8종, 합계26종이다. 기술 이름은 실제 `AttackData`의 표시 ID다. 자현 지상 강의 기존 내부 ID인 `special_neutral`을 특수기 안무로 오해하지 않는다. 틱은 초당60회인 전투 시간이며, 그림 수 때문에 바꾸지 않는다. 새 판정 그림 수가 실제 판정 틱 수를 넘지 않도록 준비·회복에 필요한 중간 자세를 배분한다.

자현의 효과는 실제 메고 있는 승인 목도리 천을 쓴다. 새 리본이나 별도 목도리로 대체하지 않는다. 지상 강에는 `scarf_root`, 공중 약·강에는 `scarf_hand`, 좌·우·위 특수에는 `scarf_root`와 두 끝의 `scarf_tips`를 그림별로 맞춘다. 새로운 그림에 과거16개 부착점을 재사용하지 않는다.

후속 모션은 상태 진입·이탈과 피격·쓰러짐·일어남, 공중 강과 착지, 특수기의 시작·타격·회복을 실제 전투에서 확인한다. 전체 그림·정상·느린 재생·반전·소형 표시의 독립 QA와 사용자 모션별 승인을 각각 남긴다. 승인 후 등록, 리소스 검사, 같은 변경 버전의 LAN 확인, 최종 PR 검토·병합까지 남아 있다. Android 실기기 확인은 별도 미실행 항목이다.

## 승인이 필요한 근거

[애니메이션 스킬](../../.agents/skills/forest-arena-2d-animation/SKILL.md)의 “모션별 사용자 명시 승인 전에는 런타임 경로·manifest에 쓰지 않고”와 [모션 제작 원칙](../../docs/content/motion-action-review.md)의 “대표 세트의 기준을 먼저 맞추고 사용자 검토 뒤 나머지 실사용 모션에 적용한다”를 따른다. 일반적인 구현 계속 요청을 아직 보지 않은 개별 원화의 승인으로 기록하지 않는다.
