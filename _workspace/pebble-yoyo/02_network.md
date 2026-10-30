# LAN5 · 조약돌 요요 연결

## 변경

- LAN 서버·클라이언트·초대 코드의 버전은5. 이전1~4는 명시 거부한다. 개발용 online_dev_client의 protocol1은 변경하지 않았다.
- 활성 두 캐릭터, 직업 없음, 미장착 또는 pebble-yoyo만 LAN 실행에 허용한다. 상점·프로필 소유 검증 경계는 기존대로 유지한다.
- use_equipment는 PRESS만 전송·접수한다. 서버는 기존 MatchController/FighterController로 명령을 전달하며 클라이언트가 궤적·경직·쿨타임을 계산하지 않는다.
- 장비 상태는 기존 network_snapshot과 재접속 snapshot으로 전달한다. 게임판정/소비자는 전투 담당이 소유한다.
- LAN runtime 확인은 실제 WebSocket 두 클라이언트로 장착 전달, 이동 후 사용, 피해 없는 경직, HOLD 거부, 쿨타임 재사용 방지와 재접속 복원을 추가했다.
- Android fleet 도구는 기본 protocol5와 활성 장비2선택×캐릭터2개 조합, 장비 버튼·사용 상태를 검사한다. 기존1~4의 명시적 검사 경로·정책은 보존했다.

## 검증

- `python3 tools/forest_arena/test_android_fleet.py`: 150개 통과. 합성 fixture 검증이며 실제 Android 통과가 아니다.
- `python3 -m py_compile tools/forest_arena/android_fleet.py tools/forest_arena/test_android_fleet_capacity.py`: 통과.
- Godot/LAN 실행 검증은 부모 에이전트의 공용 검사 순서에서 수행한다. 실제 기기 미실행.

- LAN 계약 검사 초회 실패는 테스트가 JSON 변환 전 정수 Dictionary와 수신 후 숫자 Dictionary를 직접 비교한 문제였다. wire-normalized 기대값과 비교하도록 고쳤으며 새 equipment_phase_tick도 전달 보존 대상에 추가했다. 재검은 부모가 수행한다.

## 실제 LAN 검사에서 발견한 서버 시간 처리 수정

처음 실제 실행은 `move_into_equipment_range`에서 실패했다. 303권위틱 뒤 호스트 속도는335였으나 이동거리는681px에 그쳤다. LAN 서버가 `_process`에서 고정틱 전투를 호출해 CharacterBody2D.move_and_slide가 물리틱 대신 렌더링 콜백의 가변 시간을 사용하고 있었다.

서버의 WebSocket 읽기·인증·연결 기한은 `_process`에 유지하고, 전투 step_fixed_tick와20Hz snapshot 전송만 `_physics_process`로 옮겼다. 지상 정속335에서 `이동거리 = 335 × 경과틱 / 60`을 실제 수신 snapshot으로 비교하는 회귀를 추가했다. 사용 범위 접근·장비 적중 검사를 완화하거나 제거하지 않았다.

- 수정 후 `./scripts/verify-lan-runtime.sh`: `LAN_RUNTIME`, `LAN_APP_FLOW`, `LAN_RECONNECT_AUTH`, 경기 등록·결과·재대전 전송 모두 통과. 로그 `build/verification/pebble-yoyo/lan-runtime-focused-r02.log`.
- 명시적 고정시간 이동거리 회귀 추가 뒤 최종 재검은 r03 로그를 따른다.
- 최종 r03: 고정시간 이동거리 회귀를 포함한 실제 LAN 전체 wrapper 통과. `build/verification/pebble-yoyo/lan-runtime-focused-r03.log`. 실제 Android·운영 DB 통과를 뜻하지 않는다.
