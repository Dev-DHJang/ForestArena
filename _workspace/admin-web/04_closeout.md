# 관리자 웹 마무리 기록

상태: 구현·검증·독립 검토와 PR #70의 develop 병합 완료.

## 결과

- Java 21·Spring Boot 4.1.1·Spring Security/JDBC·Maven Wrapper와 Vue 3·TypeScript·Vite·Router·Element Plus 관리자 웹을 추가했다. 정확한 버전은 pom·dependency-lock.txt·package-lock.json에 기록했다.
- 한국어 대시보드·관리자 관리·게스트/프로필 편집·경기/작업 이력과 서버 권한 검사를 제공한다. 기존 TypeScript API와 프로필 v3·v2 이전 규칙을 유지한다.
- Argon2id·AES-256-GCM 외부 키·키교체·숨김입력 최초계정/복구·CSRF·출처 검사·세션 만료/종료·로그인 제한·마지막 최고관리자 보호를 구현했다.
- 관리자 프로필 변경은 행 잠금·변경 번호·중복 요청·전후 이력을 한 트랜잭션으로 저장한다. 기존 게임 요청 기록은 변경하지 않는다.
- 원본 작업 공간의 캐릭터·모션·AGENTS 등 미완료 변경은 별도 작업 공간을 사용해 보존했다.

## 실행 증거

- `./scripts/verify-admin-web.sh`: Java 핵심 17개 + 브라우저용 데이터 준비 1개, TypeScript 9개, 실제 Spring 서버 Playwright 4개 모두 통과. 브라우저 건너뜀 0개. 최종 실행 로그 `/tmp/forest-admin-web-resume.log`.
- `./scripts/verify-admin-db.sh`: 전용 역할의 최소 권한과 게임 역할의 admin 접근 거부 실제 통과.
- `./scripts/verify.sh`, `./scripts/verify-docs.sh`, `./scripts/verify-database.sh`: 통과. 전체 기본 검사 로그 `/tmp/forest-admin-verify.log`.
- `./scripts/verify-db-profile-runtime.sh`: Godot 앱의 저장·재실행 복원·SQL 일치 실제 통과. `/tmp/forest-admin-profile-runtime.log`.
- `./scripts/server-dev.sh verify-runtime`: 실제 온라인 두 클라이언트 연결·결과 저장 통과. `/tmp/forest-admin-server-runtime-final.log`.
- 이름 있는 수동 재검사 `FRESH_DB_MIGRATION`: 별도 빈 DB에 마이그레이션 5개·백업·재실행을 적용하여 `5:development` 확인 후 임시 DB 제거·환경 파일 복원.
- 이름 있는 수동 재검사 `LOCAL_ADMIN_LIFECYCLE`: 시작 뒤 별도 명령의 status·HTTP 200, 중지·중지 상태·재시작 확인. 서버는 빌드 파일의 별도 복사본에서 독립 프로세스로 실행한다.
- Vite 프록시 정상 출처 200·다른 로컬 포트/외부 출처 403은 독립 QA가 실제 확인했다.
- 최초 브라우저 검사에서 발견한 세션 중복 종료와 정적 파일 접근 문제를 수정하고 SessionGuardTest 2개 및 전체 브라우저 흐름으로 재확인했다.
- QA 1회 fix 후 수정, QA 2회 pass. 상세 근거는 `03_qa_r01.md`, `03_qa_r02.md`.
- Android 실기기는 이번 관리자 웹 작업에서 검사하지 않았다.

## DB와 키

개발 DB 변경 전 `database/backups/forest_arena_dev_20261008T084426Z.dump`를 만들고 0005를 적용했다. 검사 데이터는 별도 `forest_arena_admin_test_dev`에만 만들었다. 자격·키·테스트 비밀번호는 Git 밖의 권한 0600 파일에 보관한다. 기존 API 컨테이너가 v2를 반환해 최신 develop v3로 재빌드한 뒤 기존 연결 검사를 다시 통과했다.

실제 개발 DB의 최고관리자는 만들지 않았다. 사용자가 터미널에서 `./scripts/admin-dev.sh bootstrap <ID> <표시이름>`으로 숨김 입력한다. 기본 계정·비밀번호는 없다. 관리자 웹은 `http://127.0.0.1:8080`에서 실행 중이다. 운영·복구 방법은 `docs/engineering/admin-web.md`를 따른다.

## 저장소와 롤백

- 기준: 최신 origin/develop `553091b972a4a684b7816e4636f6f6328654f94c`.
- 작업 브랜치: `feature/admin-web`.
- PR: https://github.com/Dev-DHJang/ForestArena/pull/70
- 최종 구현 commit: `14be818505cda82d7d075f8c920a144d554dff51`.
- develop 병합 SHA: `98a02c91886f12f541e48674ab1c8fd9fc3c7930` (2026-10-08 13:27 UTC).
- GitHub PR의 `MERGED` 상태와 origin/develop의 동일 SHA를 실제 확인했다. 별도 원격 CI 검사는 등록되어 있지 않아 독립 QA와 실행한 로컬/실제 연결 검사 근거로 병합했다.
- 병합 SHA 기록은 최신 develop에서 만든 `docs/admin-web-closeout` 문서 PR로 저장한다.
- 롤백: 관리자 서버를 중지하고 관련 commit을 revert한다. DB·키는 별도 백업에서 복구하며 기존 게임 요청과 관리자 이력을 자동 삭제하지 않는다. `main` 승격·브랜치 삭제·강제 push는 수행하지 않는다.
