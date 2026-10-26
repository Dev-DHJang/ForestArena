# 회복 방향·천 회수 경로 독립 검토 r04

2026-10-24. 담당: motion_code_review. r03 이후 `phase_frame_ranges` 전달, 마지막 판정 방향 유지, 현재 원화 끝으로의 회수만 대조했다. 프로덕션·후보·원화·촬영 자료는 수정하지 않았다. **코드 결과: fix 1건**. 현재 정상 후보의 실제 촬영이 실패했다는 의미는 아니다. 시각 품질은 별도 QA가 판단한다.

## 발견: 마지막 판정 좌표가 빈 행일 때 새 아래 방향을 사용함

P2. `frame_anchors[last_index]`가 빈 Dictionary `{}`이면 `_draw()`의 타입 검사를 통과한다. `held_scarf_path(current,reach,previous_heading={})`는 빈 인자를 “직전 방향 지정 없음”으로 처리하므로 현재 회복 그림의 아래로 늘어진 천을 긴 공격 방향으로 다시 사용한다. 빈 anchor 행은 기존 선택 필드 계약에서 허용되며, 가려져 해당 좌표를 제공하지 않는 그림에서 가능하다. 마지막 판정의 좌표가 없으면 회복 효과를 생략해야 한다.

실제 제품 `_draw()` 경로로 재현했다. QA 전용 Effects 하위 클래스는 `_cloth()`의 시작·끝만 관찰한다. 제품의 `_draw()`, 좌표 읽기와 방향 선택을 다시 구현하지 않는다.32개 프레임과 정상 회복 좌표, 구간 `[0,4],[4,27],[27,32]`를 두고 마지막 판정26번 행만 `{}`로 만들었다. 결과는 `qa/code-r04/missing-heading.gd`와 `missing-heading-r01.log`다.

```text
EMPTY_LAST_ACTIVE_DRAW: paths=1 snapshot_unchanged=true
new_downward_recovery=true
```

회복 분기에서 마지막 행이 비어 있거나 필요한 hand/held-tip 좌표가 없으면 생략하도록 확인한 뒤 전달하는 최소 수정이 필요하다. 기존 active 재생에서 “직전 방향 지정 없음”이라는 함수 기본값은 계속 유효하다. 본 담당자는 수정하지 않고 root에게 전달했다.

## 정상 확인한 경로

- Presentation은 현재 표시 drawing의 `phase_frame_ranges`를 효과에 전달하고 필드 없음·표시 자산 없음에서 비운다. 다른 모션의 구간이 남아 재사용되지 않는다.
- 회복은 구간의 마지막 판정 그림 인덱스를 읽고 범위 밖 인덱스/Dictionary가 아닌 행을 거부한다. 유효한 과거 heading의 손·천 끝이 없거나 셀 밖·가려짐·붕괴 상태이면 `held_scarf_path`는 생략한다. 위 빈 Dictionary 한 경우가 그 처리에서 빠져 있다.
- 현재 grip은 계속 현재 그림과 실제 sprite 변환에서 구한다. 직전 그림의 heading은 두 점의 차이이므로 현재 sprite 위치 이동이 상쇄되며 반전/크기가 함께 적용된다.
- extension1은 마지막 판정 heading의 긴 끝, extension0은 현재 원화의 painted_tip이다. 회복6틱에 extension0,7틱에 envelope0이며 피해·끌기·다단 타격 수나 전투 시간을 바꾸지 않는다.
- 손 좌표 없는 기존 특수기와 공중/일반 목도리 공격은 새 회수 분기로 들어가지 않는다. 기존 경로의 파형 기본값·잔상 시간도 그대로다.
- FighterController의 SHA는 r02와 같고 이번 diff에 전투 상태·Resource·LAN 메시지 형식 변경은 없다. 현재 PNG가 같은 것도 촬영 소스/후보 기록에서 대조했다.

## 실행과 범위

- `qa/code-r04/vfx.log`: **TWO_FIGHTER_VFX PASS**. 새 아래 공격 금지/정확한 painted_tip 회수를 포함하나 빈 마지막 행은 이 기존 검사에 없었다.
- `qa/code-r04/lifecycle.log`: **430개 PASS**.
- `qa/live-normal-r04/state-report.json`:120틱·728검사·오류0, 현재 소스 SHA 일치, 모든 표시 호출의 snapshot 불변.
- `qa/live-mirror-small-r04/state-report.json`:120틱·728검사·오류0, 현재 소스 SHA 일치, 모든 표시 호출의 snapshot 불변.

현재 새 후보의 마지막 판정26번 행에는 유효한 값이 있어 위 누락 처리가 실제 촬영에서 발생하지는 않았다. 따라서 정상 촬영 증거와 잘못된 데이터 처리의 코드 결함을 구분한다. 실제120틱 자료가 모든 기기·모든 모션·시각 품질을 증명한다고 해석하지 않는다.

검토 해시:

| 파일 | SHA256 |
| --- | --- |
| `scripts/fighter_attack_effects.gd` | `5d7aee4e7a3801c0fc05eb332341fb020b6925fb488501801eb25e82c6c0f65b` |
| `scripts/local_fighter_presentation.gd` | `63d1294fe5c09cd8cadd21eb9ce19b711f8d79c0aff1d3afcede3447eaff524c` |
| `tests/two_fighter_vfx.gd` | `2a1c72b355050bfc3c73e0103354edd6ea5c33d16c967a12b00d7fe2dec2452a` |

이 기록은 위 해시의 관찰로 고정한다. 해당1건의 수정 뒤 새 코드 해시와 경계 재검사를 별도로 남겨야 한다. 새 모션의 전체 재생/회복 자연스러움·사용자 승인·실제 Android 검사와는 구분한다.
