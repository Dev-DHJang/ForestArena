# 개발계 데이터베이스 계약

- DB 종류: 로컬 PostgreSQL 18.6 컨테이너다. 개발계는 `127.0.0.1:55432`에서만 연다.
- 이름과 계정: DB 이름은 `forest_arena_dev`다. 관리자 `forest_arena_admin`은 마이그레이션을 실행하고, 앱 계정 `forest_arena_app`은 `app` 스키마의 데이터만 읽고 쓴다.
- 마이그레이션: `database/migrations`의 번호 순서 SQL 파일을 한 번만 적용하고, 파일 SHA-256을 `infra.schema_migrations`에 기록한다. 적용 뒤 파일을 바꾸면 중단한다.
- 환경 표식: `infra.environment_guard`의 단일 행은 개발계에서 `development`다. 복원과 초기화는 이 표식, 로컬 호스트, `_dev` 이름과 확인 인자를 모두 만족해야 한다.
- 호환과 롤백: 새 SQL 파일을 추가해 확장한다. 적용한 SQL 파일을 고치지 않는다. 데이터 삭제 전에는 `backup`을 실행하며, 개발계 초기화는 `--confirm-development` 없이는 실행하지 않는다.
- 범위: 현재 빈 `app` 스키마만 둔다. CharacterData, JobData, AccessoryData, RuntimeCombatProfile, 게임 저장, 계정과 네트워크 메시지 형식은 바꾸지 않는다.
