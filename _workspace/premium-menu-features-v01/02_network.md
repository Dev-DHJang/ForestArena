# 메뉴 서버 구현과 확인

2026-10-15. ADR-033과 [공용 계약](01_contract.md)의 제한된 개발 서버 기능이다. 기존 프로필 v3, auth refresh, LAN v2와 duel_dev 결과 경로는 유지한다. 이 문서는 서버 역할의 전달 기록이며 최종 검사는 아래에 갱신한다.

## 구현 파일과 저장

- 실제 SQL 위치는 `database/migrations/0007_menu_services.sql`이다. 원본 player·profile·duel_dev 경기 행을 삭제하지 않고 canonical_player_id(여러 원본을 하나로 읽을 대상 ID)와 메뉴 전용 테이블을 추가한다.
- DB에 service UUID 하나를 저장하므로 API 프로세스 재시작·주소 별칭에 따라 새 UUID를 만들지 않는다.
- 통합은 대상 Bearer와 같은 서버 서명의 source token을 검증한다. 보유 합집합에 현재 선택·설정을 유지하고 최종 닉네임을 한 DB 트랜잭션으로 기록한다. 빈 현재 프로필이면 대상의 유효한 선택을 이어받는다. 원본 ID·원본 프로필·기록과 통합 당시 두 프로필 백업을 보존한다.
- 통합과 기존 v3 import/action은 같은 DB 잠금을 사용한다. 구매가 통합과 겹쳐도 원본에 뒤늦게 쓰여 보유가 누락되지 않는다. refresh의 player_id는 기존 원본 ID를 유지하며 실제 프로필·닉네임·메뉴 데이터는 통합 대상으로 읽는다.
- 동일 통합 request_id와 같은 원문 내용은 최초 응답을 반환한다. 재전송 시 주 Bearer는 유효해야 하지만 이미 성공한 source token은 만료돼도 원문 그대로 재전송할 수 있다. source token 원문은 DB에 저장하거나 로그로 출력하지 않는다. 미커밋 통합의 source 증명 실패는 409 source_authentication_required로 구분하고 전체 취소한다. 주 Bearer 실패는 기존 401이며, 이미 성공한 동일 요청은 이 검증 전에 최초 응답을 반환한다.
- 과거 A-B LAN의 A와 B가 나중에 같은 사용자로 묶이면 원본 경기 행은 남기고 전적·미션·순위에서 해당 경기를 제외한다. 오프라인 기록과 duel_dev는 LAN 순위를 바꾸지 않는다.

## 앱·LAN 전달 세부 항목

- 미션 id: `daily-play`, `daily-win`, `weekly-play`, `weekly-win`, `first-play`, `ten-play`, `all-characters`. period는 KST 날짜 `YYYY-MM-DD`, KST 주 시작 월요일 `YYYY-MM-DD`, 누적 `all`이다. current는 전체 정상 기록으로 계산하며 화면 history만 최신 50개다. character_ids는 전체 정상 경기의 중복 없는 캐릭터 ID 목록이며 미전송 기기 기록과의 합집합에 사용한다.
- progress stats.modes의 키는 ai/solo/team/lan이고 각각 played/wins/losses/draws를 가진다. history.source는 offline 또는 lan이다. offline ended_at은 UTC Z 형식의 실제 날짜이며 2000-01-01 이상·현재+5분 이하다. 더 오래된 과거 기록도 허용한다. source를 보낼 때 offline만 허용한다.
- social/action은 별도의 필수 operation_id UUID로 재전송을 구분한다. request_id는 친구 요청 대상, invite_id는 초대 대상이다. 응답은 status와 생성된 request_id/invite_id, 초대 수락이면 invite_code를 포함한다. 같은 actor+operation_id의 내용이 다르면 request_id_conflict다.
- 친구·보낸/받은 요청·초대·최근 상대는 통합된 ID를 기준으로 중복과 본인을 제외한다. 친구 접속은 마지막 online 신호 후 90초가 지나면 오프라인이다.
- rooms는 room_code+invite_code를 함께 식별한다. 서비스가 보낸 updated_at UTC를 저장하며 과거 waiting 재전송으로 수명을 늘리지 않는다. 90초 지난 waiting과 closed 방에는 새 초대·초대 수락이 불가능하다. 초대 자체는 120초 뒤 만료된다. 방의 90초 heartbeat 만료와는 별도다.
- leaderboard.win_rate는 0~1 비율이며 rank는 동점 공동 1,1,3 방식이다. 월간은 KST 월이고 page는 50개다. 0경기 사용자는 own=null이다.
- 기존 public guest/profile 응답은 원래 player_id와 nickname 두 필드를 유지한다. 내부 LAN auth는 player_id가 통합 ID다. 선택 필드 existing_player_ids(최대2개)를 보내면 canonical_players의 rawID→통합ID 대응을 함께 반환하여 방 대기 중 통합된 중복 참가자를 검사할 수 있다.

## 오류와 실패 처리

