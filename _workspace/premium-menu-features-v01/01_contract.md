# 메뉴 기능 공용 연결 규칙 v1

## 승인과 호환

사용자의 계획 승인에 따른 ADR-033의 제한된 개발 서버 확장이다. 프로필 v3·프리셋/조작 v1·LAN v2 필수 필드를 유지한다. 추가 데이터는 버전 1로 저장한다. 시간은 RFC3339 UTC이며 일일/주간/월간 구분은 Asia/Seoul이다.

## API (서버·앱 공통)

모든 /v1 메뉴 API는 Bearer 인증한다. service만 공개다. 기존 /v1/profile 및 auth API는 유지한다. 응답 오류는 {error: string}, HTTP 4xx/5xx로 구분한다. 동일 요청 ID와 내용은 재전송해도 중복 반영하지 않으며 다른 내용 재사용은 거부한다.

- GET /v1/service → {service_id: UUID, protocol_version:1}. 재시작과 URL 별칭에도 같은 DB는 같은 ID다.
- GET /v1/identity → {player_id, canonical_player_id, nickname, service_id}.
- POST /v1/identity/merge → {request_id:UUID, source_access_token?:string, nickname:string, profile:ProfileV3}. 주 Bearer가 대상이다. source는 같은 서버 서명으로 소유를 증명한다. 이미 성공한 요청은 먼저 조회해 원문 그대로 재현한다. 미커밋 요청의 source 인증 실패는 409 source_authentication_required로 구분해 기존 계정을 다시 인증하고 새 요청을 만들 수 있다. 현재 profile의 선택·설정, 서버 보유 합집합. 응답 {player_id,canonical_player_id,nickname,service_id,profile,revision}. 두 원본 ID와 원본 기록은 보존하고 서버가 canonical로 연결한다. 인증 refresh 응답 player_id는 기존 token 소유 ID를 유지하여 구형 세션을 깨지 않는다. 실제 데이터 API는 canonical로 해석한다.
- GET /v1/progress → {missions:[{id,category,title,current,target,completed,period}], stats:{offline:{played,wins,losses,draws},lan:{played,wins,losses,draws},modes:{}}, history:[...], sync_status:string}. 미션 category daily/weekly/achievements. history는 최신 50건이며 source/mode/outcome/character_id/ended_at/match_id가 있다.
- POST /v1/progress/offline → {events:[{event_id:UUID,mode:ai|solo|team,outcome:win|loss|draw,character_id,ended_at}]} → {accepted:[event_id],...}. 최대 50개. 절대로 LAN 순위에 반영하지 않는다.
- GET /v1/social?search=<exact nickname> → {friends:[{player_id,nickname,online,last_seen}], incoming:[{request_id,player_id,nickname}], outgoing:[...], recent:[{player_id,nickname,...}], invites:[{invite_id,player_id,nickname,invite_code,expires_at}], search:[{player_id,nickname}]}.
- POST /v1/social/action → {operation_id:UUID,action:request|accept|reject|cancel|remove|invite|accept_invite|reject_invite,player_id?:UUID,request_id?:UUID,invite_id?:UUID,invite_code?:string}. invite_code는 실제 대기중인 방에만 허용. accept_invite 응답에는 invite_code. 친구쌍 중복/본인/오래된 요청은 거부. 반대 방향 요청을 자동 수락하지 않는다.
- POST /v1/presence → {state:online|offline}; 30초 갱신, 90초 만료.
- GET /v1/leaderboard?scope=all|month|friends&page=0 → {entries:[{rank,player_id,nickname,wins,losses,draws,played,win_rate}],own:entry|null,page,has_more}. page50. 승수 내림차순, 승률 내림차순, 동점 공동순위, 표시 ID 정렬. 현재 KST 월 또는 전체 또는 현재 상호 친구+self. 0경기는 순위 없음.

서버 담당은 응답 세부 구조를 이 문서에 추가하고 앱 담당에게 알린다. 앱은 없는 서비스를 가짜 빈 성공으로 보여주지 않는다.

## LAN 내부 API와 내구 저장

