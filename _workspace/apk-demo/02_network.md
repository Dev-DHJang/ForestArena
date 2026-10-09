# 데모 LAN v2 개발 기록

- 적용: accepted ADR-032와 `01_contract.md`, 제한된 Phase 6 LAN 예외.
- 방/초대 코드에 같은 사설 IPv4 서버의 API・WebSocket 주소를 함께 전달한다. v1 코드/메시지는 `unsupported_protocol`로 거부한다.
- 방 생성・참가・복귀 전에 서버용 토큰을 쓰는 내부 API가 게스트 ID와 닉네임을 확인한다. 클라이언트가 보낸 이름은 표시값에 사용하지 않는다.
- 게스트 ID 두 슬롯 중복과 다른 게스트의 재접속 토큰 사용을 거부한다. 인증 중 연결 종료・취소 뒤 늦은 완료가 방을 생성하지 않도록 진행 중 요청을 연결별로 정리한다.
- 지정 bind IPv4와 CIDR을 요구하며 `0.0.0.0`을 금지한다. 실제 TCP 상대 IP를 `peer.get_peer(peer_id).get_connected_host()`로 확인하고 허용 범위 밖 연결을 끊는다. [Godot 공식 get_connected_host 안내](https://docs.godotengine.org/en/stable/classes/class_websocketpeer.html#class-websocketpeer-method-get-connected-host)에 따라 proxy 헤더와 무관한 상대 IP를 사용한다.
- 서버 내부 HTTP와 클라이언트 최초 연결・방 요청은 8초 제한. 재접속 한 시도에 8초를 넘기면 다음 시도를 하되 기존 총 60초를 유지한다. 재접속 전에 앱의 게스트 갱신 함수를 호출하며 취소 뒤 갱신 완료가 새 연결을 덮어쓰지 않도록 세대 번호를 비교한다.
- 경기 참가 때 정해진 닉네임을 재대전・재접속・실제 미니맵까지 유지한다. 실패・중단 시 입력을 해제한다.

## 실행한 확인

- `godot --headless --path . --script res://tests/lan_contract.gd`: PASS. v2 주소・버전・CIDR 경계・loadout・요청 제한 입력 해제 확인.
- `./scripts/verify-lan-runtime.sh`: PASS. 로컬 HTTP 인증 fixture와 실제 Godot WebSocket 서버/클라이언트로 missing/invalid/expired 토큰, 닉네임 미설정, 잘못된 loadout, 큰 패킷, 중복 게스트, 다른 게스트 복귀 거부, 인증 중 단절 후 방 잔존 없음, 이름 위조 무시, 입력・복귀・결과・재대전 확인.
- 같은 스크립트의 `LAN_RECONNECT_AUTH`: PASS. 실제 두 클라이언트 경기 도중 연결을 닫고 갱신 함수가 첫 시도에 8초 뒤 빈값(API 일시 실패)을 돌려준 뒤 다음 시도에 성공하는 상황에서 재접속 토큰 회전과 경기 복귀 확인. 영구 인증 실패도 새 게스트를 만들지 않고 최대 60초 유예 뒤 종료한다.
- 같은 스크립트의 `LAN_APP_FLOW`: PASS. 호스트와 참가 앱 화면에서 서버가 확인한 이름・미니맵 자기 표시・카메라・결과 확인.
- fixture는 LAN 전송/접속 허용 분기 검사 용도다. 실제 API/PostgreSQL 통합 및 APK/물리 Android 두 대 확인을 대신하지 않는다. 허용 밖 실제 네트워크 연결은 배포 환경에서 별도 확인한다.

## 환경 변수

`FOREST_ARENA_LAN_BIND_HOST`, `FOREST_ARENA_ALLOWED_CIDR`, `FOREST_ARENA_LAN_API_URL`(배포 코드에 표시할 API), `FOREST_ARENA_API_BASE_URL`(선택적 내부 API; 미설정이면 표시 API), `FOREST_ARENA_SERVICE_TOKEN`, `FOREST_ARENA_LAN_PORT`, `FOREST_ARENA_LAN_ADVERTISED_WS_URL`.
