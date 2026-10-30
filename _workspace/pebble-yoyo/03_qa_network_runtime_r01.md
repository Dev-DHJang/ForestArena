# LAN 권위 물리 콜백 수정 독립 검토 r01

- 검토자: yoyo_combat. LAN 서버 콜백 수정의 생산자가 아닌 별도 검토자다. 전투 코드에는 본 검토자가 작성한 부분이 있으므로 이 기록은 **서버 콜백·전투 소비 경계의 독립 검토**이며, 전투 구현 자체의 독립 승인을 대신하지 않는다.
- 방법: 원 요청·공용 계약, 최종 서버/전투/클라이언트 코드, 실제 LAN 실행 검사의 소스와 중앙 실행 로그를 읽었다. 새 Godot 실행은 하지 않았다(오케스트레이터가 전체 검사를 실행 중).
- 판정: **pass** — 검토 범위에서 수정이 필요한 결함을 찾지 못했다.

## 관찰과 근거

| 확인 | 관찰 |
| --- | --- |
| 물리 시간 | 서버의 `_process`는 소켓 수신·접속 해제·실시간 기한만 처리한다. 전투 accumulator·`step_fixed_tick(false)`·3틱마다 snapshot 전송은 `_physics_process`에서만 호출한다. `move_and_slide`가 물리 콜백에서 호출되어 렌더 delta를 사용하던 경로를 제거했다. CombatRules는60Hz만 허용하며 controller의 자동 physics 처리는 꺼 두어 이중 진행이 없다. |
| 입력 순서 | 소켓 수신은 단일 주 실행 흐름에서 다음 `controller.tick + 1`에 입력을 예약한다. 물리 콜백보다 늦게 수신된 입력은 다음 물리 틱에서 처리되며, 과거 틱을 소급하거나 렌더마다 전투를 추가 진행하지 않는다. seq 중복/역전 거부와 장비 PRESS 전용 검사는 유지된다. |
| 대기·재대전 | 시작 전·방 초기화 후 `running=false`라 권위 틱이 진행되지 않는다. 시작·재대전 시 accumulator=0과 `controller.reset_match()`로 이전 시간·입력·장비 쿨타임을 초기화한다. 잠시 연결이 끊겨도 기존 정책대로 경기는 계속되며 서버 상태가 유지된다. |
| 종료·결과 | 종료 신호가 동기적으로 `running=false`, `ended=true`를 설정하므로 while 조건이 다음 틱을 막는다. final_tick/hash로 결과를 한 번 저장하고 남은 결과 전송은 outbox가 담당한다. 종료 틱이3의 배수이면 최종 snapshot이 결과 뒤에 전송될 수 있는 기존 동작도 유지되며, 클라이언트는 이를 상태 표시로만 적용하고 경기 진행을 다시 켜지 않는다. |
| 실시간 기한 | 재접속60초·재대전20초·방 heartbeat와 지연 disconnect는 `_process`의 실시간 시계를 계속 사용한다. 물리 틱이나 장비 쿨타임으로 기한을 바꾸지 않았다. 재접속 시 입력·토큰·snapshot 복원 경계도 유지된다. |
| 장비 단계 | 서버 전투에서 단계·전체 틱·0기반 단계 틱·월드 위치·방향·활성 번호·남은 쿨타임을 생성하고 클라이언트는 그대로 적용한다. 조기 벽 귀환은 전체48틱 비율이 아닌 회수 단계 틱을 제공한다. 장비 준비/발사/귀환·피격중단은 렌더 프레임으로 판정하지 않는다. |
| 순수 경직 연결 | 장비 판정은 일반 공격 판정 후 서버에서 해소한다. 일반 피격은 같은 틱의 장비를 중단하고, 장비 경직은 별도 함수로 HP·추가 넉백·공중 기회를 변경하지 않으며30틱·가드/무적/다운 보호 정책을 유지한다. |
| 데이터 일반화 | AccessoryAbilityData의 모션 ID 기본값은 빈 값이며 조약돌 요요 Resource에 실제 지상/공중 ID를 명시한다. 유효성 검사와 깊은 복사를 유지하므로 최종 변경은 장비 행동이나 기존 장신구 schema2를 바꾸지 않는다. |

## 실행 증거 읽기

`build/verification/pebble-yoyo/lan-runtime-focused-r03.log`에서 LAN_RUNTIME·LAN_APP_FLOW·LAN_RECONNECT_AUTH, 등록/결과/재대전 전송과 전체 LAN 실행 스크립트 PASS를 확인했다. 해당 로그는 서버 콜백 수정 이후 생성됐다. 실행 검사의 실제 단언을 대조했다.

- 정상 속도에 도달한 권위 snapshot 두 개의 거리 변화가 `335 × 틱 차이 ÷ 60`과1px 이내로 일치한다. 렌더 폴링 시간에 따라 이동 거리가 달라지는 원래 문제를 직접 잡는 회귀 검사다.
- 실제 소켓 입력으로 요요를 사용해 서버 쿨타임 시작·HP 불변 경직·HOLD 거부·쿨타임 중 활성 번호 불변을 확인한다. snapshot 전송은3틱마다이므로 LAN 경직 관찰은1~30틱 범위이며, 정확한30틱 자체는 전투 단위 검사의 대상이다.
- 재접속 snapshot에서 장착 ID·남은 쿨타임·활성 번호를 보존하고, 다른 참가자의 토큰 재사용 거부·재대전·방 종료도 확인한다.

실행 주체는 중앙 검증이며 이 독립 검토자는 로그와 검사 소스를 대조했다. 실제 Android 두 대·Wi-Fi 단절/복귀·사람의 조작감은 이 기록의 통과 범위가 아니다.

## 검토 대상 해시

| 파일 | SHA-256 |
| --- | --- |
| `server/game/lan_game_server.gd` | `831449a4e10fe2f8d331d098df0e157d310ff87be908e6101c562dcfc7902a3a` |
| `tests/lan_runtime_verifier.gd` | `8c54e1d7479ce5f8f92d5051361aa037b12689d62a63286f431c7b35dd10ee2a` |
| `scripts/match_controller.gd` | `08957799759d0d02f97e12a00840004a21b03618b211158c17f6529365bd37e6` |
| `scripts/fighter_controller.gd` | `6355e67e5b7de0e4a1052f99c3086e77d5ab27c868ee82cb32717844787c8a8b` |
| `scripts/hit_resolver.gd` | `d86c4830c16ecf307c176a0347f2327e61d1198447ed084dc4b8e8ff0a5d4f4f` |
| `scripts/data/accessory_ability_data.gd` | `4b6c1101c1055207dd4eec8d81c38c6111fa18287c60851af738f467b1c68781` |
| `assets/loadouts/pebble_yoyo_accessory.tres` | `f8dc367f9cf78543a0d4c91d521d504b1bbfcf1fef150726fbd19035d59eb36b` |
| `scripts/network/lan_match_client.gd` | `6cdcdc5a68f4995902956e424865d261ee30f525295503c3c0ec12fb302980ae` |
| `build/verification/pebble-yoyo/lan-runtime-focused-r03.log` | `32b1716dca6250d0b79cd4d7663e304b5041f916ec763dde69fa4b7b1e2ac5f3` |
