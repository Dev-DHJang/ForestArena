# 새 게임 기본 뼈대 ZIP 마무리

## 상태

ZIP 작성·실제 압축 해제 시나리오 검사·저장소 검사 완료. 원격 반영은 자동 승인 검토의 거절로 보류했다.

## 산출물

- `artifacts/new-game-starter-v1.zip`: 루트 폴더 `game-starter/`, 27개 파일, 36,803바이트.
- SHA-256: `1d5d7a7ffb5b28581e54ee5e12e43a3df1ff7ca23571a16e1367c5cfd39ea7f0`.
- 포함: START_HERE, 입력 JSON, AGENTS·README·공통 문서, 최소 workflow 스킬, 최초 설정·구조 검사 도구, 셸 명령, Godot·Android 선택 문서, 요청·마무리 기록.
- 외부 참고 파일을 필요로 하지 않도록 독립 지침서의 참고 링크 절을 제외한 복사본도 포함했다.
- 재생성 원본: `tools/new_game_bootstrap/build_starter.py`, `configure_project.py`, `verify_bootstrap.py`, `test_starter.py`.
- 사용 안내: `docs/operations/new-game-starter-package.md`, `docs/INDEX.md` 연결.
- 기존 게임 코드·자산·활성 스킬과 다른 작업의 미커밋 변경은 보존했다.

## 실제 검사

- 통과: `python3 tools/new_game_bootstrap/build_starter.py`.
- 통과: `python3 tools/new_game_bootstrap/test_starter.py` — 12개 자동 검사. 실제 ZIP을 임시 폴더에 풀고 Python 도구·셸 명령을 실행했다.
- 통과: `./scripts/verify-docs.sh`, `./scripts/verify-harness.sh`, `git diff --check`.
- 최신 develop 기반 별도 작업 폴더에서도 문서·역할 검사, 패키지 자동 검사 12개를 통과했다. 재생성 ZIP과 제공 ZIP의 바이트도 동일했다.
- 최초 전체 검사: 종료 코드 134. 제한된 실행 환경에서 Godot 사용자 설정·로그 경로 쓰기 오류 뒤 `phase0_smoke.gd`가 중단됐다. 이 결과는 통과가 아니다.
- 통과: 사용자 설정·로그 접근이 가능한 환경의 `./scripts/verify.sh` — 종료 코드 0, `Forest Arena verification passed.`. 로그는 `/tmp/new-game-starter-verify-unrestricted.log`.

## 패키지 검사 범위

| 확인 | 결과 |
| --- | --- |
| 빈 폴더·엔진 미정·선택 도구 없음 | 기본 뼈대 통과, 입력 미적용 시 strict 검사 실패, 실제 이름·ID 적용 후 통과 |
| Godot·Android 선택 | 문서·색인·빈 자산 등록 목록 생성, 셸 검사 3개 통과 |
| Godot 없이 Android 선택 | 독립 Android 문서만 활성화 |
| 재실행과 후속 결정 | 동일 입력 재실행 시 파일 확인값이 모두 같음, 후속 사용자 결정 보존 |
| 최초 설정 전 수정 파일·기존 선택 문서 | 전체 적용 중단, 사용자 내용과 다른 파일 모두 보존 |
| 필수 파일 누락·링크·제목 오류 | 경로·문제와 함께 검사 실패, 코드 블록 예시 링크는 검사 제외 |
| 스킬 이름·설명 형식·역할 책임 오류 | 각각 검사 실패 |
| 미치환 표시·임시 ID·이전 프로젝트 식별자 | 실제 생성 문서의 오류 탐지, 지침서 자체 예시만 좁게 제외 |
| 이름의 따옴표·콜론·역슬래시 | 스킬 YAML 설명 문자열을 올바르게 기록하고 검사 통과 |
| 미확인 입력·잘못된 ID·심볼릭 링크 | 최초 적용 중단, 폴더 밖 사용자 파일 보존 |
| ZIP 내용·실행 권한·재현성 | CRC 정상, 숨김 스킬 포함, Git 이력·캐시·기존 이미지 없음, 셸 권한 기록, 같은 원본은 같은 ZIP 바이트 |

## 사용과 다음 작업

새 빈 폴더에 압축을 풀고 START_HERE의 요청문을 Codex에 전달한다. 게임별 입력을 확인한 뒤 설정 도구와 `--require-configured` 검사를 실행한다. 기존 프로젝트 위에 바로 덮어 풀지 않는다.

게임 실행·에뮬레이터·물리 기기 검사는 이 기본 뼈대의 검사가 아니다. 게임 구현 이후 추가한다. 이번 검사 결과를 기기 통과로 기록하지 않는다.

## 저장소 반영

최신 origin/develop 기반 `chore/new-game-starter` 브랜치와 `/private/tmp/forest-new-game-starter-integration` 작업 폴더를 준비했다. 이번 ZIP·생성 도구·사용 문서·기록만 반영하며 기존 사용자 변경은 섞지 않는다. 자동 승인 검토가 commit·push 요청 중 공개 저장소로의 push를 거절해 해당 명령은 실행되지 않았다. 이유는 목적지와 정확한 공개 파일에 대한 명시적 승인이 필요하다는 것이며 원격 변경·PR·병합은 하지 않았다. 재개 조건은 사용자가 공개 저장소 Dev-DHJang/ForestArena에 이 ZIP·생성 도구·사용 문서·작업 기록을 반영하도록 명시적으로 승인하는 것이다. 로컬 산출물 작성과 검사는 완료한다.

- 로컬 작성 commit: `3638662` (별도 작업 브랜치). push·PR·병합은 보류 상태다. 되돌리기는 해당 로컬 commit의 revert로 수행할 수 있다.
