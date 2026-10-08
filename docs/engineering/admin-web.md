# 로컬 관리자 웹

ADR-030의 개발 도구다. 기존 TypeScript 게임 API를 유지하고 Spring이 같은 PostgreSQL의 필요한 표만 읽고 프로필만 수정한다. 접속 주소는 `http://127.0.0.1:8080`이다. 인터넷 배포, 플레이어 정식 계정, 접속 차단, 성장·재화·결제와 경기 결과 변경은 제공하지 않는다.

## 시작·중지

Java 21, Node.js 22.12 이상과 기존 Docker·PostgreSQL이 필요하다.

```sh
./scripts/server-dev.sh up
./scripts/admin-dev.sh setup
./scripts/admin-dev.sh build
./scripts/admin-dev.sh key-init
./scripts/admin-dev.sh bootstrap my.admin 관리자
./scripts/admin-dev.sh start
./scripts/admin-dev.sh status
./scripts/admin-dev.sh stop
```

`bootstrap`은 터미널에서 비밀번호를 숨김 입력받는다. 기본 계정과 기본 비밀번호는 없다. 비밀번호는 15~128자다. 최초 계정 생성은 최초 최고관리자가 없을 때만 허용한다. 추가 계정은 최고관리자가 웹에서 만든다. 웹에서 만든 계정의 초기 비밀번호와 복구·초기화 임시 비밀번호는 다음 로그인 때 변경해야 한다.

개발 중에는 `web/admin`에서 `npm ci && npm run dev`를 실행한다. Vite는 관리자 API를 Spring으로 전달한다. 배포 빌드는 Spring이 Vue 파일을 제공한다.

## 화면과 권한

- 최고관리자(`SUPER_ADMIN`): 조회·프로필 수정과 관리자 계정 생성·권한 변경·비활성화·비밀번호 초기화·세션 종료.
- 운영자(`OPERATOR`): 조회와 게임 프로필 수정.
- 조회자(`VIEWER`): 조회만.

서버가 모든 권한을 검사한다. 마지막 활성 최고관리자의 비활성화와 권한 강등은 거부한다. 계정의 권한·비밀번호·활성 상태를 바꾸면 기존 로그인 세션을 종료한다.

대시보드는 게스트·프로필·경기 수, 최근 경기·관리 작업, DB와 게임 API 연결 상태를 보여준다. 게스트·프로필·경기·작업 이력은 검색·목록·상세로 확인한다. 목록은 기본 25개, 최대 100개다. 경기 결과는 조회만 가능하다.

프로필 편집은 보유·선택·상대 캐릭터·접근성 설정과 기존 닉네임·미니맵 설정을 보존한다. 선택 항목을 회수하려면 대체 선택을 함께 지정한다. 첫 지급 여부는 바꾸지 않는다. 저장 시 변경 이유를 입력한다. 다른 게임 또는 관리자가 먼저 저장하면 `409`로 거부하므로 최신 값을 다시 확인한다. 응답을 받지 못하면 같은 요청 ID와 같은 내용으로 재시도한다. 기존 게임 요청 기록은 수정·삭제하지 않는다.

관리자 변경은 게임의 다음 프로필 조회에 반영된다. 실행 중인 게임은 재접속하거나 프로필을 다시 조회해야 한다.

## 비밀번호·키·세션

비밀번호는 Argon2id의 메모리 19MiB 이상·반복 2회·병렬도 1로 해시한다. 표시 이름·선택 연락 이메일·작업 이력 사유는 AES-256-GCM으로 암호화한다. 로그인 ID는 고유 식별자로 평문 저장한다. 계정별 연속 실패 5회는 15분 잠금이며 IP별 시도 제한도 적용한다.

기본 외부 저장 위치는 `~/Library/Application Support/ForestArena/admin/`이다. 폴더 권한은 0700, DB 자격 파일 `db.env`와 키 파일 `keys.json`은 0600이어야 한다. `FOREST_ARENA_ADMIN_STATE_DIR`로 위치를 바꿀 수 있다. 키는 Git·DB·DB 백업에 포함하지 않는다. 키 식별자가 암호문에 들어가며 무작위 nonce와 인증 태그로 변조를 검출한다.

