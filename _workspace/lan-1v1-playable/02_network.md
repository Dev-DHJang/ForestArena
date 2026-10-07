# LAN 전송 구현

- `server/game/lan_game_server.gd`: `0.0.0.0`에 열 수 있는 Godot WebSocket 한 경기 서버.
- `scripts/network/lan_match_client.gd`: 방 생성·참가, 입력, 상태 표시, 재접속과 명시적 퇴장.
- `scripts/lan-host.sh`: macOS 사설 IPv4를 찾아 시작·상태·로그·종료를 제공한다.
- 서버와 앱은 기존 DB·TypeScript 개발 온라인 경로를 호출하지 않는다.
- 의도적 퇴장은 WebSocket을 닫기 전 한 프레임 동안 패킷을 내보내 방이 60초 대기 상태로
  남지 않게 한다.
