# Forest Arena 운영 색인

현재 개발 단계와 자주 쓰는 검사 명령만 빠르게 찾는 문서다. 낯선 프로젝트 운영·게임 용어는 [용어 가이드](../../GLOSSARY.md)를 참고한다.

## 현재 단계

- Phase 5 기반 위에서 Phase 6 오프라인 흐름을 개발한다. 현재 경기·조작 기준은 [자현·나비 전투 v2](../../gameplay/two-fighter-combat-v2.md), 제품 범위는 [개발 순서](../../product/roadmap.md)와 승인 ADR을 따른다.
- 승인된 자현 목도리3종·나비 체형18종은 PR112로 통합했다. 검사 범위와 기기 확인의 한계는 [캐릭터 표시 수정 기록](../../../_workspace/fighter-presentation-fixes/04_closeout.md)을 따른다. 과거 통과를 모든 모션·기기의 통과로 확대하지 않는다.
- 실제 앱 메뉴는 [프리미엄 메뉴 런타임](../../ui/premium-menu-runtime-v07.md), 개발 서버 기능은 [메뉴 기능](../../ui/menu-features-v01.md)을 따른다. 별도 Penpot 설계의 완료 여부와 앱 구현 여부를 구분한다.
- 현재 전투 개선은 [ADR-036](../../product/decisions.md#adr-036-전투-입력-여유와-낙하-장외-처리)에 따라 경직·다운·가드 붕괴2배, 동작 전체 콤보 입력, 아래 낙하 뒤 비표시1초 탈락과 LAN4를 사용한다. 실제 Android 검사는 추후 별도 진행한다.
- 조약돌 요요의 장비·쿨타임·AI 선택·LAN5는 [현재 장비 규칙](../../gameplay/pebble-yoyo.md)을 따른다. 신규 캐릭터 사용 모션은 개별 승인 뒤 등록하며 기기 검증은 별도 기록한다.
- LAN·게스트 데모는 [LAN 안내](../../gameplay/lan-1v1-play.md)와 [데모 설치](../../gameplay/demo-install.md), 개발 DB는 [데이터베이스](../../engineering/database.md)를 따른다. 정식 인터넷 온라인·Story 보상·성장·경제는 승인된 별도 범위가 아니면 구현하지 않는다.
- 동시 작업·검사 선택·파일 정리는 [프로젝트 관리](../project-maintenance.md), 역할·배정은 [팀 명세](team-spec.md)가 기준이다. 과거 완료 항목은 개별 작업 기록과 Git 이력에서 찾는다.

## 검증 명령

- 하네스: `./scripts/verify-harness.sh`
- 모션 행위 검토 자료·기록 검사: [실행 절차](../../content/motion-action-review.md)
- 변경 관련 검사: `./scripts/verify.sh` (`--list`로 선택 이유 확인)
- 최종 전체 검사: `./scripts/verify.sh --full`
- 작업 폴더·브랜치·기준 확인: `python3 tools/forest_arena/workflow.py status`
- LAN 실제 연결 자동 검사: `./scripts/verify-lan-runtime.sh`
- Android 자동 검사 LAN 두 경기 분리: `./scripts/verify-android-qa-lan.sh` (화면 없는 로컬 테스트, 실기기 결과와 구분)
- macOS LAN 한 경기 서버: `./scripts/lan-host.sh start|stop|status|logs`
- 직업 ID 독립성: `python3 tools/forest_arena/verify_job_id_independence.py`
- Godot 리소스: `python tools/forest_arena/verify_godot_resources.py --project-root .`
- Android debug export: `./scripts/export-debug-android.sh`
- Android 패키지: `./scripts/verify-android-package.sh`
- 연결된 에뮬레이터 생명주기: `./scripts/verify-android-emulator.sh`
- Android 실기기 무선 디버깅: `./scripts/android-wireless-debug.sh` (`docs/engineering/godot/android-wireless-debugging.md` 참고)
- Android 1~4대 실기기 자동 플레이: `./scripts/verify-android-fleet.sh --apk <apk> --serial <serial> --suite smoke|soak|extended` ([사용 방법과 케이스](../../engineering/godot/android-device-autoplay.md), `--serial`은 대상마다 반복)
- 로컬 서버·DB 시작: `./scripts/server-dev.sh up`
- 기본 게임 DB 저장·재실행 복원: `./scripts/verify-db-profile-runtime.sh`
- 온라인 계약: `./scripts/verify-online-server.sh`
- 온라인 실제 연결: `./scripts/server-dev.sh verify-runtime`

## 미확인 항목

- 캐릭터 표시 수정의 최신 기기 검사는 제한된 표본이다. HOME 복귀·입력 해제와 모든 모션의 전체 기기 확인은 별도 재검사 대상이다.
- 물리 Android 두 대의 LAN 동시 플레이·Wi-Fi 단절/복귀와 사람이 듣는 사운드 품질은 해당 환경에서 확인해야 한다.
- Story 대화·보상·성장·경제와 정식 인터넷 온라인의 완료를 주장하지 않는다.
