# 문서 용어 쉽게 쓰기 마무리

## 결과

- 완료: 게임 개발 초보자를 위한 `docs/GLOSSARY.md`를 추가했다.
- 완료: README에서 게임 방식, 현재 Phase와 구현·미구현 상태를 쉬운 문장으로 다시 썼다.
- 완료: `docs/01`~`docs/07`의 핵심 용어를 쉬운 표현으로 바꾸고 필요한 코드·업계 용어에는 즉시 설명을 붙였다.
- 완료: Godot 리소스, 하네스 운영 색인·팀 명세와 Penpot 안내에서 첫 진입 설명을 보강했다.
- 보존: 코드 식별자, JSON 필드, 게임 규칙, Phase 범위와 ADR 상태는 바꾸지 않았다.
- 보존: 작업 시작 전에 존재한 세계관 문서와 관련 변경은 수정하거나 제거하지 않았다.

## 용어 정책

- 본문은 `실제 결과를 정한다`, `한 판용 데이터`, `완료 조건`, `기존 기능 재검사`처럼 행동과 결과가 보이는 표현을 먼저 쓴다.
- 코드에서 검색해야 하는 `AttackData`, `Resource`, `Area2D`, `ForestArenaResources` 같은 이름은 유지한다.
- 유지한 전문 용어는 프로젝트 진행, 전투, 화면·그래픽, Godot·데이터, 테스트의 다섯 문맥으로 나눠 설명한다.

## 검증 결과

- `./scripts/verify-harness.sh`: PASS, 14개 활성 역할과 345개 논리 자산 확인.
- `./scripts/verify.sh`: PASS, Phase 0 기본 실행, Phase 1 전투·입력·결정 재현, Phase 2 데이터 조합, 캐릭터·공격·UI·리소스 검사 통과.
- `git diff --check`: PASS.
- Markdown 상대 링크 검사: PASS, 17개 Markdown 파일에서 존재하지 않는 로컬 대상 없음.
- `초보 개발자 문서 읽기 검사`: PASS. README와 핵심 문서에서 현재 범위, 한 판 데이터 조합, 전투 결과 계산 책임, Phase 3·7 제한과 용어 가이드 위치를 확인할 수 있다.

## 실행하지 않은 검증

- 실제 Android 기기 검증은 실행하지 않았다. 문서 표현만 바뀌었으며 게임 코드, 자산과 Android 설정은 변경하지 않았다.

## 버전 관리 상태

- 작업 위치: 기존 `feature/combat-resource-ui-baseline` 브랜치.
- 커밋·push·PR·`develop` 병합: 실행하지 않음.
- 이유: 작업 시작 전부터 README·제품 비전·결정 기록과 새 세계관 파일에 커밋되지 않은 사용자 변경이 있었고, 현재 브랜치도 최신 `origin/develop` 기반의 새 작업 브랜치가 아니었다. 기존 변경과 겹치는 README를 임의로 분리·stash하거나 다른 기준으로 옮기면 사용자 작업을 누락할 위험이 있어 로컬 변경으로 보존했다.

## 되돌리기

- 이 작업만 되돌릴 때는 `docs/GLOSSARY.md`와 `_workspace/terminology-simplification/`을 제거하고, 이 기록의 결과 목록에 있는 문서에서 용어 변경만 되돌린다.
- README의 세계관 링크, `docs/01_product_vision.md`의 세계관 문장, `docs/DECISIONS.md`의 ADR-019와 `docs/08_world_and_narrative.md`는 이 작업 전 변경이므로 되돌리지 않는다.

## 다음 작업

- 이후 새 문서는 `docs/GLOSSARY.md`의 작성 원칙을 따른다.
- 새로운 전문 용어가 반복되면 본문에서 먼저 쉽게 설명한 뒤 같은 문맥의 용어 표에 추가한다.
