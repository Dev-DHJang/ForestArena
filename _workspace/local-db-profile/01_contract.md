# 프로필 계약 v1

프로필은 LocalPlayerStore schema_version 2 형식이다. 같은 Godot 카탈로그에서 만든 캐릭터·장신구 ID를 서버가 검사한다. 지급 전 보유 목록은 비어 있고 지급 후 선택 장비는 보유 목록에 있어야 한다. 접근성은 기존 배율 세 가지와 boolean 설정 두 가지다.

- GET /v1/profile: {profile, revision} 또는 404 profile_missing.
- POST /v1/profile/import: {profile}. 기록이 없을 때만 revision 1로 생성하며 기존 기록은 보존한다.
- POST /v1/profile/actions: {request_id, expected_revision, action, payload}. action은 grant_first, purchase, select, accessibility다. 성공은 {profile, revision}, 입력 오류 400, 변경 번호 충돌 409 revision_conflict, 동일 요청 ID의 다른 본문 409 request_id_conflict다.

게스트 ID로 자신의 기록만 접근한다. 행 잠금과 트랜잭션으로 중복·동시 요청을 처리한다. 응답 유실 시 같은 요청 ID로 재시도한다. 충돌 시 최신 DB 프로필을 읽고 다시 조작하도록 안내한다. DB·연결 실패 시 기존 화면 상태를 유지한다.

DB가 비었을 때만 유효한 기기 저장을 이전하며 원본을 보존한다. 세션은 API 주소에 묶어 별도 파일에 저장한다. 인증 갱신 실패 시 새 게스트를 자동 생성하지 않는다. 마이그레이션은 기존 기록을 보존하고 롤백은 코드 revert와 기기 저장 모드로 한다.

POST /v1/auth/refresh는 선택 필드 next_refresh_token을 허용한다. DB 프로필 클라이언트는 32바이트 무작위 새 토큰을 요청 전에 기기에 기록한다. 서버는 이전 hash에 정확한 다음 hash를 연결하고 동일한 두 토큰의 재시도만 허용한다. 이전 토큰 단독 재사용과 다른 다음 토큰은 거부한다. DB에 원문 토큰은 저장하지 않으며 기존 필드만 쓰는 온라인 클라이언트도 호환된다.
