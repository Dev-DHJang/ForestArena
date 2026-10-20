# 두 캐릭터 정책의 실제 DB 확인

## 환경과 기존 기록 보호

2026-10-20에 전용 Colima 프로필 `fa-two-fighter-db-qa`를 만들고 `--activate=false --ssh-config=false`로 시작했다. 기존 `default` 프로필은 시작하지 않았다. Docker 기본 context와 개발 `.env.development`를 바꾸지 않았다.

- 별도 Docker socket을 명시한 전용 PostgreSQL 18.6 컨테이너를 사용했다. 기존 개발 DB와 같은 PostgreSQL 이미지 버전이다.
- 컨테이너 이름은 `fa-two-fighter-db-qa`, DB 이름은 `forest_menu_qa_two_fighter_dev`다. 저장 공간은 전용 `tmpfs`이고 기존 이름 있는 볼륨은 연결하지 않았다.
- DB와 API에는 사용 가능한 별도 loopback 포트를 배정했다. 새 비밀번호·토큰 비밀값은 실행 메모리에만 두고 기존 환경 파일을 읽지 않았다.
- 저장소의 SQL 변경 파일 0001~0007을 빈 인스턴스에 순서대로 적용하고 환경 표식은 `verification`으로 기록했다. API는 현재 작업 폴더 소스로 빌드하여 실행했다.
- Godot 검사는 기존 일반 사용자 파일 대신 검사 전용 경로를 사용한다. 메뉴 검사는 일반 프로필·세션·프리셋 파일의 검사 전후 SHA-256도 비교한다.
- 기본 `verify-db-profile-runtime.sh`는 개발 환경 파일을 강제로 읽으므로 그대로 실행하지 않았다. 같은 catalog 생성 → API build → Godot 쓰기 → 별도 프로세스 복원 → 실제 API/SQL 대조 명령을 전용 환경에서 실행했다.
- `verify-database-runtime.sh`의 `db-dev.sh up`과 기존 개발 DB 안의 검사 표 생성은 실행하지 않았다. `verify-admin-db.sh`·`prepare-admin-test-db.py`도 기존 개발 인스턴스·관리자 상태를 참조하므로 실행하지 않았다.

재실행 코드는 `qa/run-isolated-db.py`, 새 정책의 독립 검사는 `qa/db-selection-check.mjs`다. 원시 로그와 비밀값을 제외한 결과는 모두 같은 `qa/` 폴더에 둔다. 전체 `verify.sh`는 다른 담당자가 실행하므로 중복 실행하지 않았다.

## 실행 결과

판정: **pass**. 아래 결과는 실제 HTTP와 격리 PostgreSQL을 사용했다. API 대역이나 모의 응답은 넣지 않았다. 실제 Android 기기는 실행하지 않았다.

| 실행 | 결과와 확인 범위 | 원시 기록 |
| --- | --- | --- |
| `tests/db_profile_runtime.gd` | 쓰기 PASS. 실제 앱의 이전·활성 두 캐릭터 구매·선택·설정·DB 실패 시 화면 보존·서버 응답 유실 재시도·변경 번호 충돌·토큰 회전 복구·실제 경기 진입 | `qa/db-profile-game-write.log` |
| 같은 검사의 별도 프로세스 `--restore` | PASS. DB 모드·두 캐릭터 보유·미장착 선택·설정·닉네임·미니맵 복원, 기기 원본 보존 | `qa/db-profile-game-restore.log` |
| `server/api/dist/tests/profile_runtime.js` | PASS. 실제 인증 분리·이전·동시 변경·같은 요청 재전송·토큰 재발급과 Godot 최종 프로필/변경 번호의 SQL 행 완전 일치 | `qa/db-profile-api-runtime.log`, `qa/db-profile-game-sql-report.json` |
| `qa/db-selection-check.mjs` | **13개 PASS**. 기존 보유·설정 보존과 실제 DB 저장 실패를 포함한 새 선택 정책 독립 확인 | `qa/db-selection-check.log`, `qa/db-selection-report.json` |
| `tests/menu_features_app_api.gd` | **123개 PASS**. 실제 앱의 DB/LAN/기기 계정 통합, 과거 장신구 보유·미장착 유지, 재시작·부분 로컬 저장 실패 복구, 프리셋·입력 설정 보존, 친구·순위·오프라인/LAN 기록 분리와 51건 분할 업로드 | `qa/db-menu-features-app-api.log`, `qa/db-menu-features-app-api-report.json` |

