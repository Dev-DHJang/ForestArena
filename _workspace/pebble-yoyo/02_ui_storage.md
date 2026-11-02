# 상점·저장·AI 편성 연결

## 구현

- `LocalPlayCatalog`에 활성 장신구 ID pebble-yoyo와 대표 이미지 논리 ID fa.accessory.pebble.yoyo를 추가했다. 기존 4캐릭터·6장신구 보유 카탈로그와 비활성 정책은 보존했다.
- 상점에 활성 장신구 카테고리와 0원 획득을 연결했다. 장신구 목록·상세에서 대표 이미지·효과·쿨타임·보유 상태와 장착·해제를 제공한다.
- 로컬 프로필과 DB API는 동일한 활성 장신구 허용 목록·보유 검사를 사용하며, schema3 구조를 유지한다. 기존 선택 정규화는 소유한 요요를 보존하고 과거 비활성 장신구만 해제한다.
- 프리셋은 요요 저장·초안 선택·적용·해제를 지원한다. 보유하지 않은 활성 장신구 적용은 거부하고 과거 프리셋은 원본을 보존하며 활성 복사본만 적용한다.
- 로컬·LAN 대전 준비의 플레이어 장신구 선택 값이 실제 경기 편성에 전달된다. human selector QA label은 `장신구`다.
- AI별 선택은 `ai_accessories[index]`에 앱 세션 동안만 보관한다. 선택지는 미장착과 내가 소유한 활성 장신구이며, 시작 시 재검사한다. AI N 장신구 선택이 참가자 N의 기존 selection.accessory_id에 전달되고 재대전에도 유지된다. 기본 미장착, 연습 허수아비는 기존 무입력 정책을 유지한다.
- LAN 안내 코드 표기를 FAH5/FA5와 버전5로 갱신했다.

## 검사

- API Node 테스트 16개 통과. 로그: build/verification/pebble-yoyo-menu/api-tests.log.
- 이후 Java·TypeScript 공용 프로필 사례에 요요 보유/미보유/중복 소유를 추가했다. 최종 전체 검사에서 공용 사례와 Godot 런타임 검사를 수행한다.
- 관련 Godot 검사 보강: local_player_store, local_ai_app_flow, premium_menu_runtime, menu_state_store, db_profile_runtime, accessory_policy, forestlight_runtime. 실제 물리 Android 검사는 수행하지 않았다.
