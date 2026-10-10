# 프로젝트 폴더와 저장 공간 관리

## 파일을 둘 위치

| 폴더 | 용도 | 정리 기준 |
| --- | --- | --- |
| `docs/` | 현재 개발 기준과 사용 안내 | `docs/INDEX.md`에서 연결한다. 중복 여부와 사용하는 코드를 확인한 뒤 합친다. |
| `forest_arena/`, `scripts/`, `scenes/`, `tests/` | 실행 코드와 검사 | 코드 참조를 확인하지 않고 이동하지 않는다. |
| `assets/` | 승인 자산과 출처 | 캐릭터·UI 원본과 승인 기록을 함께 보존한다. |
| `_workspace/<topic>/` | 요청·검토·완료 기록과 제작 시안 | 요청·완료 기록, 승인 원본과 백업은 보존한다. 새 임시 생성물은 해당 작업 안에 둔다. |
| `build/android/` | Android APK | 최신 검증 APK를 남긴다. 대응 APK가 없는 `.idsig`는 삭제할 수 있다. |
| `build/demo/` | 데모 배포 묶음과 명세 | 배포에 사용하는 묶음은 보존한다. |
| `artifacts/` | 사용자에게 전달하는 압축 파일 | 문서에서 연결한 파일은 보존한다. |
| `android/` | Godot Android 빌드 템플릿 | 템플릿 소스·설정·`libs/`는 남기고 중간 생성 파일을 정리한다. |
| `server/`, `database/`, `web/` | 서버·DB·관리자 웹 | DB 데이터·환경 파일·실행 중인 서비스는 보존한다. |

작업 기록·빌드·배포 폴더에는 `.gdignore`를 둔다. 이는 Godot 편집기가 폴더 안의 시안과 다른 작업 복사본을 게임 자산으로 자동 검색하지 않게 하는 표시다. 파일 자체와 Python 도구의 읽기는 유지된다. 승인 자산은 기존 `assets/` 또는 `forest_arena/` 경로에 설치한다.

Python `__pycache__/`, `.pyc`와 작업 기록 이미지의 `.import` 자동 생성 파일은 새 Git 관리 대상에서 제외한다. 이미 Git에 저장한 과거 파일은 이 설정만으로 삭제되지 않는다.

## 캐시를 정리할 때

1. 정리 대상과 삭제 전 용량을 `_workspace/<topic>/`에 기록한다.
2. `git status`와 `git worktree list`로 기존 변경과 별도 작업 폴더를 확인한다. 다른 작업 폴더를 통째로 지우지 않는다.
3. Android 빌드가 실행 중이지 않을 때 `android/build/build/`, `android/build/.gradle/`, `android/build/src/main/assets/`를 정리할 수 있다. 다음 Android export에서 다시 만들어진다.
4. Godot가 그 프로젝트를 사용하지 않을 때 `.godot/imported/`와 `.godot/shader_cache/`를 정리할 수 있다. 편집기 설정은 남긴다. 다음 프로젝트 열기에서 자산을 다시 가져온다.
5. 해당 패키지 설치·빌드가 실행 중이지 않을 때 Homebrew·pip 다운로드 캐시, npm의 `_cacache`, Gradle의 `caches/`를 정리할 수 있다. 다음 설치·빌드에 다운로드와 추가 시간이 필요할 수 있다. Gradle wrapper와 설치된 개발 도구는 남긴다.
6. 실행 중인 앱의 캐시·업데이트 파일, 브라우저 프로필, Codex 대화·런타임, Android SDK·에뮬레이터, DB 볼륨은 일괄 정리 대상에 넣지 않는다.
7. `./scripts/verify-docs.sh`, `./scripts/verify.sh`와 Godot 리소스 검사를 실행하고, 실제 확보된 여유 공간을 완료 기록에 남긴다.

## 이름 있는 수동 재검사

`생성 파일 분리 확인`: Godot 가져오기 후 `.godot/imported/`에 작업 기록과 빌드 폴더의 새 이미지가 생기지 않는지 확인한다. 게임 자산이 열리고 자동 검사가 통과하는지도 함께 확인한다.

`기존 변경 보존 확인`: 삭제 전에 기록한 미커밋 파일 해시와 정리 후 파일을 비교한다. 이 작업에서 의도적으로 고친 파일만 차이를 허용한다.
