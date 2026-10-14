# 프리미엄 메뉴 v07 실제 앱 연결

[Penpot 설계](premium-menu-v07.md)를 Godot 네이티브 Control로 구현한다. 배경·원화·아이콘만 이미지이며 버튼, 목록, 탭, 설명, 슬라이더, 팝업은 실제 UI다. 밝은 로비는 유지하고 하위 메뉴에만 어두운 색상 변형을 적용한다.

## 메뉴와 데이터

로비의 캐릭터·장신구·프리셋·미션·친구·상점이 새 화면을 연다. 하위 화면의 전체 메뉴에서 도감·랭크·프로필과 설정도 연다. 실제 캐릭터·기술·장신구 데이터를 읽고 보유한 항목만 편성에 적용한다. 기존 가격 0원 무료 구매는 상세 확인 뒤 처리한다. 도감은 읽기 전용이며 미션·친구·랭크는 준비 중과 빈 상태로 표시한다.

프리셋 4개는 첫 슬롯에 현재 편성, 나머지에 빈 슬롯을 둔다. 편집은 초안이며 저장과 적용을 구분한다. 적용 직전 보유 여부를 확인하고 기존 선택 저장 경로를 쓴다. 닉네임은 프로필에서 변경한다. 일반 설정은 소리·화면 효과·접근성·미니맵으로 나누며 분류별 적용·취소·복원을 제공한다. 저장 전 분류를 떠나면 버리기 확인을 연다.

조작 설정은 고정/플로팅 조이스틱, 버튼 크기100–120%, 투명도0–50%를 제공한다. 기본값은 고정·100%·0%다. 전투 그림과 터치 영역을 함께 조정하고 입력을 해제한다. 플로팅은 왼쪽 예약 영역에서만 시작한다. 일시정지에서 연 조작 설정은 일시정지로 돌아간다.

## 코드와 기기 저장

- `scripts/premium_menu/premium_menu_router.gd`: 화면 이동과 초안·확인·저장 연결.
- `premium_menu_view.gd`, `premium_menu_theme.gd`: 공통 색상·상태·네이티브 화면.
- `local_menu_state_store.gd`: 버전1 `menu_presets_v01.json`, `menu_controls_v01.json`. 임시 파일·백업으로 저장 실패를 보호한다.
- `scripts/local_ai_app.gd`: 실제 프로필, 구매, 경기 진입, 뒤로 동작 연결.

기존 프로필 형식 v3, DB·LAN API, 전투 규칙은 유지한다. 프리셋은 기기 사용자와 DB 사용자별로 분리하며 DB 사용자 키는 접속 주소와 사용자 ID의 해시다. 조작 설정은 기기 공통이다. 검사 저장 경로는 앱의 `save_path`와 같은 폴더를 따라 Android QA 실행별 폴더를 사용한다.

## 자산과 검증

런타임 전용 자산27개(배경6·벡터16·승인 원화 사본4·폰트1)는 `forest_arena/assets/ui/premium-menu-v07/`와 논리 ID `fa.ui.menu.v07.*`, `fa.font.menu.v07.noto_sans_kr`에 등록한다. 승인 원본·전투 자산을 교체하지 않는다. Noto Sans KR 공식 배포본과 SIL OFL 라이선스, 출처·해시는 같은 폴더의 manifest와 fonts/OFL.txt에 보관한다.

[작업 요청](../../_workspace/premium-menu-v07-runtime/00_request.md), [공용 연결 약속](../../_workspace/premium-menu-v07-runtime/01_contract.md), [마무리와 실제 검사 결과](../../_workspace/premium-menu-v07-runtime/04_closeout.md)를 확인한다. 81개 설계 상태는 같은 폴더의 state-runtime-coverage.csv에서 실제 상태와 대응한다. 제공되지 않는 서버 예시를 실제 서비스 결과로 기록하지 않는다.

자동 검사는 `tests/menu_state_store.gd`, `tests/menu_touch_controls.gd`, `tests/premium_menu_runtime.gd`와 기존 앱·전투·LAN 검사다. 실제 화면 캡처는 `godot --path . --script res://tests/premium_menu_runtime.gd -- --ui-capture`로 생성한다. Android 실기기는 수행한 항목만 결과로 기록한다.