추가 선택 검사에서는 다음을 직접 대조했다.

1. 묘령·유란·나비와 과거 장신구 두 개를 가진 v3 행을 SQL로 넣었다. GET이 선택만 나비·미장착·활성 상대 자현으로 바꾸고 모든 보유·닉네임·미니맵·접근성 값을 유지했으며, 응답과 실제 SQL 행이 일치했다. 변경 번호는1을 유지했다.
2. 반복 GET은 응답·변경 번호와 `updated_at`까지 유지했다. 활성 캐릭터가 없는 옛 보유에는 자현을 한 번 무료 추가하고 묘령·유란과 장신구 보유는 유지했다.
3. 신규 import와 기존 행이 있는 import 모두 정리한 선택을 실제 저장한 뒤 응답했다. 기존 행의 보유를 새 import 입력으로 덮어쓰지 않았다.
4. 묘령·장신구의 새 구매와 비활성 캐릭터·장신구 선택은400으로 거부했다. 거부 전후 SQL 프로필·변경 번호·저장 시간이 같았다.
5. 검사 소유 행 하나에만 UPDATE를 실패시키는 임시 DB trigger를 걸었다. GET과 import가 모두500 `internal_error`를 응답했고, 정리된 값을 성공으로 반환하지 않았다. SQL 원본도 유지했다. trigger를 제거한 뒤 GET이 성공하고 정리한 값을 저장했다.

검사 마지막 실제 DB에는 환경 표식 `verification`, 검사 프로필13개와 처리 요청11개가 있었다. 실제 행의 프로필 관찰값은 `qa/db-selection-report.json`에 기록했다. 토큰·비밀번호는 보고서에 넣지 않았다.

## 종료 정리와 한계

- 전용 API 프로세스를 종료하고 전용 컨테이너를 삭제했다. `tmpfs` DB도 함께 사라졌다. 전용 Colima 프로필은 중단한 뒤 이번 검사에서 만든 프로필·컨테이너 저장 공간까지 삭제했다. 기존 `default` 프로필은 전후 모두 Stopped이고 Docker context도 `default` 그대로다.
- 이번 실행이 만든 Godot DB 검사 경로 두 개와 `/private/tmp`의 전용 보고서 원본을 삭제했다. 보존용 프로필 보고서에는 인증 정보가 없다. 메뉴 검사가 쓰는 기존 작업 폴더의 보고서는 실행 전 바이트를 복원했다.
- 실행 오케스트레이션·포트·정리 결과는 `qa/db-isolated-results.json`, `qa/db-orchestration.log`, `qa/db-colima-stop.log`, `qa/db-colima-delete.log`, `qa/db-local-fixture-cleanup.log`에 남겼다. 삭제 도구가 이미 중단된 디스크 잠금 해제 경고를 냈으나 종료값은0이며 전용 프로필·디스크 경로가 사라진 것을 확인했다.
- 강제 SQL 실패 시험의 API `internal_error` 두 건은 의도한 실패다. `qa/db-api-server.log`에 요청 경로만 기록됐다.
- Godot 복원·메뉴 검사 종료 때 ObjectDB4개/Resource2개 정리 경고가 남았다. 기능 결과와 구분하며 이 경고가 해결됐다고 기록하지 않는다. SCRIPT ERROR는 없었다.
- 이번 담당자는 생산 코드나 기존 테스트 기대값을 추가 수정하지 않았다. 실제 Android, 모션 승인, 운영 배포와 전체 검사는 이 DB 결과에 포함하지 않는다.
- `./scripts/verify-docs.sh`와 `git diff --check`는 PASS다. 검사 코드 실행 뒤 추가한 정리 코드도 Python 문법 검사를 통과했다.
