# 네트워크 구현 기준

- HTTP와 WebSocket payload는 `protocol_version: 1`을 사용한다.
- 입력은 연결별 단조 증가 seq로 중복과 역순을 버린다.
- snapshot은 권위 상태이며 클라이언트는 전투 결과를 계산하거나 서버에 주입하지 않는다.
- 로그에는 correlation ID, match ID, slot과 오류 코드만 남기고 access·refresh·match·reconnect token은 남기지 않는다.
- 기본 포트 공개는 loopback이다. LAN은 `FOREST_ARENA_SERVER_BIND_HOST=0.0.0.0`과 광고 주소를 함께 지정한 경우만 허용한다.
