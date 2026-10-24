# 표시 코드 독립 검토 r01

2026-10-24. 담당: motion_code_review. 기준 HEAD `ad4a4928bfd2f557cb483417dd8deb9796b59e54` 이후 표시 코드 diff를 검토했다. animation/qa/resources 지침, 이 작업의 요청·목도리 표시 계약, 상태 생산자인 FighterController/MatchController와 LAN snapshot 적용 경로를 대조했다. 프로덕션 코드·원화·후보·manifest는 수정하지 않았다.

## 결과: fix 1건

**P2 — 재등장 중 새 경기 초기화가 이전 등장 모션을 남긴다.** `local_fighter_presentation.gd`의 `_spawn_elapsed`와 `_last_motion`은 캐릭터 ID 변경 때만 초기화된다. 실제 `ring_out()`→`step_tick()` 복귀로 spawn을 시작한 뒤0.4초 재생하고, 공개 `reset_for_match(rules)`를 호출하면 파이터는 새 경기의 IDLE인데 그림은 이전 spawn의5번 프레임부터 계속 표시된다. 같은 캐릭터의 `configure_profile()`을 다시 호출해도 유지된다. 재등장 연출을 요청하는 상태 전환이 새 경기에 없는데도 지난 경기의 표시 시간이 이어지는 문제다.

재현 출력(`qa/code-r01/repro-reset.gd`와 `.log`):

```text
before reset: spawn elapsed=0.41666666666667 frame=5
after public reset_for_match: spawn elapsed=0.41666666666667 frame=5 state=IDLE
after same-character profile reconfiguration: spawn elapsed=0.41666666666667 frame=5
```

새 경기/동일 캐릭터 프로필 재설정에도 표시 타이머를 초기화할 명시 경로가 필요하다. 캐릭터가 달라질 때의 초기화는 정상이다. 이 문제를 고치려고 전투 시간이나 LAN 메시지 형식을 바꿀 필요는 없다. 실제 공개 reset 중간 경계를 확인하는 검사가 유효하며, 기존228개 lifecycle 검사는 이 경계를 확인하지 않는다. 촬영 중인 코드 해시는 유지하고 root에게 발견만 전달했다.

## 정상 확인한 범위

- 표시 변경은 fighter의 상태·남은 기회·공격·무적 시간 등을 읽고 자신의 타이머/sprite만 수정한다. 경기 규칙·피해·경직·승패·전투 snapshot을 쓰지 않는다.
- 실제 RING_OUT→IDLE 복귀는 spawn을 시작한다. 이동·공격·가드 등 IDLE 이외의 행동 또는 active_attack이 있으면 즉시 연출을 중단한다. 없는 spawn 자산을 강제로 표시하지 않는다.
- 실제 `apply_network_snapshot()`을 거친 RING_OUT→IDLE, 바로 공격, 바로 이동을 별도 확인했다. 상태 읽기로 재등장을 표시하며 공격/이동 우선이 유지된다. 다른 캐릭터 프로필 변경은 지난 spawn 타이머를 버린다. 이는 snapshot 적용 경로 검사이며 실제 LAN 연결 검사 통과를 뜻하지 않는다.
- MATCH_ENDED에서 stocks0은 death, 그 외는 idle이다. 끝난 경기의 active_attack이 남아도 공격 프레임으로 매핑하지 않는다. 무적 alpha를 제거하며 효과 envelope도0이어서 잔존 공격의 목도리/발톱 효과를 그리지 않는다.
- 잡은 손 좌표가 있는 새 특수기는 실제 손에서 원화의 잡힌 쪽 끝 방향으로 한 가닥만 연장한다. 반대쪽 천은 원화에 남는다. 손 좌표가 없는 기존 경로는 유지한다. 준비는 원화만 표시하고 회복 잔상은 기존7틱 이내 사라진다. 누락/가려진/겹친/셀 밖 좌표에서는 임의 방향을 만들지 않는다. 실제 sprite의 크기·접지 이동·좌우 반전을 같은 변환으로 적용한다.
- 좌표 범위0..128은 기존 Python 표시 계약과 일치한다. 기존 효과는 승인 원화의 목도리를 논리 ID로 읽는다.

## 실행 증거

직접 재실행한 검사:

- `motion_lifecycle_presentation.gd`: **228개 PASS**.
- `two_fighter_vfx.gd`: **PASS**.
- `local_fighter_presentation.gd`: **PASS**.
- `variable_motion_presentation.gd`: **53개 PASS**.
- `two_fighter_presentation.gd`: **PASS**.
- 별도 실제 snapshot 적용 검사 `qa/code-r01/read-network-state.gd`: **21개, 오류0**. 각 표시 호출 전후 전투 snapshot 불변도 비교한다. 결과는 동명 `.log`에 있다.
- `verify_godot_resources.py --project-root .`: **519개 논리 자산 정상**, 품질별 자산25개.
- `git diff --check`: **PASS**.

검토 해시:

| 파일 | SHA256 |
| --- | --- |
| `scripts/local_fighter_presentation.gd` | `79e420c952552d87b88a7c48f21d96e7fb45740d60b534db0f7a103f2dc96544` |
| `scripts/fighter_attack_effects.gd` | `936a66c1a688d3f635d7816019669b3851f716d299f616d63f3d44cb553de713` |
| `tests/motion_lifecycle_presentation.gd` | `2e4da5a0e618168e11b50f2630c3d4945ce586954e356d9ae5e335a7bf9ace8f` |
| `tests/two_fighter_vfx.gd` | `e3efa56dacc33fbf845ed50d1adec3707e47463d73ed1ea1525c75111b371e2f` |

이 검토는 코드 동작과 상태 경계에 한정한다. 새 목도리 원화의 연속 쳐내기 안무·정상/느린 속도·실제 전체 연결·작은 화면의 자연스러움은 원화/동영상 QA에서 확인해야 한다. 실제 Android 기기 검사는 실행하지 않았다. 위1건을 남긴 상태를 전체 통과로 기록하지 않는다.
