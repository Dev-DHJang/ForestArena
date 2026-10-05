# 종료 기록

## 통합 결과

- 관리 위치를 `/Users/jdh/Desktop/workspace/ForestTales`로 통일했다.
- 로컬 권위 서버·API·PostgreSQL 구현은 `d52df4d`로, 숲빛 UI 인계 자산은 `f700ef1`로 보존했다.
- 온라인 검사 의존성을 깨끗한 작업 폴더에서도 준비하도록 `37ae97a`에서 보완했다.
- 메인 폴더는 원격 `develop`과 같은 `37ae97a`이며 추가 worktree는 없다.

## 제거한 작업 폴더

- `ForestArena-local-ai`: 내용이 이미 `develop`에 포함된 깨끗한 worktree였다.
- `ForestTales-combat-overhaul`: 내용이 이미 `develop`에 포함된 깨끗한 worktree였다.
- `ForestTales-development-database`: 내용이 이미 `develop`에 포함된 깨끗한 worktree였다.
- `ForestTales-local-online`: `d52df4d`가 `develop`에 포함된 뒤 제거했다.
- `ForestTales-penpot-full-ui-ux`: 현재 Phase 6 계약과 충돌하는 과거 설계라 병합하지 않았다. 고유 커밋은 `origin/feature/penpot-full-ui-ux`에 보존했다.

위 폴더의 소스는 Git 커밋과 원격 브랜치에서 복구할 수 있다. 로컬에서만 다시 만드는 `.godot` 가져오기 캐시, Gradle 빌드 결과, 실패한 Docker 빌드 층과 브라우저 캐시는 저장 공간 확보를 위해 제거했다.

## 로컬 환경

- `database/.env.development`를 메인 폴더로 옮기고 소유자만 읽고 쓸 수 있는 권한 `600`을 유지했다.
- PostgreSQL 이름 있는 볼륨은 삭제하지 않아 개발 데이터가 유지된다.
- 기본 바인드는 loopback이며 LAN 공개는 환경값을 명시적으로 바꿀 때만 허용한다.
- 정리 뒤 데이터 볼륨의 여유 공간은 약 16 GiB다.

## 검증

- `./scripts/verify.sh`: Phase 1~6, 로컬 AI, UI, 온라인 계약과 하네스 전체 통과.
- 숲빛 UI: PNG 53개, 터치 영역 겹침 0, 안전 영역 이탈 0, 기존 이미지 슬롯 61개 누락 0.
- Godot 리소스: 논리 자산 346개, 품질별 차이 24개 통과.
- 메인 폴더 온라인 런타임: 실제 Godot 클라이언트 두 개, 60초 연결 해제 기권, API 결과 제출과 PostgreSQL 저장 통과. 최종 확인 경기 ID는 `c50148b6-ba77-4d4c-97c1-d0b3c9279401`이다.
- 물리 Android 기기에서 새 온라인 흐름을 확인하지 않았으므로 기기 통과로 기록하지 않는다.
