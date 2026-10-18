# 서버·DB 운영 폴더 이전

사용자 승인에 따라 /Users/jdh/Desktop/Dev/ForestArena에 실제 설정·실행 파일·마이그레이션·백업을 배치하고 새 경로에서 서비스를 재시작했다. 게임·서버 개발 소스는 기존 저장소에 유지하고 운영 실행 묶음을 분리했다.

DB·API·게임 서버는 Docker에서 healthy이며 forest-arena-development 프로젝트와 forest_arena_development_postgres 볼륨을 유지한다. 세 컨테이너의 Compose·환경 파일 라벨과 DB init/migrations 마운트가 새 경로를 참조한다. 이전 전후 13개 사용자 테이블의 행 수가 정확히 동일하다. app.players 64, player_profiles 31, matches 12를 유지하며 admin·infra 표도 같음을 확인했다.

관리자 웹의 기존 JAR·db.env·keys.json·로그를 새 admin/ 폴더로 복사했다. 원본과 바이트 단위 비교가 일치하며 인증 값은 출력하지 않았다. 기존 프로세스의 실행 경로를 확인해 중지하고 새 폴더의 JAR로 재시작했다. 프로세스 실행 명령, 새 시작 로그와 HTTP 200을 확인했다. 새 계정·키 생성, 비밀번호·권한 변경과 DB 초기화는 수행하지 않았다.

운영 폴더에는 scripts/server-dev.sh, db-dev.sh, admin-dev.sh와 database/, admin/, images/ 및 README.md가 있다. images/의 API·게임 서버·PostgreSQL tar는 기존 실행 이미지를 그대로 내보낸 것이며 재빌드하지 않았다. up은 기존 이미지를 재사용하고 없을 때만 tar에서 가져온다. DB 데이터 파일은 Docker 볼륨에 남고 database/backups에 dump를 보관한다. 이전 전 백업 forest_arena_dev_20261010T052007Z.dump를 포함한 기존 백업을 복사했다.

보안: 운영 루트·admin·백업 폴더는 0700, 환경·키 파일은 0600. 원본 운영 파일과 이전 관리자 상태 폴더는 복구용으로 남겼고 어떤 데이터도 삭제하지 않았다. 이전 경로에서 중복 실행하지 않는다.

검증: shell 구문, Compose config --quiet, 원본 환경·키·JAR 비교, 전체 행 수 보존, Docker healthy, API /health/ready의 ready, 관리자 csrf HTTP200과 게임 TCP 7777 연결 통과. QA는 별도 기록에 남긴다. 게임 기능·Android·권한 전체 검사는 동일 실행 파일의 위치 이전에서 다시 수행하지 않았다.

새 admin/db.env의 기존 계정으로 TCP·비밀번호 인증 DB 연결과 admin.accounts 조회를 확인했다. 새 scripts/db-dev.sh backup이 종료 0으로 database/backups/forest_arena_dev_20261010T052506Z.dump를 만들었다. 독립 QA r01은 pass이며 필수 수정 없음이다. 별도 macOS LAN 호스트는 중지 상태였으며 새로 시작하거나 네트워크 공개 범위를 늘리지 않았다.

저장소 문서 전체 검사는 docs 최상위 파일 제한 위반으로 실패했다. 이번 이전은 docs/ 파일을 추가하거나 변경하지 않았고 다른 작업 문서를 임의로 이동하지 않는다. git diff --check는 통과했다. 운영 이전 검사 결과와 저장소 전체 문서 검사 실패를 구분한다.

원격 통합: 로컬 설치·운영 상태 이전만 수행했다. 저장소의 게임·서버 기능 코드는 변경하지 않았고, 기밀 환경·키·백업·이미지를 Git 또는 외부 서비스에 업로드하지 않았다. 새 PR이나 원격 병합은 없다.

복구: 새 관리자 웹을 stop하고, 이전 관리자 스크립트의 start를 사용한다. Docker는 이전 Compose와 동일 이미지를 --no-build로 up하여 기존 마운트로 되돌린다. 볼륨·DB·키 초기화는 필요하지 않다. 이전 경로에서 setup·key-init·reset을 실행하지 않는다.
