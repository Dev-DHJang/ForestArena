# 장신구 계약

- AccessoryData v2와 기존 fixture ID는 유지한다. 기존 보유·선택 기록은 새 옵션을 사용한다. 표시 이름과 파일명·저장 ID가 다를 수 있다.
- 장신구 combat_effects에는 REFLECT_DAMAGE·EXPLOSION_DAMAGE·REVIVE를 허용하지 않는다. 반사도 별도 HP 피해이므로 제거한다. 금지 효과는 장신구 정의 검사에서 거부한다. 직업·기본 전투의 일반 효과 기능과 stock 상실 후 정상 복귀는 삭제하지 않는다.
- 현재 장신구에는 무조건 슈퍼아머·무적·추가 stock·HP 증가를 주지 않는다. 옵션은 이동·무게·체공의 작은 장단점 또는 기술 목록 교체로 만든다. 수치 조정은 기본값이며 실제 공정성 증명은 아니다.
- 4캐릭터×6장신구 조합·피해 사건·마지막 stock·재대전·원본 비변경을 검사한다. ID 목록이 같으므로 API 보유 카탈로그·DB 저장 형식은 변경하지 않는다.
- 소비자: LocalPlayCatalog, LoadoutBuilder, FighterController/HitResolver, 로컬 앱·LAN 서버, API profile catalog와 tests.
- 롤백: 이번 커밋 revert. 저장 데이터 초기화·DB 삭제·무료 보유 회수는 하지 않는다.
