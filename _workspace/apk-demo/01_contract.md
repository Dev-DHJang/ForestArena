# 데모 v2 데이터 약속

## 닉네임 API
- 기존 POST /v1/auth/guest와 /v1/auth/refresh 유지.
- GET /v1/guest/profile: Bearer 인증, {player_id, nickname: string|null}.
- PATCH /v1/guest/profile: {nickname}, NFC・2~12 한글 완성형/영문/숫자/밑줄, trim 없이 검사. 소문자 비교 UNIQUE, 충돌 409 nickname_taken, 형식 400 invalid_nickname. 기존 display_name 보존, nullable nickname 신규 필드.
- POST /internal/v1/lan/auth: x-forest-arena-service-token 필수, {access_token}. access 검증+DB 현재 닉네임 확인; {player_id,nickname}; 미설정 409 nickname_required. 클라이언트 ID/닉네임 신뢰 금지.
- API demo 모드에 FOREST_ARENA_ALLOWED_CIDR 필수. 요청 socket.remoteAddress를 검사(IPv4-mapped 포함), proxy header 무시. loopback 내부 호출 허용.

## LAN protocol v2
- 모든 메시지 protocol_version=2. host code FAH2|api_url|websocket_url|2, invite FA2|api_url|websocket_url|room_code|2. URL은 동일 사설 IPv4 또는 loopback, http/ws+port only. 구버전 코드 명시 거부.
- LanInvite.host_code(ws_url, api_url), invite_code(ws_url, room_code, api_url).
- begin_host(code,selection,nickname="",access_token=""), begin_join 동형. nickname 인수는 API 확인한 표시값과 무관한 호환용; 서버에서 사용하지 않음.
- 최초 create_room/join_room와 resume는 access_token 포함. 서버는 내부 auth API를 8초 제한으로 호출, peer당 진행 중 인증 하나만 허용, 완료 뒤 peer 존재・방 상태 다시 확인.
- 동일 player_id 두 슬롯 점유 금지; resume는 검증한 ID와 기존 슬롯 ID 및 회전형 reconnect_token 모두 일치해야 함.
- 표시 nickname은 서버가 확인한 값으로 참가 시 고정한다. 기존 참가자 표시・미니맵 유지.
- 초기 연결・방 요청 8초 deadline; 경기 reconnect 60초・rematch 20초 유지. 취소・실패는 모든 입력 해제.
- LAN은 지정 bind IP와 허용 CIDR, loopback test 가능; 운영 기본 0.0.0.0 금지.

## 앱 세션
- 신규 DemoGuestClient, user://demo_guest_session.json. 기존 DbProfileClient와 별개. api_url/player_id/refresh_token/갱신 중 successor만 저장, access는 메모리. 원자적 파일 교체; refresh 재시도는 기존 규칙 재사용.
- login(api_url,new_guest=false), set_nickname(value), cancel(); nickname/player_id/access_token/error/session_invalid/busy 제공. 토큰 변경 저장 실패면 온라인 진입 금지. 만료는 명시적인 새 게스트 선택, 자동 생성 금지.
- 서버 주소 변경은 기존 세션 덮어쓰기 금지; 명시적 새 게스트 확인. 기존 기기 보유・설정 유지.
- LAN UI는 코드→게스트 login→닉네임 설정(필요 시)→기존 방 진입, 경기 중 변경 UI 차단. 데모 export feature demo; 개발 DB 메뉴 숨김.

## 소비자와 검사
API・PostgreSQL migration・LAN server・LanInvite・DemoGuestClient・LAN client・app UI・runtime tests・host scripts를 함께 갱신한다. v1은 update 안내로 거부. 기존 개발 인증・DB 프로필과 전투 규칙은 유지한다.
