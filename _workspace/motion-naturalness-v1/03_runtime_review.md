# 모션 표시 코드·등록 도구 검토

2026-10-22. 담당: motion_code_review. 작업 폴더는 PR109의 별도 작업 폴더만 사용했다. 원화 생성·사용자 승인 작성·실제 자산 등록·manifest 변경은 하지 않았다.

## 범위와 판정

`local_fighter_presentation.gd`, `fighter_attack_effects.gd`, 가변 프레임 후보 읽기·시간표·검토·등록 도구와 관련 검사를 생산자/사용자 양쪽에서 읽었다. 00_request, 01_contract, 모션 행위 검토 문서, animation/qa/resources 지침을 대조했다. 아래 세 문제를 찾아 수정하고 재검사했다. 해당 코드 범위에서 추가 필수 수정은 발견하지 않았다. **그림 품질이나 실제 경기의 자연스러움에 대한 통과 판정은 아니다.**

## 발견과 처리

1. **수정 — 교체 등록 때 새 원화 출처가 기록되지 않음.** 등록기의 기존 모션 경로는 이전 manifest 항목을 재사용하고 표시 필드만 바꿨다. 따라서 새 PNG에 예전 `creation`, `rights`, `motion_unification.source_path/source_sha256`가 남았다. root의 경로별 수정 승인 뒤 `register_motion_candidates.py`를 수정했다. 등록 계획은 이제 후보의 `source_path`, `source_sha256`, `creation`, `rights`, `conversion`을 필수로 확인하고 실제 원화 PNG 해시를 대조한다. 현재 항목과 `motion_registration.provenance`에 새 기록을 남기며 이전 항목 전체는 `registration_history`에 보존한다. 이전 history를 다시 중첩하지 않는다. 기존 PNG·논리 ID·SpriteFrames 경로, 사용자 모션별 승인과 정확한 계획 해시 검사는 유지했다.
2. **수정 — 새16프레임 후보의 생략된 그림을 허용함.** Python과 Godot 시간표 검사에서 전체 그림 표시 검사가 `count != 16`인 경우에만 실행됐다. 준비 구간 `[0,4)`에서 실제 표시가 `[0,0,0,0,0,0,0,3]`인 새16후보를 `timeline_errors=[]`로 재현했다. root 승인 뒤 두 도구의 해당 조건을 수정했다. 이제 새16·24·32 후보 모두 선언한 단계의 모든 그림을 보여야 한다. 기존 승인 자산 재사용은 예외로 유지한다. 원화 수가 실제 전투 틱보다 많은 경우를 거부하는 기존 검사도 유지했다.
3. **수정·독립 재검토 — 새16그림에 옛 목도리 좌표를 사용함.** 처음 코드는 프레임 수가16이면 기존 AIR_HAND/SWEEP_TIPS를 사용했다. 새16그림의 손·목과 좌표가 다를 수 있었다. root가 정확히 검토된4개 PNG 해시와 모션 ID를 함께 확인하는 방식으로 수정했다. 새 그림은 자체 프레임별 좌표가 있어야 한다. 해시가 없는 옛 검토 후보는 원본 PNG를 한 번만 읽어 캐시하며 렌더 틱마다 읽지 않는다. root 수정 diff와 새48개 검사를 독립적으로 읽고 재실행했다. 기존 manifest 공중 강 그림의 해시는 신시안과 다르므로 옛 좌표를 빌려 쓰지 않는다. 이것을 새 공중 강 원화의 승인이나 등록으로 해석하지 않는다.

등록기와 시간표 두 수정의 작성자는 이 검토 담당자이므로 그 수정 자체의 독립 코드검토는 최종 통합 담당자의 추가 대조 대상이다. runtime의 해시 제한 수정 작성자는 root이며 본 담당자가 독립 재검토했다.

## 확인한 동작과 증거

- 가중치가 실제 표시 그림을 선택하지만 준비/판정/회복의 전투 틱은 변경하지 않는다. 기존16 공격은 기존 반올림 매핑을 유지한다.
- run은 관찰한 실제 이동 거리로 진행한다. 새 달리기·새 활성화·순간이동 때 초기화하고, 정지 중에는 시간만으로 진행하지 않는다.
- 점프는 속도에서 상승/정점/하강 구간을 선택하며 착지는 기존 지상 전환/0.25초 표시 범위 안에서만 나온다. pivot으로 이미지를 위로 이동하고 같은 pivot 기준을 조정하는 포장은 월드 발 위치를 보존한다.
- 효과는 현재 표시 프레임의 좌표와 실제 sprite 크기·반전을 사용한다.24/32 또는 새16그림에 옛15번 프레임 좌표를 강제로 쓰지 않는다.
- `fighter_controller.gd`, AttackData/CombatRules, 기존 캐릭터 PNG·manifest·표시 보정 데이터는 이 검토 작업으로 변경하지 않았다.

