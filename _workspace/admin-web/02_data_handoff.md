# 데이터 API 전달 기록

- `AdminDataController`, `AdminDataService`, `ProfileValidator`, `DataApiException`을 추가했다.
- 프로필 검증은 현재 게임 API의 v3 규칙, v2를 읽을 때 v3으로 변환하는 규칙, 기존 카탈로그를 따른다. 조회만으로 DB를 변경하지 않는다.
- 수정은 프로필 행 잠금 뒤 중복 요청과 변경 번호를 검사하고, 프로필·번호·암호화 사유가 있는 전후 이력·중복 요청 응답을 한 트랜잭션으로 저장한다. 첫 지급 여부는 바꿀 수 없다.
- 페이지 크기는 기본 25·최대 100이며 검색은 SQL 매개변수로 전달한다. 경기 조회에는 참가자가 포함된다. 대시보드는 `/health/ready`에서 게임 API 상태를 확인한다.

## 확인

- Java 21로 `ProfileValidatorTest` 2개와 `AdminDataPostgresTest` 3개를 실제 PostgreSQL의 별도 `forest_arena_admin_test_dev` DB에서 통과했다.
- 확인 항목: 변경 번호 충돌, 동일 본문의 중복 요청 재응답, 다른 본문의 같은 요청 ID 거부, 선택·보유 검증, 첫 지급 상태 보호, 이력 저장 오류 때 전체 취소, 게임과 관리자 동시 수정, 페이지 한도, SQL 검색 입력.
- 게임 TypeScript `npm test` 9개를 통과했다. Java와 TypeScript는 `server/api/tests/fixtures/profile-validation-fixtures.json`의 승인·거부 20개 예제를 공유한다.
- 통합 검사에서는 매번 고유 UUID로 만든 행만 정리했다. 실제 개발 DB 기존 게스트와 프로필은 변경하지 않았다. 별도 브라우저 검사 DB에 만든 프로필은 외부 `e2e-player.env`에 ID를 기록했다.
- Android 기기 검사는 수행하지 않았다.
