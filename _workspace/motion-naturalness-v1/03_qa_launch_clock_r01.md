# LAUNCH 표시 시간 제안 독립 코드 확인 r01

판정: **PASS — 고정 제안 clone의 두 조건 변경과 아래 코드 검사 범위.** 그림의 자연스러움·사용자 승인·실제 Android 결과는 이 판정에 포함하지 않는다. 제품에는 이 검토에서 코드를 복사하지 않았다.

## 대상과 보존

- 요청: 자현·나비의 띄워짐(`LAUNCH`)이 실제 경직 21틱 동안 그림 F1~F5까지만 재생되고 바로 낙하 그림으로 전환되는 연결 문제를 검토한다. 실제 경직을 늘리지 않고 로컬의 이미 결정된 경직 시간에 그림 F1~F16을 맞추는 제안이다.
- 제품 기준: 검사 시작 HEAD `63a45825b3ee2e0dd3256c018c1beda2a80e024a`. 제안 `qa/launch-transition-proposal-r01/presentation-proposed.gd` SHA-256 `7b65553654f7a44069546e48e81e338f32c5bbd7814be3ca894c4ff3cb7526f7`.
- 제품과 clone의 차이는 두 곳뿐이다. `shown == hitstun` 조건을 `shown in [hitstun, launch]`로 넓혀, 상태 진입 시 실제 `fighter.hitstun_ticks`를 읽고 그 시간 안에 그림을 배분한다. 타격·상태 전환·피해·위치·경직 시간을 쓰는 코드는 추가하지 않는다.
- 제품 presentation, fighter controller, main, manifest, 제안 clone, 생산자 검사 파일은 검사 전후 모두 같은 해시였다. `independent-input-hashes-r01.json`, `independent-fixed-files-r01.json`에 기록했다. PNG·runtime 리소스·manifest는 수정하지 않았다.
- QA 스킬에 따라 생산자와 표시 코드를 함께 읽고, 변경 범위를 코드와 별도 경계 검사로 확인했다. 이 문서는 기존 `03_qa_remaining_final_r03.md`의 시각 관찰을 대체하지 않는다.

## 독립 관찰

| 확인 항목 | 판정 | 근거와 한계 |
|---|---|---|
| 실제 시간 사용 | pass | `apply_hit`가 상태·경직을 정한 뒤 신호를 보내며, 표시 코드는 그 값을 읽는다. 프레임은 경과 틱/전체 틱으로 정하며 경직을 늘리지 않는다. 6틱에서는 일부 그림을 건너뛰되 첫·마지막 자세와 종료 시점을 지킨다. |
| 같은 상태의 반복 LAUNCH | pass | 30틱 시작 후 6틱 진행해 남은 24틱에서 6·24·30틱으로 다시 피격시켰다. 상태 이름과 공격 활성 번호가 같아도 신호로 새 실제 시간을 저장하고 F1로 재진입한다. 마지막 잠금 틱에 마지막 그림, 만료 틱에 실제 상태를 표시했다. 두 캐릭터 모두 확인했다. |
| 기존 HITSTUN·예외 | pass | 고정 생산자 검사를 독립 재실행해 688개 통과했다. 일반 재피격, 로컬 신호/전달 이벤트 중복 차단, 지난 이벤트·다른 대상·BLOCK/IMMUNE/ARMOR 차단, 가드 붕괴, 초기화가 포함된다. |
| 전투 값 불변 | pass | 별도 448개 검사의 모든 `sync_visual` 전후에 기존 snapshot, `RuntimeCombatState`의 모든 스크립트 변수, 반올림 전 위치·속도, `hitstun_ticks`, 공격 참조·예약 입력·활성 번호를 동등 비교했다. 기존 snapshot에는 남은 경직이 없어 그 값도 별도로 검사했다. |
| 145틱 원본/제안 비교 | pass | 제공된 baseline/proposed 보고서를 독립 읽기하여 145개 `match` snapshot 전체 동등을 재계산했다. 원본은 LAUNCH F1~F5, 제안은 F1~F16이며 두 경우 모두 LAUNCH 21틱이다. 이는 저장된 상태 자료의 재검산이며 이번에 그 145틱을 새 촬영한 것은 아니다. 해당 자료의 현재 해시 불일치는 이후 concept 4개가 더해진 manifest 한 파일뿐이며, 두 presentation 핀은 현재와 일치한다. |
| LAN duration 없음 | pass | 실제 `apply_network_snapshot`으로 LAUNCH를 전달했다. 현재 snapshot에는 `hitstun_ticks`가 없다. 초기화된 원격 파이터의 표시 duration은 0으로 유지하며 FPS 경로로 진행한다. 새 `hit_resolved/HIT`에 F1 재진입, 다음 FALL snapshot에서 즉시 jump 표시와 duration 초기화를 확인했다. 통신 메시지·버전은 바꾸지 않는다. 실제 소켓 연결 검사는 이 별도 시험의 범위가 아니다. |
| 착지·KO·초기화 | pass | 2인 출시 규칙 리소스의 실제 착지로 기존 18틱 쓰러짐→12틱 기상 시작을 확인했다. 치명타는 남은 기회에 따라 death/ring_out을 즉시 표시하고 LAUNCH 시계를 지웠다. 경기/프로필 초기화 모두 idle F1, duration 0, 재시작 예약과 로컬 전달 대기 0을 확인했다. |
| 미술·기기·제품 반영 | blocked / 별도 범위 | 이번 자료는 headless 코드 검사다. 새 자현 원화의 품질, 전체 LAUNCH 전환의 직접 재생, Android, 제품 최종 복사 뒤 바이트 동등은 여기서 통과시키지 않는다. |