검사 결과:

- `PYTHONPATH=tools/forest_arena python3 -m unittest test_motion_action_review`: **82개 PASS**, `qa/code-review-tests-r04.log`. 원화 출처 누락/변조/설명 누락/계획 뒤 변경, 새 출처 복사·과거 기록 보존과 새16 생략 거부 검사를 포함한다. 등록 테스트는 임시 가상 프로젝트에서만 실행한다.
- Godot `variable_motion_presentation.gd`: **48개 PASS**, `qa/code-review-variable-r02.log`.
- Godot `two_fighter_vfx.gd`: **PASS**, `qa/code-review-vfx-r02.log`.
- 현재 코드의 기존120모션 시간표: **PASS**, `qa/code-review-legacy-timeline-r02.log/json`. Python으로 현재 소스 해시·모션 범위·단계까지 다시 대조해 오류0개를 확인했다.
- `git diff --check`: **PASS**.

이전 `code-review-tests-r02.log`의 신규 테스트 import 누락은 수정했고 최종 결과는 r04다. `qa/verify-r01.log`의 전체 검사는 이 검토의 추가 수정 전 결과이므로 최종 통합 후 전체 검사를 다시 실행해야 한다. 실제 Android, LAN, 새 대표10종의 전체 원화·정상/느린 재생·연속 전환 QA는 이 코드검토로 대체하지 않는다.

## 후속 대조: 구간을 생략한16프레임 공격과 촬영용 포커스 처리

root의 후속 대조에서 `phase_frame_ranges` 자체가 없는 새16프레임 공격도 빠질 수 있음을 확인했다. 구간 명시를 강제하지 않고 **새 공격의 전체 재생에서0..count-1의 모든 그림이 실제로 표시됐는지** 확인하는 검사를 Python과 Godot 양쪽에 추가했다. 구간이 있는 경우의 단계별 검사도 유지한다. 기존 승인 runtime 재사용만 제외한다. 테스트는 구간 없는 새16후보의 전체 그림이 있으면 허용하고 한 그림을 빼면 거부하며 기존 승인 재사용 예외도 확인한다.

최신 증거는 다음과 같다. 위 r04/120모션 r02보다 이 결과를 우선한다.

- Python **83개 PASS**: `qa/code-review-tests-r05.log`.
- 현재 대표10모션의 Godot 시간표 **PASS**: `qa/code-review-pilot-timeline-r01.log/json`.
- 기존120모션의 Godot 시간표 **PASS**: `qa/code-review-legacy-timeline-r03.log/json`.
- 두 시간표를 Python `timeline_errors`로 현재 파일 해시·후보 scope·모션별 실제 표시 범위와 대조해 오류0개를 확인했다.

`render-pilot.gd`의 촬영 전용 플랫폼 알림 제외도 독립적으로 읽었다. 현재 `main.gd._notification`은 포커스 이탈·일시중단·포커스 복귀·재개 네 알림에만 반응하고 나머지는 동작이 없다. fixture는 autoload 준비 뒤 이 함수 이름 하나만 바꿔 제품 루트 스크립트를 컴파일한다. 따라서 현재 소스에서 제외되는 동작은 OS 포커스에 의한 입력 해제·경기 일시중단/재개뿐이며 경기 계산·준비·입력·실제 고정 틱 실행은 보존한다. 매 틱 pause를 강제로 푸는 방식은 없다. 원본 main과 변환 fixture의 해시를 모두 기록하므로 이 제외 범위를 재현할 수 있다.

이는 백그라운드 원화 촬영 조건으로 적절하며 실제 Android 생명주기 검사 통과를 뜻하지 않는다. 실패한 상속 시도 r08과 포커스 간섭 촬영 r01은 실패 증거로 보존한다. 최신 무영상 r09의 작은 요약 필드에서 errors=[]·checks=3265를 확인했다. 전체 동영상 품질을 이 검사로 판단하지 않았다. 촬영 결과 자체에도 `platform_lifecycle_ignored_for_capture=true`를 명시하라는 제안을 root에게 전달했고 최종 재촬영에 반영하기로 했다. fixture 수정은 root 소유로 두었다.
