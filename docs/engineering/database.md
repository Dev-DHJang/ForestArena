# 개발계 데이터베이스

개발계에서는 로컬 PostgreSQL로 실행·마이그레이션·백업 절차만 준비한다. 게임이 이 DB를 직접 읽거나 쓰지 않으며, 플레이어·성장·재화·계정·온라인 데이터 표도 아직 만들지 않는다. 현재 Phase 2의 범위를 지키기 위한 구성이다.

## 시작 방법

macOS에서는 아래 명령으로 무료 Colima와 Docker 도구를 설치한다. Docker Desktop은 필요하지 않다.

```sh
./scripts/db-dev.sh install
./scripts/db-dev.sh up
./scripts/db-dev.sh status
```

처음 `up`을 실행하면 `database/.env.development`에 개발 전용 비밀번호를 만들고, PostgreSQL 컨테이너를 시작한 뒤 마이그레이션을 적용한다. 이 파일과 `database/backups/`는 Git에 저장하지 않는다.

DB는 `127.0.0.1:55432`, 이름은 `forest_arena_dev`로만 열려 있다. 같은 네트워크의 다른 기기에서는 연결할 수 없다. 앱용 계정 `forest_arena_app`은 표와 역할을 만들거나 바꿀 수 없고, 마이그레이션은 관리자 계정으로만 실행한다.

## 일상 작업

```sh
./scripts/db-dev.sh logs
./scripts/db-dev.sh psql
./scripts/db-dev.sh migrate
./scripts/db-dev.sh backup
./scripts/db-dev.sh down
```

`down`은 컨테이너만 멈추며 데이터는 남긴다. `restore <백업 파일> --confirm-development`와 `reset --confirm-development`는 개발계 표식, 로컬 호스트, `_dev` DB 이름을 모두 확인한다. `reset`은 개발계 볼륨을 지우므로 되돌릴 수 없다. 먼저 `backup`으로 백업 파일을 만든다.

## 환경을 나누는 방법

개발계·검증계·운영계는 같은 PostgreSQL 서버 안에서 DB 이름만 나누지 않는다. 각 환경은 별도 PostgreSQL 인스턴스, 별도 볼륨 또는 저장소, 별도 계정과 별도 비밀번호를 사용한다. 공통 마이그레이션 파일은 새 환경에 순서대로 적용할 수 있지만, 환경 표식은 해당 환경 배포 과정에서 한 번만 넣는다.

검증계와 운영계 구성, 게임 저장 데이터, Godot 연결, 클라우드 백업과 온라인 기능은 Phase와 제품·저장 계약이 승인된 뒤에 별도 작업으로 진행한다.

## 검사

```sh
./scripts/verify-database.sh
./scripts/verify-database-runtime.sh
```

첫 명령은 컨테이너를 시작하지 않고 개발계 설정, 비밀번호 제외, 마이그레이션 기록과 삭제 보호 규칙을 확인한다. 두 번째 명령은 컨테이너를 시작해 개발계 표식, 반복 마이그레이션, 앱 계정의 데이터 읽기·쓰기와 표 생성 거부를 확인한다.
