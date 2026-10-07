# LAN 1대1 계약 v1

## 연결 코드

- 호스트 코드는 `FAH1|ws://<사설 IPv4>:<port>|1`이다.
- 초대 코드는 `FA1|ws://<사설 IPv4>:<port>|<8자리 방 코드>|1`이다.
- 앱은 사설 IPv4, `ws` 방식, 1~65535 포트, 대문자 영숫자 8자리 방 코드와 protocol 1만 받는다.

## 메시지

- 클라이언트는 `create_room`, `join_room`, `input`, `resume`, `rematch`, `leave`, `ping`을 보낸다.
- 서버는 `room_created`, `room_waiting`, `room_ready`, `joined`, `match_start`, `snapshot`, `peer_status`, `match_end`, `rematch_state`, `error`, `pong`을 보낸다.
- 모든 메시지는 `protocol_version=1`을 가진다. 한 패킷은 8KiB 이하이며 알 수 없는 버전·타입은 명시적으로 거부한다.
- 입력은 증가하는 `seq`, action, direction, edge만 가진다. 위치·HP·stock·승패는 서버만 정한다.

## 로드아웃과 경기

- 선택 형식은 `schema_version`, `character_id`, `job_id`, `accessory_id`다.
- 서버의 `LocalPlayCatalog`에서 존재하고 `LoadoutBuilder`로 만들 수 있는 조합만 받는다.
- 참가자 ID는 `lan_host`, `lan_guest`로 고정하며 방장 slot 1, 참가자 slot 2다.
- 경기장은 `forest-ledge`, 3 stock과 기존 HP·링아웃·45 tick 복귀·60 tick 무적 규칙을 사용한다.
- 서버는 같은 방에서 두 명이 준비된 뒤 seed를 만들고 양쪽에 같은 설정을 보낸다.
- 연결 해제 시 입력을 풀고 60초 동안 회전형 reconnect token으로 복귀시킨다. 만료 시 이탈 패배다.
- 결과 뒤 양쪽이 모두 `rematch=true`를 보내면 같은 선택과 새 seed로 초기화한다. 한쪽 취소 또는 20초 만료는 방을 닫는다.

## 호환과 보안 경계

- 개발용 HTTP/WebSocket protocol v1과 `online_dev` 장면은 변경하지 않는다.
- LAN 서버는 데이터베이스, 계정과 결과 저장을 사용하지 않는다.
- Android APK는 같은 Wi-Fi의 WebSocket에 연결하기 위해 `INTERNET` 권한만 추가하며 위치·카메라·마이크 권한은 요청하지 않는다.
- 사설 Wi-Fi 개발·플레이 범위이며 TLS·공인 인터넷 노출을 지원하지 않는다.
