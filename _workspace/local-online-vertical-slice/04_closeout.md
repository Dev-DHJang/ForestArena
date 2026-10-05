# 종료 기록

## 결과

- `./scripts/server-dev.sh up` 한 명령으로 PostgreSQL 18.6, TypeScript API와 Godot 4.7.1 headless 권위 서버를 빌드하고 시작한다.
- 15분 access token, 한 번만 쓸 수 있는 30일 refresh token, 60초 match ticket과 회전형 reconnect token을 구현했다.
- 자현 대 묘령 고정 2인전은 서버 60Hz 판정과 20Hz snapshot으로 동작한다. 연결 해제 시 입력을 풀고 60초 동안 같은 slot 재접속을 허용한다.
- 경기 결과는 API를 거쳐 PostgreSQL에 한 번만 기록되며 게임 서버는 DB 자격 증명을 갖지 않는다.
- 오프라인 기본 실행은 바꾸지 않고 `scenes/online_dev.tscn`을 개발 진입점으로 추가했다.

## 검증

- 계약·단위·Godot 리소스·문서·하네스 검사와 컨테이너 healthcheck를 통과했다.
- 최신 Phase 6 `develop` 위로 재배치한 뒤 권위 서버 이미지의 전체 스크립트 로드와 준비 표식 기반 healthcheck를 다시 통과했다.
- 두 실제 Godot 네트워크 클라이언트로 매칭, 입력, snapshot, ticket 재사용 거부와 재접속을 확인했다. 이어서 60초 연결 해제 유예를 실제로 만료시켜 기권 종료와 PostgreSQL 결과 저장, 중복 제출 거부까지 확인했다.
- `./scripts/verify.sh`, `./scripts/verify-database-runtime.sh`, `./scripts/export-debug-android.sh`를 종료 코드 0으로 통과했다.
- GitHub CLI 로그인 정보가 없는 환경이므로 검증된 feature 커밋을 원격 `develop`에 fast-forward 방식으로 통합한다.

## 제한

- 정식 계정·로비·선택 UI·랭크·보상·성장·경제·클라우드·8인전은 포함하지 않는다.
- 개발 클라이언트의 refresh token 파일은 평문 개발 편의이며 운영 방식이 아니다.
- 물리 Android 기기는 확인하지 않았으므로 기기 통과로 기록하지 않는다.

## 롤백

- API·게임 서버·온라인 개발 scene과 migration 0002를 역방향 migration으로 제거한다.
- ADR-025 예외를 되돌려도 ADR-008의 미래 서버 권위 원칙은 유지한다.
