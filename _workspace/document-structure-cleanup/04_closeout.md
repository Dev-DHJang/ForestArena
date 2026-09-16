# 쉬운 문장 규칙과 문서 구조 정리 마무리

## 결과

- `docs/INDEX.md`를 문서와 주요 파일 탐색의 시작점으로 추가했다.
- 문서를 `product`, `gameplay`, `contracts`, `engineering`, `content`, `ui`, `operations`의 7개 목적별 폴더로 정리했다.
- `docs/` 최상위에는 `INDEX.md`와 `GLOSSARY.md`만 남겼다.
- README, AGENTS, 문서, AI 역할 지침, 캐릭터 콘셉트, 테스트와 검사 스크립트의 경로를 새 위치로 갱신했다.
- AGENTS와 AI 개발 절차에 쉬운 한국어 우선, 전문 용어 첫 설명, 용어 가이드 추가와 색인 갱신 규칙을 넣었다.
- `scripts/verify-docs.sh`를 추가하고 `verify-harness.sh`를 통해 기본 전체 검사에 연결했다.

## 주요 새 위치

- 제품: `docs/product/`
- 전투와 사용자 경험: `docs/gameplay/`
- 프로그램이 읽는 공용 JSON: `docs/contracts/`
- 코드·Godot·Android: `docs/engineering/`
- 이미지·애니메이션·오디오: `docs/content/`
- 화면 설계: `docs/ui/`
- AI 작업 절차와 역할: `docs/operations/`

전체 이전→현재 경로는 `docs/INDEX.md`의 이동표에 있다.

## 검증 결과

- `./scripts/verify-docs.sh`: PASS
- `./scripts/verify-harness.sh`: PASS
- `./scripts/verify.sh`: PASS
- `git diff --check`: PASS
- `docs/` 최상위 파일 제한: PASS
- Markdown 상대 링크 검사: PASS
- 활성 파일의 이전 경로 검색: PASS
- 공격 데이터 JSON SHA-256: `8abd7d0b605208f8be76dcaa7292d001efe3eafd81b2757d1c7e7c3a8bf8ddc1`, 이동 전후 동일
- 캐릭터 외형 JSON SHA-256: `cc77293715121fe867c6e73bd510290e91853ffdcdab8fb6f9a4c6392e9631b5`, 이동 전후 동일

## 미확인

- 실제 Android 기기는 확인하지 않았다. 문서·경로와 테스트 참조만 바뀌었고 게임 코드, 장면, 자산과 Android 설정 내용은 바꾸지 않았다.
- `forest_arena_install_report.json`은 최초 설치 당시의 기록이므로 이전 문서 경로를 역사적 값으로 유지한다. 현재 위치를 찾는 목록으로 사용하지 않으며 색인에도 이를 명시했다.

## 버전 관리 상태

- 작업 위치: 기존 `feature/combat-resource-ui-baseline` 브랜치.
- 커밋·push·PR·`develop` 병합: 실행하지 않음.
- 작업 시작 전에 이 브랜치에 커밋되지 않은 세계관, 캐릭터 모션과 용어 정리 변경이 함께 있었다. 이 작업만 최신 `origin/develop` 기준으로 옮기면 현재 문서 내용과 기존 사용자 변경을 누락할 수 있어 로컬에서 통합·검증한 상태로 보존했다.

## 되돌리기

1. `docs/INDEX.md`의 이동표를 아래에서 위 순서로 적용해 파일을 이전 위치로 돌린다.
2. README, AGENTS, `.agents/skills/`, 캐릭터 콘셉트 문서와 테스트의 경로를 함께 복원한다.
3. `scripts/verify-docs.sh`와 `verify-harness.sh`의 문서 구조 연결을 제거한다.
4. 이 작업 이전부터 있던 문구 개선, 세계관과 캐릭터 모션 변경은 되돌리지 않는다.

## 다음 작업 규칙

- 새 문서나 공용 파일을 추가할 때 먼저 기존 7개 분류 중 하나를 고른다.
- `docs/INDEX.md`에 목적, 링크와 필요한 관련 문서를 추가한다.
- 쉬운 문장을 먼저 쓰고 유지해야 하는 전문 용어만 `docs/GLOSSARY.md`에 추가한다.
- 문서 변경 뒤 `./scripts/verify-docs.sh`를 실행한다.
