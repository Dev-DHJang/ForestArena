# 로컬 온라인 세로 흐름 계약 v1

## HTTP

- `GET /health/live`, `GET /health/ready`: 프로세스와 DB 준비 상태를 구분한다.
- `POST /v1/auth/guest`: 게스트 플레이어와 15분 access token, 30일 회전형 refresh token을 만든다.
- `POST /v1/auth/refresh`: refresh token을 한 번만 사용하고 새 토큰 쌍으로 교체한다.
- `POST /v1/matchmaking/join`: Bearer access token을 확인하고 고정 `duel_dev` 대기열에 참가시킨다.
- `GET /v1/matchmaking/:queue_entry_id`: 본인의 `waiting|matched` 상태만 읽는다.
- `DELETE /v1/matchmaking/:queue_entry_id`: waiting 상태만 취소한다.
- `POST /internal/v1/matches/:match_id/result`: 게임 서버 전용 토큰으로 결과를 한 번만 기록한다.

HTTP JSON 본문은 16KiB를 넘길 수 없다. 토큰 원문은 DB와 로그에 남기지 않는다.

## WebSocket protocol v1

- 클라이언트: `join`, `resume`, `input`, `ping`.
- 서버: `joined`, `match_start`, `snapshot`, `match_end`, `error`, `pong`.
- `input`은 증가하는 `seq`, `action_id`, `direction`, `edge`만 가진다. 서버가 fighter ID, ground/air context와 적용 tick을 정한다.
- action은 `move`, `jump`, `dash`, `evade`, `ultimate`, `attack_light`, `attack_heavy`, `attack_special`만 허용한다.
- 클라이언트가 위치, HP, stock, 피해, 승패 또는 서버 tick을 보내면 거부한다.
- 중복·역순 seq는 버리고 연결별 마지막 seq만 유지한다.
- match ticket은 60초짜리 일회용 서명 토큰이다. 첫 join 뒤 받은 reconnect token은 성공할 때마다 교체한다.

## 경기와 저장

- Godot 4.7.1 headless 서버가 현재 `MatchController`를 60Hz로 실행하고 3 tick마다 JSON snapshot을 보낸다.
- slot 1은 자현, slot 2는 묘령이다. 한 로컬 서버는 동시에 한 경기만 실행한다.
- 연결 해제 시 해당 fighter의 유지 입력을 즉시 해제하고 경기는 계속된다. 60초 안에 resume하면 같은 slot을 되찾고, 넘기면 상대의 이탈 승리다.
- 저장 표는 guest player, refresh token hash, match와 participant/result만 포함한다. 게임 서버는 DB에 직접 연결하지 않고 API에 idempotent result를 제출한다.
- protocol version이 다르거나 ticket·ID·slot이 맞지 않으면 명시적 오류 뒤 연결을 닫는다.

## 소비자

- TypeScript API는 인증, 매칭, ticket과 저장을 소유한다.
- Godot headless 서버는 ticket 검증, 입력 순서, 전투 판정, 재접속과 결과를 소유한다.
- Godot 개발 클라이언트는 access token과 match ticket을 소비하며 서버 snapshot을 표시만 한다.
