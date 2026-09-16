# Forest Arena 하네스 팀 명세

AI 작업을 어떤 전문 역할에 맡기고 어떻게 확인할지 정한 운영 문서다. 하네스, 계약, 인수인계와 결과 상태는 [용어 가이드](../../GLOSSARY.md#프로젝트-진행-용어)에서 쉽게 설명한다.

## 운영 구조

AI 작업 체계(하네스)는 전문 역할과 별도 검토 역할을 사용한다. 한 영역은 해당 전문가가 처리한다. 둘 이상의 영역, 함께 쓰는 데이터 형식 또는 여러 개발 단계에 걸친 작업은 조율 역할(`orchestrator`)이 나눈다. 위험이 크거나 별도 확인이 필요한 변경은 품질 역할(`qa`)이 데이터를 만드는 쪽과 읽어 사용하는 쪽을 함께 검토한다.

이 표가 활성 역할 목록의 단일 원본이다. 현재 단계와 실행 명령은 [운영 색인](operating-index.md)에서 확인한다.

## 역할

| 역할 | 스킬 | 소유 범위 |
| --- | --- | --- |
| 오케스트레이터 | forest-arena-orchestrator | 영향 분석, 역할 조율, 통합, 원격 통합과 종료 증적 |
| 제품 | forest-arena-product | 제품 규칙, Phase, 범위, 수용 기준과 ADR |
| 전투 | forest-arena-combat | 이동, 상태, 공격, 판정, 넉백, 링아웃과 로드아웃 |
| UI | forest-arena-ui | 터치 UX, Camera2D, HUD, 메뉴, Penpot 및 Godot 비전투 UI |
| Godot 리소스 | forest-arena-godot-resources | 논리 ID, 품질 변형, `ForestArenaResources`와 리소스 검증 |
| 2D 애니메이션 | forest-arena-2d-animation | 프레임, 아틀라스, SpriteFrames, 시각 래퍼와 승인 캐릭터 모션 |
| 캐릭터 디자인 | forest-arena-character-design | 신규 전투 캐릭터 콘셉트, 사용자 승인과 승인 자산 등록 |
| 이미지 | forest-arena-image-design | 콘셉트, 초상화, 아이콘, UI 이미지와 배경 |
| 오디오 | forest-arena-audio | 의미 이벤트 기반 BGM·SFX와 모바일 오디오 |
| 모바일 | forest-arena-mobile | Android export, 생명주기, 터치, 성능과 기기 검증 |
| 계약 | forest-arena-contracts | Resource, 저장, 공용 ID와 미래 버전 계약 |
| 멀티플레이 | forest-arena-multiplayer | Phase 7 이후 온라인 매치 의미 |
| 네트워크 | forest-arena-network | Phase 7 이후 전송, 연결과 복구 |
| QA | forest-arena-qa | 독립 검증과 `pass`/`fix`/`redo`/`blocked` 판정 |

## 요청 라우팅

| 요청 | 필수 역할 | 조건부 역할 | 제한 |
| --- | --- | --- | --- |
| 제품 규칙·로드맵 | product | orchestrator, qa | 미정 규칙은 proposed ADR |
| 이동·공격·판정 | combat, qa | ui, mobile | 시각 프레임은 판정 비권위 |
| 터치·카메라·HUD·비전투 Godot UI | ui, qa | godot-resources, mobile, combat | `ForestArenaResources`의 논리 ID만 소비 |
| Godot 리소스 카탈로그·품질·Autoload | godot-resources, contracts, qa | ui | 공용 계약 변경이면 `01_contract.md` 선행 |
| Penpot 비전투 UI 설계 | product, contracts, ui, image-design, mobile, qa | orchestrator | 계약 확정 뒤 `ui`와 `image-design`만 병렬화 |
| Resource·ID·저장 | contracts, qa | combat, product | `01_contract.md` 선행 |
| 신규 전투 캐릭터 콘셉트 | character-design, qa | image-design, 2d-animation | 사용자 승인 전 `assets/character/` 등록 금지 |
| 승인 캐릭터 외형 경계·변경 | character-design, contracts, qa | image-design, 2d-animation | 외형 JSON이 단일 원본 |
| 캐릭터 idle·jump·run 모션 | 2d-animation, qa | character-design | 승인 콘셉트와 모션별 사용자 명시 승인 필수 |
| 콘셉트·정적 이미지 | image-design, qa | ui, 2d-animation | 원본성과 권리 기록 |
| BGM·SFX | audio, qa | combat, mobile | 의미 이벤트만 소비 |
| Android export·기기 | mobile, qa | ui, combat | 실제 기기 결과와 자동 검증을 구분 |
| 온라인·재접속 | contracts, multiplayer, network, mobile, qa | combat, ui | Phase 7과 accepted ADR 필수 |
| 원격 통합·롤백 | orchestrator, qa | product | 실제 Git 권한·보호 규칙 필요 |

## 작업 증적

모든 작업은 `_workspace/<topic>/`에 둔다. topic은 소문자 영문·숫자·하이픈을 쓴다.

- 항상 작성: `00_request.md`, `04_closeout.md`.
- 공용 계약 변경: `01_contract.md`.
- 실질적 역할 인수인계: `02_<role>.md`.
- 독립 QA가 필요한 기능 또는 고위험 변경: `03_qa_rNN.md`.
- 브랜치·PR·병합·롤백 정보는 별도 파일이 아니라 `04_closeout.md`에 기록한다.

`fix`는 구현 생산자에게, `redo`는 product 또는 contracts 소유자에게 돌린다. 같은 원인이 두 회차 반복되면 역할과 접근을 재분류한다. 필수 검증을 실행할 수 없으면 `blocked`이며, 사용자 승인으로 이연한 검증만 범위·이유·재개 조건을 남긴다.

## 소유권과 불변 경계

- combat는 전투 판정을 소유하며, ui·2d-animation·image-design·audio는 표현만 소유한다. 표현은 피해, 상태, 넉백, 승패를 결정하지 않는다.
- `docs/contracts/character-appearance-v01.json`은 승인 로스터 외형의 단일 원본이다. character-design, image-design, 2d-animation은 같은 ID와 필수·각도 한정·금지 규칙을 소비한다.
- 승인 캐릭터 외형 변경은 영향 자산과 계약 필드를 먼저 기록하고, 사용자 변경 승인과 QA `pass` 전에는 PNG·모션·manifest를 변경하지 않는다. 사용자 시안 승인만으로는 계약 변경 승인이 되지 않는다.
- 2d-animation은 승인 콘셉트의 idle·jump·run 런타임 패키지를 소유한다. 모션별 사용자 명시 승인 전에는 `assets/character/<character-id>/animation/runtime/` 또는 manifest에 쓰지 않는다.
- `ForestArenaResources`는 `res://forest_arena/` 카탈로그의 논리 ID 경계다. 기존 `assets/ui/generated/`, `assets/character/`의 승인·소유권·출력 경로를 대체하지 않는다.
- CharacterData·JobData·AccessoryData 조합은 contracts와 combat가 관리한다. 온라인, 영속 성장, 경제와 정식 선택 UI는 해당 Phase와 승인 전 구현하지 않는다.
- Penpot 1920×1080은 설계 참조이며 Godot 런타임 논리 해상도 1280×720은 별도 승인 없이 바꾸지 않는다. 비전투 화면은 `docs/ui/non-combat-ui-v01.json`, 이미지 요구는 `assets/ui/asset-requirements.csv`를 따른다.
- Phase 7 이전 온라인 구현 요청은 실행하지 않고 `blocked`와 재개 조건을 남긴다.

## 버전 관리

사용자가 구현·수정·완료를 요청하면, 그 범위에는 최신 `origin/develop` 기반 작업 브랜치 생성, 관련 변경만 commit, push, PR 생성, QA 뒤 `develop` 병합과 롤백 증적 기록이 포함된다. 이 저장소 절차에는 단계별 재허가를 요청하지 않는다.

다만 `main` 승격, `release/*`·`hotfix/*`, 강제 push, 이력 재작성, 원격 브랜치 삭제, 계정·권한·비밀정보 변경은 자동 범위에서 제외한다. 인증, 보호 규칙, 충돌 또는 실행 플랫폼이 강제하는 보안 확인은 우회하지 않으며 기술적 차단으로 기록한다.

## 완료 기준

- 생산자는 자동 검사 또는 이름 있는 수동 회귀를 수행한다.
- qa는 원 요청, 제품 문서, 계약, 생산자와 소비자 산출물을 함께 검토한다.
- 실제 기기·서비스가 없어 실행하지 못한 검증은 `pass`가 아니다.
- 하네스는 `./scripts/verify-harness.sh`, 전체 회귀는 `./scripts/verify.sh`, UI 계약은 `tests/ui_design_contract.gd`로 확인한다.