## 실행과 증거

실행 환경은 macOS의 Godot `4.7.1.stable.official.a13da4feb`, headless다.

```sh
godot --headless --path . --script _workspace/motion-naturalness-v1/qa/launch-transition-proposal-r01/reaction-tests-proposed.gd
# HIT_REACTION_RESTART: PASS (688 checks)
godot --headless --path . --script _workspace/motion-naturalness-v1/qa/launch-transition-proposal-r01/independent-boundaries-r01.gd
# INDEPENDENT_LAUNCH_BOUNDARIES: PASS (448 checks)
```

- 고정 생산자 검사 재실행: `qa/launch-transition-proposal-r01/independent-reaction-rerun-r01.log`.
- `./scripts/verify-docs.sh`: PASS. 같은 폴더 `independent-verify-docs-r01.log`에 남겼다.
- 추가 경계 검사: 같은 폴더 `independent-boundaries-r01.gd`, `.json`, `.log`. JSON에는 재피격 6·24·30틱의 실제 그림 번호와 LAN 전환 사례를 남겼다.
- 145틱 재검산: `independent-comparison-r01.json`. 원 보고서는 `baseline/state-report.json`, `proposed/state-report.json`이며 `state_only: true`, `pixel_capture: false`다.
- 검사 도구의 첫 실행은 main scene 기본 Phase 1 규칙으로 실행되어 착지 쓰러짐 6개 검사가 실패했다. 이 규칙에는 단순 전투의 착지 쓰러짐이 활성화되어 있지 않았다. 제품 버그로 기록하지 않고 초기 실패 JSON을 `independent-boundaries-r01-fixture-setup-fail.json`에 보존했다. 별도 검사만 실제 `two_fighter_combat_rules.tres`로 명시한 뒤 위 448개가 통과했다. 제품·clone·기존 688개 검사는 고치지 않았다.

## 후속

이 두 조건 변경의 코드 반영을 막는 문제는 찾지 못했다. 제품에 반영한다면 승인된 clone과 최종 제품 파일의 바이트 동등을 별도로 확인하고, 최종 원화와 실제 상태 재생을 기준으로 시각 검토를 갱신한다. 기존 전체 검사나 Android·LAN 실제 연결 통과를 이번 결과로 대신하지 않는다.
