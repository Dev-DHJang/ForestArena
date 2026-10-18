# Forest Arena 로컬 서버·DB 운영 폴더

실행 위치: /Users/jdh/Desktop/Dev/ForestArena. 게임·서버 개발 소스는 기존 저장소에 유지하고 이 폴더는 검증된 실행 파일과 로컬 설정을 보관한다.

```sh
cd /Users/jdh/Desktop/Dev/ForestArena
./scripts/server-dev.sh up
./scripts/admin-dev.sh start
./scripts/server-dev.sh status
./scripts/admin-dev.sh status
./scripts/db-dev.sh backup
```

API는 http://127.0.0.1:3000, 게임 서버는 ws://127.0.0.1:7777, 관리자 웹은 http://127.0.0.1:8080이다. DB는 127.0.0.1:55432이다. 기존 Docker 프로젝트명과 DB 볼륨명을 유지한다.

- database/: Compose·환경 설정·초기화·마이그레이션·백업.
- images/: 현재 검증된 API·게임 서버·PostgreSQL 이미지의 tar 실행 묶음. up은 이미지가 없을 때만 가져오며 새로 빌드하지 않는다.
- admin/: 기존 관리자 웹 실행 JAR·환경·암호화 키·실행 로그·PID. 키를 새로 만들거나 계정 비밀번호를 바꾸지 않는다.
- scripts/: 서버·DB·관리자 웹 실행 명령.

실제 DB 내용은 Docker의 forest_arena_development_postgres 볼륨에 남는다. 이 폴더를 옮겨도 DB 내용은 자동 이동하지 않는다. database/backups의 dump가 복구용 DB 파일이다.

down은 컨테이너를 멈추며 DB 볼륨을 남긴다. db-dev.sh reset·restore는 삭제 또는 덮어쓰기가 있는 명령이므로 평소 이전·재시작에 사용하지 않는다. 기존 저장소와 이전 관리자 상태 폴더는 복구용으로 보존하며 이전 경로에서 서버를 중복 실행하지 않는다.

새 코드 배포는 저장소에서 별도 빌드·검증한 뒤 이미지를 갱신하고, 관리자 웹은 검증된 새 JAR를 배치한다. 이 폴더에는 결제·재화 구현이나 계정·권한 변경 기능을 추가하지 않는다.
