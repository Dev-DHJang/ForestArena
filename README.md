# Forest Arena

Forest Arena는 발판이 있는 경기장에서 3등신 동물 캐릭터가 상대를 밖으로 밀어내는 Android용 2D 격투게임이다. Godot 4로 개발하며, 현재는 캐릭터·직업·장신구를 한 판의 전투 데이터로 합치는 개발 단계(Phase 2)까지 완료했다.

게임 개발 용어가 낯설다면 [용어 가이드](docs/GLOSSARY.md)를 먼저 읽는다. 본문은 쉬운 표현을 우선하고, 코드에서 검색해야 하는 고유 이름은 `AttackData`처럼 그대로 쓴다.

문서나 주요 파일을 찾을 때는 [문서·파일 색인](docs/INDEX.md)에서 목적별 목록과 권장 읽기 순서를 확인한다.

## 문서 우선순위

충돌이 있을 때 아래 순서로 판단한다.

1. 이 README의 현재 프로젝트 기준
2. [문서·파일 색인](docs/INDEX.md)에 연결된 제품·게임플레이·엔지니어링·콘텐츠 문서
3. 사용자가 승인한 [결정 기록](docs/product/decisions.md)의 `accepted` 결정
4. [AI 역할과 작업 배정](docs/operations/harness/team-spec.md)
5. 작업별 `_workspace/<topic>/` 작업 기록

아직 정하지 않은 항목은 `proposed`(제안) 상태의 결정 기록으로 남긴다. 같은 규칙을 여러 문서에 복사하지 않고 최종 기준이 되는 한 문서로 연결한다. 상태와 ADR의 뜻은 [용어 가이드](docs/GLOSSARY.md#프로젝트-진행-용어)에서 확인할 수 있다.

## 문서 지도

- [전체 문서·파일 색인](docs/INDEX.md)
- [제품 비전](docs/product/vision.md)
- [게임 디자인](docs/gameplay/combat.md)
- [기능과 UX](docs/gameplay/features-and-ux.md)
- [기술 아키텍처](docs/engineering/architecture.md)
- [콘텐츠·아트·오디오](docs/content/art-and-audio.md)
- [캐릭터 외형 계약 v01](docs/contracts/character-appearance-v01.json)
- [개발 순서와 완료 조건](docs/product/roadmap.md)
- [AI 개발 가이드](docs/operations/ai-development.md)
- [세계관과 중심 서사](docs/product/world-and-story.md)
- [용어 가이드](docs/GLOSSARY.md)
- [결정 기록](docs/product/decisions.md)
- [비전투 UI·Penpot 설계 기준](docs/ui/penpot-setup.md)
- [하네스 운영 색인](docs/operations/harness/operating-index.md)

## 실행과 검증

    godot --path . --editor
    ./scripts/verify.sh
    ./scripts/export-debug-android.sh
    ./scripts/verify-android-emulator.sh
    ./scripts/android-wireless-debug.sh devices

실제 Android 기기를 무선으로 연결하는 방법은 [Android 무선 디버깅](docs/engineering/godot/android-wireless-debugging.md)을 참고한다.

`./scripts/verify.sh`는 화면 없이 Godot 프로젝트 열기, 앱 기본 실행, 전투, 캐릭터·직업·장신구 조합, 데이터 형식과 문서 구조를 한 번에 확인하는 기본 검사다. `./scripts/verify-docs.sh`는 문서 위치·링크·쉬운 문장 규칙을, `./scripts/verify-harness.sh`는 AI 역할·작업 배정 규칙을 빠르게 확인한다.

## 현재 상태

- 완료: 같은 입력이면 같은 결과가 나오는 기본 전투 한 판(Phase 1), 이미지·소리를 안정적인 이름으로 찾는 목록, 캐릭터·직업·장신구를 조합하는 데이터 처리(Phase 2).
- 현재: AI 작업은 14개 전문 역할로 나눈다. 정식 선택 화면, 성장, 게임 재화와 Phase 3 이후 전투 기능은 아직 없다.
- 준비된 캐릭터 자료: 자현·묘령·나비의 기본 데이터와 콘셉트, 그리고 유란의 플레이용 기본·공격 데이터와 사용자 등록 콘셉트가 있다. 유란의 런타임 모션은 배치별 사용자 검토 중이다. 자료가 등록됐다는 뜻이며, 모든 애니메이션이 실제 전투 화면에 연결됐다는 뜻은 아니다.
- 공격 체계: 세 캐릭터의 공격 정보는 `AttackData`(공격 시간·피해·밀어내기)와 `MoveSetData`(기술과 입력 조건)에 저장되어 있다. 실제 기본 공격과 맞음 계산, 터치 입력이 동작한다.
- 화면 설계 준비: 24개 화면과 61개 이미지 자리의 이름·용도를 정했다. 실제 Godot 화면, 최종 이미지와 Penpot 설계 파일은 아직 만들지 않았다.
- 로컬 검증 완료: Android debug APK export, arm64 에뮬레이터 설치·가로 실행·중단/복귀와 20:9 시각 검사.
- 미확인: 실제 물리 Android 기기의 터치·중단/복귀·성능.
- 미구현: 정식 선택 UI(SCR_06–SCR_08), 저장·성장·경제, 복수 장신구·태그 시너지, 오디오와 온라인 기능.
