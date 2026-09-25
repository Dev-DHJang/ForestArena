# Forest Arena 문서·파일 색인

이 문서는 프로젝트에서 문서와 주요 파일을 찾는 시작점이다. 게임 개발 용어가 낯설면 [용어 가이드](GLOSSARY.md)를 함께 연다.

## 처음 읽는 순서

1. [README](../README.md): 게임 한 줄 설명, 실행 방법과 현재 구현 상태
2. [제품 방향](product/vision.md): 어떤 게임을 만들고 무엇을 만들지 않는지
3. [개발 순서](product/roadmap.md): 완료한 단계와 다음 개발 단계
4. [전투 규칙](gameplay/combat.md): 한 판의 조작과 승패 규칙
5. [현재 작업 상태](operations/harness/operating-index.md): 지금 쓸 검사 명령과 아직 확인하지 못한 항목

필요한 내용만 찾으려면 아래 표에서 질문과 가장 가까운 행을 고른다.

## 목적별 문서

| 찾고 싶은 내용 | 먼저 볼 문서 | 함께 볼 문서 |
| --- | --- | --- |
| 이 게임은 무엇인가? | [제품 방향](product/vision.md) | [세계관과 중심 이야기](product/world-and-story.md) |
| 지금 어디까지 만들었는가? | [개발 순서](product/roadmap.md) | [현재 작업 상태](operations/harness/operating-index.md) |
| 로컬 AI 버전은 어떻게 플레이하는가? | [로컬 AI 플레이](gameplay/local-ai-play.md) | [전투 규칙](gameplay/combat.md) |
| 중요한 결정이 승인됐는가? | [결정 기록](product/decisions.md) | [용어 가이드의 결정 상태](GLOSSARY.md#프로젝트-진행-용어) |
| 이동·공격·승패는 어떻게 동작하는가? | [전투 규칙](gameplay/combat.md) | [캐릭터별 전투 가이드](gameplay/character-combat-guide.md), [공격 데이터 형식](contracts/attack-system-v01.json) |
| 자현·묘령·나비는 어떻게 싸우는가? | [캐릭터별 전투 가이드](gameplay/character-combat-guide.md) | [전투 규칙](gameplay/combat.md) |
| 화면과 터치 조작은 어떻게 구성하는가? | [기능과 사용자 경험](gameplay/features-and-ux.md) | [비전투 화면 데이터](ui/non-combat-ui-v01.json), [Penpot 설계 기준](ui/penpot-setup.md) |
| 코드를 어떤 책임으로 나누는가? | [코드 구조](engineering/architecture.md) | [공용 데이터 형식](#공용-데이터-형식) |
| 개발계 DB를 어떻게 실행하는가? | [개발계 데이터베이스](engineering/database.md) | [코드 구조](engineering/architecture.md) |
| 이미지·애니메이션·소리는 어떻게 만드는가? | [콘텐츠 제작 원칙](content/art-and-audio.md) | [캐릭터 외형 데이터](contracts/character-appearance-v01.json) |
| Godot 자산은 어떻게 찾고 교체하는가? | [Godot 설정](engineering/godot/setup.md) | [Godot 자산 규칙](engineering/godot/resource-rules.md) |
| Android 기기를 어떻게 연결하는가? | [Android 무선 연결](engineering/godot/android-wireless-debugging.md) | [README 실행 명령](../README.md#실행과-검증) |
| AI 작업은 어떤 절차로 진행하는가? | [AI 개발 절차](operations/ai-development.md) | [AI 역할과 작업 배정](operations/harness/team-spec.md) |

## 폴더별 역할

```text
docs/
├── INDEX.md                 문서와 주요 파일을 찾는 시작점
├── GLOSSARY.md              게임·Godot·작업 용어 설명
├── product/                 제품 방향, 개발 순서, 세계관, 승인 결정
├── gameplay/                조작, 전투 규칙과 사용자 경험
├── contracts/               프로그램이 읽거나 검사하는 공용 JSON
├── engineering/             코드 구조와 Godot·Android 설정
├── content/                 캐릭터·이미지·애니메이션·오디오 원칙
├── ui/                      비전투 화면 데이터와 Penpot 기준
└── operations/              AI 작업 절차, 역할과 현재 운영 상태
```

`docs/` 최상위에는 시작 문서 두 개만 둔다. 새 문서는 가장 가까운 목적 폴더에 넣고 이 색인에 연결한다.

## 공용 데이터 형식

아래 JSON은 설명 문서가 아니라 코드와 검사가 함께 쓰는 데이터 약속이다. 필드나 ID를 바꿀 때는 사용하는 코드와 테스트를 함께 바꿔야 한다.

| 파일 | 역할 | 주요 검사 |
| --- | --- | --- |
| [공격 데이터 형식](contracts/attack-system-v01.json) | 기술 입력, 공격 단계와 캐릭터별 공격 설계 | `tests/combat_concept_contract.gd` |
| [캐릭터 외형 데이터](contracts/character-appearance-v01.json) | 승인 캐릭터의 필수·허용·금지 외형 | `tests/character_appearance_contract.gd` |
| [비전투 화면 데이터](ui/non-combat-ui-v01.json) | 24개 화면과 이미지 자리 | `tests/ui_design_contract.gd` |

## 문서 밖 주요 폴더

| 경로 | 들어 있는 것 |
| --- | --- |
| `forest_arena/` | Godot에서 실행되는 게임 코드, 장면과 자산 연결 데이터 |
| `assets/` | 캐릭터, UI, 이미지·소리 원본과 출처 기록 |
| `tests/` | Godot 자동 검사 |
| `scripts/` | 전체 검사, Android 생성·설치와 개발 보조 명령 |
| `tools/` | 자산 목록처럼 특정 데이터를 검사하는 도구 |
| `.agents/skills/` | AI 전문 역할별 작업 지침 |
| `_workspace/` | 작업별 요청, 변경 근거, 품질 확인과 마무리 기록 |
| `harness/` | AI 도구가 사용하는 기계 판독 설정 |

## 실행 코드 빠른 찾기

| 바꾸거나 확인할 기능 | 주요 위치 |
| --- | --- |
| 게임 시작 장면과 전체 흐름 | `scenes/local_ai_app.tscn`, `scripts/local_ai_app.gd` |
| 한 판의 전투 장면 | `scenes/main.tscn`, `scripts/main.gd` |
| 캐릭터 이동·점프·대시 | `scripts/fighter_controller.gd` |
| 터치 입력과 공통 전투 명령 | `scripts/touch_command_source.gd`, `scripts/combat_intent.gd` |
| 남은 기회, 링아웃과 승패 | `scripts/match_controller.gd` |
| 카메라와 경기장 표시 | `scripts/combat_camera.gd`, `scripts/arena_visual.gd` |
| 캐릭터·직업·장신구 데이터 클래스 | `scripts/data/` |
| 실제 캐릭터 데이터와 승인 이미지 | `assets/character/<character-id>/` |
| 공격과 기술 목록 데이터 | `assets/combat/` |
| 한 판 시작 조합 예시 | `assets/loadouts/` |
| 논리 자산 이름을 실제 파일로 연결 | `forest_arena/scripts/forest_arena_resource_manager.gd`, `forest_arena/data/resource_registry.json` |
| 자동 검사 | `tests/`와 `./scripts/verify.sh` |

## 저장소 최상위 파일

| 파일 | 역할 |
| --- | --- |
| `README.md` | 프로젝트 시작 안내와 현재 상태 |
| `AGENTS.md` | AI가 모든 작업에서 따라야 하는 공통 규칙 |
| `project.godot` | Godot 프로젝트 설정과 시작 장면 |
| `export_presets.cfg` | Android APK 생성 설정 |
| `forest_arena_install_report.json` | Godot 자산 패키지를 처음 설치했을 때의 기록. 현재 문서 경로 목록으로 사용하지 않는다. |

## 문서 우선순위

서로 다른 내용이 충돌하면 다음 순서로 확인한다.

1. [README](../README.md)의 현재 프로젝트 기준
2. 이 색인에 연결된 제품·게임플레이·엔지니어링·콘텐츠 문서
3. [결정 기록](product/decisions.md) 중 사용자가 승인한 `accepted` 항목
4. [AI 역할과 작업 배정](operations/harness/team-spec.md)
5. `_workspace/<topic>/`의 개별 작업 기록

같은 규칙을 여러 문서에 복사하지 않는다. 최종 기준 파일 한 곳에 적고 다른 문서에서는 링크한다.

## 쉬운 문장 규칙

- 독자가 해야 할 일과 결과를 먼저 쓴다.
- 가능한 경우 쉬운 한국어를 쓴다. 예: `수용 기준` 대신 `완료 조건`, `영속 데이터` 대신 `앱을 종료해도 남는 저장 데이터`.
- 코드나 도구에서 검색해야 하는 이름은 그대로 쓴다. 첫 등장에는 `쉬운 설명(전문 용어)` 형식으로 설명한다.
- 같은 전문 용어가 두 문서 이상에서 반복되면 [용어 가이드](GLOSSARY.md)에 추가한다.
- `권위`, `소비`, `주입`, `경계`처럼 일반적인 뜻과 다르게 쓰는 말은 설명 없이 단독으로 쓰지 않는다.

## 이동된 이전 경로

| 이전 경로 | 현재 경로 |
| --- | --- |
| `docs/01_product_vision.md` | `docs/product/vision.md` |
| `docs/02_game_design.md` | `docs/gameplay/combat.md` |
| `docs/03_features_and_ux.md` | `docs/gameplay/features-and-ux.md` |
| `docs/04_technical_architecture.md` | `docs/engineering/architecture.md` |
| `docs/05_content_art_audio.md` | `docs/content/art-and-audio.md` |
| `docs/06_roadmap_and_acceptance.md` | `docs/product/roadmap.md` |
| `docs/07_ai_development_guide.md` | `docs/operations/ai-development.md` |
| `docs/08_world_and_narrative.md` | `docs/product/world-and-story.md` |
| `docs/DECISIONS.md` | `docs/product/decisions.md` |
| `docs/attack-system-v01.json` | `docs/contracts/attack-system-v01.json` |
| `docs/character-appearance-v01.json` | `docs/contracts/character-appearance-v01.json` |
| `docs/forest_arena/` | `docs/engineering/godot/` |
| `docs/harness/forest-arena/` | `docs/operations/harness/` |

이 표는 예전 링크를 새 위치로 바꾸기 위한 안내다. 새 문서에서는 현재 경로만 사용한다.