```sh
./scripts/admin-dev.sh stop
./scripts/admin-dev.sh rotate-key
./scripts/admin-dev.sh start
./scripts/admin-dev.sh recover my.admin
```

키 교체는 새 활성 키를 만들고 계정 암호문을 다시 암호화한다. 추가 전용 작업 이력의 이전 암호문을 읽기 위해 이전 키를 보존한다. 키 교체 후에는 별도 보관 중인 키 백업도 갱신한다. 복구 명령은 터미널에서 임시 비밀번호를 숨김 입력받고 기존 세션을 종료한다.

서버 세션은 유휴 30분·최대 8시간이다. 로그인 성공 시 세션 ID를 바꾸고 쿠키에 `HttpOnly`, `SameSite=Strict`를 적용한다. `Secure` 예외는 이 로컬 HTTP 실행에만 해당한다. CSRF 토큰과 같은 출처 검사, 보안 헤더, 입력 검증과 매개변수 SQL을 사용한다. 로그에 비밀번호·세션 값·키를 기록하지 않는다.

## DB 변경·백업·복구

번호순 마이그레이션을 유지한다. 적용된 파일은 수정하지 않는다. 기존 DB에 새 변경을 적용하기 전 `db-dev.sh migrate`가 백업을 만든다. 관리자 전용 역할 `forest_arena_admin_web`은 프로필의 지정 열만 수정할 수 있다. 관리자 작업 이력·중복 요청 기록은 추가·조회만 가능하다. 게임 역할은 `admin` 스키마에 접근할 수 없다.

```sh
./scripts/admin-dev.sh stop
./scripts/db-dev.sh backup
# 키 파일은 암호화한 별도 보관소에 따로 복사하고 권한 0600을 유지한다.
./scripts/db-dev.sh restore database/backups/선택한.dump --confirm-development
# 복원한 DB 암호문에 필요한 키 식별자가 모두 있는 keys.json을 별도로 복구한다.
./scripts/admin-dev.sh setup
./scripts/admin-dev.sh start
```

DB 백업과 키 백업은 별도 위치에 보관한다. 키를 잃으면 암호화된 이름·이메일·이력 사유를 복구할 수 없다. 복구 후 로그인·이력 복호화·프로필 조회를 확인한다. DB 비밀번호는 `setup`이 외부 자격 파일과 동기화한다. 볼륨 삭제·기존 표 삭제는 자동 수행하지 않는다.

## 검사

```sh
./scripts/verify-admin-db.sh
./scripts/verify-admin-web.sh
./scripts/verify-db-profile-runtime.sh
./scripts/server-dev.sh verify-runtime
./scripts/verify.sh
./scripts/verify-docs.sh
```

관리자 검사는 암호화·키 교체, 인증·권한·CSRF·잠금·세션 종료·최고관리자 보호, 프로필 동시 수정·중복 요청·전체 취소와 Java/TypeScript 공용 예제를 확인한다. 브라우저 검사는 별도 테스트 계정으로 전체 흐름을 확인한다. 상세 실행 결과와 미확인 항목은 `_workspace/admin-web/`에 기록한다. Android 기기 검사는 실제 수행한 경우에만 기기 통과로 기록한다.

기술 근거: [Spring Boot 지원 환경](https://docs.spring.io/spring-boot/system-requirements.html), [Vue 설치](https://vuejs.org/guide/quick-start.html), [Vite 지원 환경](https://vite.dev/guide/), [OWASP 비밀번호 저장](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html), [OWASP 암호화 저장](https://cheatsheetseries.owasp.org/cheatsheets/Cryptographic_Storage_Cheat_Sheet.html), [Spring Security CSRF](https://docs.spring.io/spring-security/reference/servlet/exploits/csrf.html).
