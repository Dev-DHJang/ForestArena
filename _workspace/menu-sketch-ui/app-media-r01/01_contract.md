# 앱 미디어 연결 계약

- 앱 소비자는 ForestArenaResources 논리 ID `fa.ui.menu09.artifact.<short-id>`, `fa.ui.menu09.poster.<owner>.<clip>`, `fa.ui.menu09.video.<owner>.<clip>`을 사용한다. owner는 기존 4캐릭터 ID 또는 `accessory`, clip은 기존 VIDEO 슬롯의 마지막 조각이다. 실버는 기존 `fa.rank.rank.silver`, 요요 이미지는 기존 catalog ID를 재사용한다.
- 신규 원화6종과 포스터22종은 배치 원본을 복사하며 영상은 기존 검토 영상에서 Godot 내장 Ogg Theora 호환 사본을 생성한다. 출력은 `forest_arena/assets/ui/menu09-media/`, 파일 목록·해시는 작업 기록에 둔다. 런타임/캐릭터 원본에 손대지 않는다.
- UI는 기존 실제 보유·구매·선택과 라우터를 사용한다. 비활성 캐릭터·신기는 소개로만 연결한다. 기존 내부 ID, 보유 저장, 경기 로스터, 경제·매칭 규칙을 유지한다. 실버는 랭킹 로비 예시 레이블을 구분한다.
- 자산 생산자는 출력 디렉터리, 리소스 등록, 제작 도구와 `02_media.md`만 담당한다. 주 에이전트가 실제 앱 UI·테스트·실기기·최종 통합을 담당한다. 독립 QA는 코드/계약/표시 검토를 기록한다.

사용자 추가 선택은 “승인된 MENU09 21종 전체 반영”이다. 메인 로비·대전 5종, 캐릭터·신기 4종, 상점 5종, 미션·생활 7종으로 나눠 기존 기능과 연결한다. 명세는 `screen-register.json`의 승인본을 기준으로 한다.

- 대전 생산자 소유: `scripts/local_ai_app.gd`, 새 `scripts/*menu09*match*.gd`, `tests/*menu09*match*.gd`, `02_match.md`. 랭킹 로비는 별도 view helper/앱 화면으로 만들고 기존 LAN 순위를 구분해 연다. 8인 예시와 실제 LAN 1:1을 구분한다.
- 생활 생산자 소유: `scripts/premium_menu/menu09_life.gd`, 생활 검증 파일, `02_life.md`. 공통 view/router 변경 필요시 주 에이전트에 연결 지점을 전달한다. 기존 미션·친구·설정 로직과 서비스/API는 유지한다.
- 주 에이전트 소유: 공통 `premium_menu_view.gd`, `premium_menu_router.gd`, 리소스 로더, 캐릭터·신기·상점, 공통 검사·기기·통합. 동일 파일을 병렬로 덮어쓰지 않는다.