서비스 토큰 인증은 기존 x-forest-arena-service-token이다.
- POST /internal/v1/lan/rooms → {room_code,host_player_id,invite_code,state:waiting|closed,updated_at:UTC}. 대기방의 실제 소유자를 서버가 등록한다.
- POST /internal/v1/lan/matches/<UUID>/register → {participants:[{player_id,slot:1|2,character_id,accessory_id}],room_code}. 실제 두 참가자, 네 캐릭터와 여섯 장신구 검사. match source lan, 기존 duel_dev 제외.
- POST /internal/v1/lan/matches/<UUID>/result → {reason:combat|draw|disconnect|abandoned,winner_player_id:string|null,final_tick:int,snapshot_hash:sha256}. 결과·미션 기록을 한 DB 트랜잭션에서 처리. combat/draw 두 canonical 사용자가 다를 때만 정상 집계. 시각은 DB 종료 시각. 중복은 원본과 같을 때만 인정.
- LAN 서버는 각 재대전 새 UUID, 순차 등록→결과 전송을 기기 저장 outbox v1에 남긴다. API 중단에도 전투는 계속하며 대기 결과 상태를 클라이언트 match_end의 선택 필드 match_id/result_sync로 알린다. 재시작 후 같은 요청을 재전송한다. API 인증 실패/오류는 제한된 재시도와 진단, 비밀 출력 금지.

## 앱 연결 지점과 파일 담당

루트 담당: scripts/local_ai_app.gd, server/game/lan_game_server.gd 및 새 lan_result_outbox.gd, 문서 통합·빌드·병합.
앱 담당: scripts/premium_menu/*, 새 scripts/network/menu_service_client.gd 및 identity/progress 저장 구현·테스트. 서버 담당: server/api/*, database/migrations/*와 새 서버 검사. QA 담당: 독립 검사와 별도 테스트·03_qa 기록. 다른 담당 파일을 고칠 때 먼저 조율한다.

앱은 app.menu_service:MenuServiceClient를 Node로 소유한다. 앱 담당이 configure(app), record_offline(config,controller), refresh_menu(menu_id), foreground(value), snapshot(menu_id), perform(action,payload) API를 제공한다. 초기 configure는 로컬 저장만 읽고 네트워크를 강제하지 않는다. root는 결과 hook에서 record_offline를 한 번 부르고 앱 focus 및 메뉴 진입을 연결한다. 서비스는 내부에서 기존 db_client/demo_guest를 사용하며 통합 완료 시 app callback apply_unified_identity(response)를 호출한다. 통합 실패는 기존 프로필을 보존한다. 통합 UI/라우터는 서비스 API를 통해 처리한다. 자세한 callback 요구는 앱 담당이 root에게 알린다.

## 필수 의미

미션: 일일 1완료/1승, 주간5완료/3승, 누적 첫완료/10완료/각4캐릭터 완료. KST 월요일 주간 경계. 보상 없음.
기기 오프라인 기록은 즉시 반영하고 outbox로 보낸다. LAN은 내부 서비스 결과만 집계한다. 전투 승패를 다시 계산하지 않는다. 설정·선택은 기존 저장 성공 경로를 쓴다.
통합 의도와 request_id를 네트워크 전 먼저 백업 저장한다. 서버 성공 후 로컬 저장 실패/응답 손실에도 같은 의도를 재시도한다. 서버가 다른 service_id면 자동 통합하지 않는다. 통합 전 계정과 네트워크 응답이 뒤늦게 도착해도 새 계정에 적용하지 않는다.

## QA 보완된 경계 규칙

- 사회 행동의 operation_id는 같은 실행자의 같은 내용 재전송을 기억한다. request_id는 친구 요청 대상 ID로 별도다.
- 공동 순위는 1,1,3 순서다. 닉네임은 기존 정규식과 lower(C) 비교를 유지한다.
- 오프라인 ended_at은 2000-01-01 이후의 유효 UTC 시각부터 현재+5분까지 허용한다. 과거 전송 지연에 임의 만료를 두지 않는다. 이 출처는 기기 제공 자료이며 순위에는 쓰지 않는다.
- 합병 뒤 두 참가자가 같은 canonical이 된 경기 원본은 보존하지만 모든 기록 집계·진행에서 제외한다. 사회 연결은 중복을 합치고 자신을 가리키는 친구·요청·초대를 표시하지 않는다.
- 현재 기기 저장이 첫 지급 전이라 선택이 없지만 서버에 보유가 있으면 유효한 서버 선택을 유지한다. 현재 유효한 선택·설정이 있으면 그것을 우선한다.
- 방 heartbeat는 30초, TTL90초다. payload updated_at을 기록하므로 늦게 재전송된 waiting이 새 방처럼 살아나지 않는다.

내부 LAN auth는 선택 입력 existing_player_ids(최대2)를 canonical_players 대응표로 돌려준다. 실제 전송 필드·마지막 보완은 [서버 전달 기록](02_network.md)을 함께 따른다.
