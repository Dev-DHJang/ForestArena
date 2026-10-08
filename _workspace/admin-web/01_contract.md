# 관리자 웹 공용 데이터 약속

## 서버 구조

Java 패키지 `com.forestarena.admin`, Spring Boot 4.1.1, Java 21, Jackson 2 명시 의존성 사용. Maven Wrapper. 모든 API는 `/admin/api/v1`. JSON 오류 `{error: 한국어 또는 안전한 코드}`. 페이지 `{items: [], total: 숫자, page: 1부터, size: 기본25 최대100}`. 검색 `q`. UUID와 시간은 문자열. 서버 127.0.0.1:8080.

## 인증·계정 (auth 역할 소유)

GET `/auth/csrf` → `{token, headerName}`. POST `/auth/login` JSON `{login_id,password}` → 사용자. GET `/auth/me` → `{id,login_id,display_name,email,role,active,must_change_password}`. POST `/auth/logout`. POST `/auth/password` `{current_password,new_password}`. 변경 의무 계정은 csrf/me/logout/password 외 API 금지.

GET/POST `/admins`; POST 생성 `{login_id,display_name,email,role,password,reason}`. PATCH `/admins/{id}` `{display_name,email,role,active,reason}`. POST `/admins/{id}/reset-password` `{temporary_password,reason}`. POST `/admins/{id}/end-sessions` `{reason}`. 계정 변경은 최고관리자만. 생성도 초기 비밀번호 변경 의무.

현재 로그인 계정 ID는 `Principal.getName()`이 UUID. 역할은 `ROLE_SUPER_ADMIN`, `ROLE_OPERATOR`, `ROLE_VIEWER`. `CryptoService.encrypt(String)` / `decrypt(String)`은 문자열 봉투를 사용한다. 암호화 사유는 이 서비스 사용. 계정 관리 audit는 `admin.audit_log(actor_id,action,target_id,reason_encrypted,before_data,after_data)`에 추가. 계정 이름·이메일은 audit JSON에 평문으로 넣지 않는다.

## 데이터 API (data 역할 소유)

최신 develop 기준 프로필 schema_version=3이며 nickname/minimap을 포함한다. Java/웹은 worktree의 profiles.ts 검증·v2 이전 규칙을 그대로 적용하고 이 값을 보존한다.

GET `/dashboard` → `{guests,profiles,matches,db_status,game_api_status,recent_matches:[],recent_actions:[]}`.
GET `/catalog` → 기존 `server/api/src/profile_catalog.json` 내용.
GET `/guests` → 페이지(guest = app.players, player_id/display_name/created_at). GET `/guests/{id}` → `{player,profile,revision}`. 프로필 없으면 profile null.
GET `/profiles` → 페이지(player_id/display_name/profile/revision/updated_at). GET `/profiles/{id}` → `{player_id,profile,revision}`.
PUT `/profiles/{id}` → `{request_id,expected_revision,reason,profile}`; 응답 `{profile,revision}`. 운영자 이상만. 첫 지급 여부 보존. 같은 request_id는 같은 actor/player/body이면 같은 응답, 달라지면409. 기존 app.profile_requests 변경 금지.
GET `/matches` → 페이지 app.matches. GET `/matches/{id}` → `{match,participants:[]}`.
GET `/audit` → 페이지(id,actor_id,action,target_id,reason,before_data,after_data,created_at).

## DB (조율 역할 소유)

기존 번호순 다음 migration. `forest_arena_admin_web` LOGIN 역할은 migration에서 비밀번호 없이 생성, 별도 로컬 설정 명령에서 비밀번호 설정. schema admin:
accounts(id uuid PK,login_id text UNIQUE,password_hash text,display_name_encrypted text,email_encrypted text,role text,active boolean,must_change_password boolean,session_version bigint default0,created_at timestamptz,updated_at timestamptz).
sessions(id text PK,account_id uuid FK,session_version bigint,created_at timestamptz,last_seen_at timestamptz) — 실제 Spring HttpSession ID의 SHA256만 저장.
login_limits(scope text,key_hash text,failures int,locked_until timestamptz,window_started_at timestamptz, PRIMARY KEY(scope,key_hash)).
audit_log(id bigint generated identity PK,actor_id uuid,action text,target_id text,reason_encrypted text,before_data jsonb,after_data jsonb,created_at timestamptz default now()).
requests(actor_id uuid,player_id uuid,request_id uuid,request_hash text,response jsonb,created_at timestamptz default now(),PK(actor_id,player_id,request_id)).
전용 역할은 app.players/matches/match_participants/player_profiles SELECT, player_profiles의 profile/revision/updated_at UPDATE만. admin.accounts/sessions/login_limits SELECT INSERT UPDATE DELETE; audit_log/requests SELECT INSERT만. audit sequence USAGE SELECT. app 역할 admin 접근 없음.

## 실행 환경

Spring properties 환경: ADMIN_DB_URL, ADMIN_DB_USER, ADMIN_DB_PASSWORD, ADMIN_KEY_FILE, GAME_API_URL. 키 파일은 Git·DB 밖 권한0600 JSON `{active:"키ID",keys:{"키ID":"32바이트 base64"}}`. CryptoService가 키 생성/교체 CLI 구현. 최초 계정 CLI `bootstrap <login_id> <display_name>` 숨김 비밀번호; `recover <login_id>` 숨김 임시 비밀번호. CLI는 web-application-type=none.