기존 {error:string} HTTP 응답을 유지한다. 400은 값/시각/ID 형식 오류, 401은 토큰 또는 존재하지 않는 원본 사용자, 403은 다른 사람 요청·초대 조작, 404는 미등록 경기·없는 프로필, 409는 nickname_taken/request_id_conflict/event_id_conflict/request_pending/already_friends/stale_request/stale_invite/room_not_waiting/result_conflict 등이다. 실패한 DB 작업은 전체 취소한다.

## 검사 환경

root 승인으로 꺼져 있던 Colima를 시작했다. 기존 개발·운영 DB와 볼륨은 바꾸지 않고 `forest-menu-api-test-<UUID>` 임시 PostgreSQL 컨테이너, `forest_menu_api_test_<UUID>` DB, 자동 할당된 API 포트만 사용한다. 검사 도구가 자기 컨테이너와 API만 종료한다. Colima 최종 종료는 root가 결정한다.

- `npm --prefix server/api test`: 14개 PASS.
- `python3 server/api/tests/run_menu_runtime.py`: 최종 메뉴 실제 PostgreSQL 97개 확인, 기존 PROFILE_API_RUNTIME와 DEMO_GUEST_API_RUNTIME, API 재시작의 service UUID 보존 PASS. [실행 로그](server-runtime.log)를 남겼다.

실제 Android 기기·LAN 두 기기 검사는 서버 단위·통합 검사로 대신 통과 처리하지 않는다.

## 최종 확인 세부

격리 실행 도구의 `--godot-profile`로 기존 DB 프로필 검사의 실제 Godot 쓰기/복원 두 프로세스와 `PROFILE_GAME_SQL`(게임 상태와 DB 행 동일)도 통과했다. 종료 시 기존 ObjectDB 4개/resource 2개 경고가 함께 나왔으며 root에 전달했다. 단순 서버 검사로 이 Godot 결과를 대신하지 않았다.

마지막 PostgreSQL 검사에는 원 source token이 실제로 만료된 뒤 성공 통합의 같은 요청 재전송, 실패 source 증명의 미커밋 확인, 통합/기존 구매 동시 실행, 8개 동시 내부 LAN 인증, 별도 operation_id 재전송, 초대 120초와 방/접속 90초 경계, KST 월간·동점 순위, 통합된 과거 자기 경기 제외와 원본 행 보존을 포함했다. 동일 시각의 waiting/closed는 closed를 우선하여 초 단위 방 종료 신호도 반영한다.

검사 도구는 `--godot-test res://tests/<파일>.gd`를 반복해서 받을 수 있다. 환경 변수로 같은 격리 API를 전달하며 `--skip-build`는 이미 컴파일한 산출물을 사용하는 독립 QA용 옵션이다. 임시 DB의 초기 Unix 서버를 준비 완료로 오인하지 않도록 최종 TCP 서버 준비까지 확인한다. 실행이 끝난 임시 컨테이너는 제거됐으며 Colima는 root의 다른 작업을 위해 켜 두었다.

## 실제 LAN 서버 → API → DB 실행 확인

`python3 server/api/tests/run_menu_runtime.py --skip-build --lan`이 통과했다. [전체 실행 로그](server-lan-runtime.log)와 [실제 LAN 서버 로그](lan-menu-server.log)를 남겼다. LAN 구간은 27.9초였으며 두 실제 경기의 종료 tick은 687·690이다.

새 [LAN 실행 검사](../../tests/lan_menu_api_runtime.gd)는 별도 Godot 서버 프로세스와 실제 인증 게스트 두 명을 사용한다. API에서 정한 닉네임과 나비·유란 선택을 확인하고, 호스트가 왼쪽으로 걷는 PRESS/HOLD 입력을 매 프레임 보내 3→2→1 기회를 실제 snapshot에서 관찰했다. HP·기회·위치·승패를 강제로 고치지 않고 두 경기 모두 정상 combat 결과로 종료했다.

첫 경기의 실제 API 전적·순위를 확인한 다음 API 프로세스를 중단하고 재대전했다. 새 match UUID와 pending 상태를 확인했고, 전송 대기 파일에 등록→결과 순서가 함께 남는지 검사했다. 이어 LAN 서버를 종료하고 같은 대기 파일로 새 프로세스를 시작한 뒤 API를 복구했다. 누락·중복 없이 2승과 서로 다른 두 경기 기록이 조회됐다. 서비스 토큰은 환경 변수로만 전달하며 대기 파일에 없는 것도 확인했다.

이 실행에 앞서 메뉴 API 97개 검사, 뒤이어 기존 프로필·게스트 API와 service UUID 재시작 확인도 함께 통과했다. API 중단의 빈 응답에서 root가 수정한 JSON 진단 오류는 최종 서버 로그에 없었다. 사용한 임시 DB/컨테이너·API·LAN 프로세스는 모두 정리했다. 이 결과는 실제 Android 두 기기의 무선 LAN 검사를 뜻하지 않는다.
