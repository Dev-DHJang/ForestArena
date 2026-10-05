# 조율 기록

## 적용 순서

1. ADR-008·025와 HTTP·WebSocket·DB 계약을 먼저 고정했다.
2. PostgreSQL migration 0002와 앱 계정 경계를 추가했다.
3. TypeScript API의 게스트 인증·토큰 회전·2인 매칭·결과 저장을 구현했다.
4. Godot 4.7.1 headless 권위 서버와 개발 클라이언트를 같은 `WebSocketMultiplayerPeer` 계약으로 연결했다.
5. 정적 계약, 실제 컨테이너, 두 Godot 클라이언트 런타임, 기존 오프라인 회귀를 순서대로 확인했다.

## 경계

- 현재 제품 단계는 Phase 3 완료로 유지한다.
- API만 PostgreSQL 앱 계정을 사용한다. 게임 서버와 클라이언트는 DB에 직접 연결하지 않는다.
- 기본 공개 주소는 loopback이다. LAN은 환경값 두 개를 함께 바꾼 명시적 개발 시험에서만 사용한다.
- 물리 Android 기기 통과는 이번 기록에 포함하지 않는다.
