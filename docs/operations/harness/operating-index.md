# Forest Arena 운영 색인

현재 개발 단계와 자주 쓰는 검사 명령만 빠르게 찾는 문서다. 낯선 프로젝트 운영·게임 용어는 [용어 가이드](../../GLOSSARY.md)를 참고한다.

## 현재 단계

- Phase 5까지의 전투·로드아웃 기반 위에서 Phase 6 오프라인 전체 흐름을 진행 중이다.
- 로컬 AI의 첫 선택·0원 상점·저장·결과 화면과 스토리·AI·연습·Solo·Team 모드 선택, 최대
  8명 실제 경기 생성은 구현됐다. 팀전은 팀당 1~4명이며 온라인처럼 보이는 기능은 추가하지 않았다.
- Galaxy S23 Ultra에서 최신 APK의 첫 선택·로컬 AI 대전·터치·결과·재대전·중단/복귀·로비 복귀를
  확인했다. AI와 실제로 한 판을 끝냈고, 경기 표본은 60 FPS 및 p95 약 16.7 ms였다. 접근성 설정의
  실제 기기 세부 가독성·진동 확인과 사람이 듣는 사운드 품질 검증은 남아 있다.
- Story 대화·보상·성장과 사운드의 구체 규칙은 아직 문서에서 미정이다. 따라서 Phase 6을 완료로
  처리하지 않는다.
- ADR-028 범위로 macOS 한 경기 서버와 같은 Wi-Fi Android 두 대의 LAN 1대1 경로를
  구현했다. 네 캐릭터·장신구 6종, 60Hz 판정·20Hz 표시, 60초 재접속과 20초 재대전 계약의
  자동 두 클라이언트 검사와 Android 에뮬레이터의 실제 macOS Wi-Fi 접속·결과·재대전은
  통과했다. 물리 Android 두 대 검증은 사용자 결정으로 다음 계획에 반영한다.
- ADR-008·026의 DB 기반 개발 흐름은 별도로 유지한다. ADR-029로 기본 게임의 보유·선택·접근성 설정을 로컬 DB에 저장하는 개발 모드를 추가한다. 정식 인터넷 온라인·클라우드·8인전은 Phase 7 전체 범위 전까지 구현하지 않는다.
- Godot가 시작할 때 자동으로 준비하는 `ForestArenaResources`는 350개 논리 자산 이름을 실제 파일과 연결하며 24개 품질별 파일 차이를 처리한다. 승인된 전투 배경과 투명 지형을 포함하며 `assets/character/`와 `assets/ui/generated/`의 승인 규칙을 대신하지 않는다.

역할 목록과 요청 라우팅은 [팀 명세](team-spec.md)가 단일 원본이다. 과거 완료 작업과 당시 역할 구성은 `_workspace/` 및 Git 이력의 감사 증적에 보존한다.

## 검증 명령

- 하네스: `./scripts/verify-harness.sh`
- 전체 회귀: `./scripts/verify.sh`
- LAN 실제 연결 자동 검사: `./scripts/verify-lan-runtime.sh`
- macOS LAN 한 경기 서버: `./scripts/lan-host.sh start|stop|status|logs`
- 직업 ID 독립성: `python3 tools/forest_arena/verify_job_id_independence.py`
- Godot 리소스: `python tools/forest_arena/verify_godot_resources.py --project-root .`
- Android debug export: `./scripts/export-debug-android.sh`
- Android 패키지: `./scripts/verify-android-package.sh`
- 연결된 에뮬레이터 생명주기: `./scripts/verify-android-emulator.sh`
- Android 실기기 무선 디버깅: `./scripts/android-wireless-debug.sh` (`docs/engineering/godot/android-wireless-debugging.md` 참고)
- 로컬 서버·DB 시작: `./scripts/server-dev.sh up`
- 기본 게임 DB 저장·재실행 복원: `./scripts/verify-db-profile-runtime.sh`
- 온라인 계약: `./scripts/verify-online-server.sh`
- 온라인 실제 연결: `./scripts/server-dev.sh verify-runtime`

## 미확인 항목

- 최신 APK에서 네 캐릭터의 선택·경기 진입은 확인했다. 다만 모든 신규 모션·장신구 조합의
  물리 Android 기기 재생은 미확인이다.
- Story 대화·보상·성장·경제와 정식 인터넷 온라인은 구현 범위 밖이다.
- 다음 계획: LAN 1대1의 물리 Android 두 대 동시 플레이, Wi-Fi 단절·복귀와 사람이 듣는
  사운드 품질.
