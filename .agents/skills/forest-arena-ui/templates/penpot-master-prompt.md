# FOREST ARENA Penpot 비전투 UI 제작 프롬프트

현재 포커스된 Penpot 파일을 수정하기 전에 읽기 전용으로 검사하라. 팀/프로젝트가 `Forest_Arena`, 파일이 `Forest_Arena_UI`인지 확인하고 기존 페이지, 토큰, 컴포넌트와 화면 프레임을 보고하라. 대상이 다르면 중단하라. 재실행이면 기존 Forest Arena 구조를 재사용하고 중복 생성하지 말라.

## 권위 입력

- `docs/product/decisions.md`의 accepted ADR
- `docs/ui/non-combat-ui-v01.json`
- `assets/ui/asset-requirements.csv`
- 승인된 `assets/character/manifest.json`과 각 CharacterData

공유 프롬프트의 일반 캐릭터 설명보다 승인된 자현·묘령·나비와 3등신 시각 방향을 우선하라. 자현=mouse, 묘령=rabbit, 나비=cat-theme다. `character-approval-required`인 신규 로스터를 최종 캐릭터로 발명하지 말라.

## 제품·시각 규칙

- 표시 로고: `FOREST ARENA`
- 1920×1080 가로 기준. 8px 간격 리듬과 모바일 safe area를 사용한다.
- 밝은 독창적 비픽셀 판타지 숲. 하늘색, 민트, 신선한 초록, 코발트, 따뜻한 금색과 반투명 유리·조각 나무·밝은 석재를 사용한다.
- 제3자 캐릭터, 로고, 지도, 아이콘, UI나 특정 작가의 고유 스타일을 복제하지 않는다.
- 모드: Story / Solo / Team / AI / Practice.
- 최대 8명. Team은 팀당 1~4명이고 전체 최대 8명.
- 장신구에는 희귀도·등급이 없다. 별, 티어, 색상 희귀도 테두리, legendary/epic 라벨을 쓰지 않는다.
- `SCR_01_Splash`에는 캐릭터를 넣지 않는다.
- 실시간 전투 HUD는 만들지 않는다.

## 생산 구조

먼저 Foundations를 만든다. 의미 색상 토큰, Noto Sans KR 우선의 읽기 쉬운 서체 스타일, 8px spacing, 8/12/16/20/24/full radius와 panel/modal/hero effect를 정의한다.

다음 실제 재사용 컴포넌트를 만든다.

- `BTN/Primary|Secondary|Ghost|Danger/{L|M|S}/{Default|Pressed|Disabled}`
- `TAB/Filter/{Default|Selected}`
- `NAV/Meta/{Default|Active}`와 Top Bar
- `CARD/Character`, `CARD/Accessory`, `CARD/Mode`, Mission, Reward, Shop
- `PARTY/Slot/{Empty|Filled|Host|Ready}`와 Team A/B 각 4칸
- matchmaking timer, Match Found countdown, ready indicator
- stat row, player result row, MVP badge, like button, rank progress

## 화면

다음 ID를 정확히 가진 편집 가능한 1920×1080 프레임 24개를 만든다.

| 그룹 | 화면 |
| --- | --- |
| Launch | `SCR_01_Splash`, `SCR_02_Login` |
| Lobby/meta | `SCR_03_Lobby`, `SCR_04_CharacterCollection`, `SCR_05_CharacterDetail`, `SCR_06_AccessoryCollection`, `SCR_07_AccessoryDetail`, `SCR_08_Preset`, `SCR_19_Shop`, `SCR_20_Collection`, `SCR_21_Mission`, `SCR_22_Social`, `SCR_23_Rank`, `SCR_24_Profile` |
| Match flow | `SCR_09_ModeSelect`, `SCR_10_PartyLobby`, `SCR_11_Matchmaking`, `SCR_12_MatchFound`, `SCR_13_CharacterSelect`, `SCR_14_AccessorySelect`, `SCR_15_Loading` |
| Result | `SCR_16_Victory`, `SCR_17_ResultSummary`, `SCR_18_MVP` |

각 화면의 상세 요구와 runtime gate는 JSON 계약을 그대로 따른다. Lobby에서는 Play가 상점보다 강해야 한다. ModeSelect는 다섯 모드와 인원 규칙을 보인다. PartyLobby는 팀마다 4칸을 지원한다. Accessory 화면은 기능 범주와 궁합만 표현한다.

## 자산 매핑

CSV의 각 `asset_slot`을 `output_path`에 연결한 Assets Mapping을 만든다. 파일이 없으면 정확한 `IMG/...` 이름과 의도한 비율의 플레이스홀더를 만들고 보이는 `MISSING ASSETS` 목록에 기록한다. 누락 이미지를 최종 이미지처럼 조용히 발명하지 않는다.

## Dev Handoff와 완료 검사

safe area, 토큰/스타일 이름, 컴포넌트 이름, selected/default/disabled 규칙, 이미지 슬롯, SVG·투명 PNG/WebP·배경 WebP/PNG 권장을 기록한다. Godot 런타임 논리 해상도는 1280×720임을 명시한다.

완료 전 24개 ID, 프레임 크기, Splash 무캐릭터, 팀 슬롯, 다섯 모드, 무등급 장신구, 컴포넌트 인스턴스, 한국어 clipping/overlap, 주요 CTA, 누락 에셋 기록과 무관한 작업 보존을 감사하라. 마지막에 페이지/섹션 수, 컴포넌트 수, 화면 수, 누락 목록, 플레이스홀더 수, 미해결 결정과 MCP 한계를 보고하라.
