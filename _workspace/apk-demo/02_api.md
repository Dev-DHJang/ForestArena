# 데모 API 구현・확인

## 구현
- `GET/PATCH /v1/guest/profile`: 기존 Bearer access 인증 재사용, 닉네임 NFC 변환과 2~12자 한글 완성형・영문・숫자・밑줄 검사. 공백을 잘라내지 않는다.
- `0006_demo_guest_nickname.sql`: nullable nickname 추가. 기존 display_name과 프로필・보유 기록 유지. lower(nickname) 고유 인덱스로 동시 요청 및 대소문자 중복을 409 nickname_taken으로 거부한다.
- `POST /internal/v1/lan/auth`: 서비스 토큰・access 토큰・DB 사용자 존재 검사. DB의 현재 이름만 반환하며 미설정 이름은 409 nickname_required.
- `FOREST_ARENA_DEMO_MODE=true`: FOREST_ARENA_ALLOWED_CIDR 필수, 사설 IPv4 또는 loopback CIDR만 허용. 지정 host가 허용 주소여야 하며 0.0.0.0 거부. 모든 요청의 socket 주소 검사, IPv4-mapped 및 loopback 지원. proxy 헤더 미사용. 기존 개발 모드는 유지.

## 실행 결과
- `npm --prefix server/api test`: 11개 통과(기존 9개 + 닉네임・CIDR 2개).
- 임시 PostgreSQL 18.6 컨테이너, 모든 0001~0006 migration 적용 후 실제 HTTP 검사: 통과. 동시 등록 중 1개 성공・1개 충돌, NFC 동등 이름 충돌, 유효성・미설정・위조・만료 access・서비스 인증・현재 DB 표시값 검증.
- 기존 `profile_runtime.ts` 실제 DB・HTTP 검사 통과: 기존 프로필・보유・동시 변경・refresh 재시도 보존.
- 실제 API 프로세스 종료・재시작 뒤 refresh로 같은 ID와 닉네임 복원 확인: 통과.
- 임시 DB 및 API 프로세스 정리 완료. 기존 개발 DB는 변경하지 않음.

## 재검사
- `npm --prefix server/api test`
- 마이그레이션된 격리 DB와 API가 실행 중인 환경에서 `DATABASE_URL`, `FOREST_ARENA_API_URL`, token/service secret을 설정하고 `node server/api/dist/tests/demo_guest_runtime.js` 실행. 검사에서 만든 게스트는 종료 시 삭제한다.

## 남은 확인
- 실제 LAN 인터페이스에서 허용 밖 socket 차단과 두 Android 기기 흐름은 통합・실기기 담당 확인 필요. 단위 검사는 실제 기기 통과를 뜻하지 않는다.
