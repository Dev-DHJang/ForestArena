# 새 게임 기본 뼈대 압축 파일

[ZIP 파일](../../artifacts/new-game-starter-v1.zip)을 새 빈 폴더에 풀어 새로운 게임의 개발 준비에 사용한다. 게임 코드와 기존 게임 자산은 포함하지 않는다.

## 시작 순서

1. 압축을 풀고 `game-starter/START_HERE.md`를 읽는다. 숨김 폴더 `.agents`도 풀어야 한다.
2. 이 폴더를 Codex에서 열고 START_HERE의 시작 요청문을 전달한다.
3. `project-input.json`에 이름·ID·핵심 플레이·첫 목표와 선택 항목을 작성한다.
4. 사용자와 중요한 입력을 확인한 뒤 `confirmed`를 true로 바꾸고 `python3 tools/configure_project.py`를 실행한다.
5. `python3 tools/verify_bootstrap.py --scope all --require-configured`를 실행하고 마무리 기록에 실제 결과를 적는다.

Python 3.9 이상이 필요하다. 엔진·플러그인·외부 Python 패키지는 필요하지 않다. Windows에서는 Python 명령을 사용하며 macOS·Linux에서는 포함된 셸 명령도 사용할 수 있다.

## 포함 내용

- 공통 문서: 짧은 AGENTS·README, 색인, 제품 방향·개발 순서·결정, 기술·콘텐츠 기준.
- 작업 체계: 팀 명세·운영 색인, 한 에이전트가 순서대로 사용할 최소 workflow 스킬.
- 실제 도구: 이름·ID·초기 입력 적용, 문서·링크·역할·스킬·필수 파일·식별자 검사.
- 선택 구성: Godot 자산 ID·등록 목록 계획, Android 터치·화면·중단/복귀·성능 확인 계획.
- 독립 지침서와 요청·마무리 기록.

입력 전 기본 뼈대 검사와 게임별 설정 완료 검사를 구분한다. 엔진 미정·외부 도구 없음으로 진행할 수 있다. Godot는 engine=`godot`, Android는 android=`true`로 각각 선택하며 게임 실행 프로젝트는 만들지 않는다.

## 보존과 재실행

같은 입력으로 다시 실행하면 기존 문서와 결정을 변경하지 않는다. 최초 설정 전에 기본 문서가 수정됐거나 선택 구성 위치에 기존 파일이 있으면 자동 적용을 중단해 덮어쓰지 않는다. 이후 입력 변경은 결정 기록과 관련 문서를 확인해 수동으로 반영한다.

기존 프로젝트에 압축을 바로 덮어 풀지 않는다. 별도 폴더에서 [독립 지침서](new-game-bootstrap.md)의 기존 프로젝트 절차에 따라 필요한 부분만 비교해 보완한다. 설치·계정 연결·Git 원격·자동 병합 정책은 포함하지 않는다.

## 다시 만들기와 검사

저장소 루트에서 다음을 실행한다.

```sh
python3 tools/new_game_bootstrap/build_starter.py
python3 tools/new_game_bootstrap/test_starter.py
```

첫 명령은 ZIP을 다시 만들며 두 번째는 임시 폴더에 실제로 풀어 입력 적용·재실행·선택 구성·기존 파일 보존과 누락·링크·스킬·식별자 실패 탐지를 확인한다. 같은 원본이면 압축 파일의 내용과 확인값(SHA-256)도 같다.

생성 원본은 `tools/new_game_bootstrap/`에서 관리한다. 현재 게임의 `.agents/skills/`나 게임 동작은 바꾸지 않는다. 배포 파일의 크기·확인값과 실제 검사 결과는 `_workspace/new-game-starter/04_closeout.md`에 기록한다.
