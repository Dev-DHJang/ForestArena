# Forest Arena 운영 색인

현재 개발 단계와 자주 쓰는 검사 명령만 빠르게 찾는 문서다. 낯선 프로젝트 운영·게임 용어는 [용어 가이드](../../GLOSSARY.md)를 참고한다.

## 현재 단계

- Phase 5까지의 전투·로드아웃 기반 위에서 Phase 6 오프라인 전체 흐름을 진행 중이다.
- 로컬 AI의 첫 선택·0원 상점·저장·결과 화면과 스토리·AI·연습·Solo·Team 모드 선택, 최대
  8명 실제 경기 생성은 구현됐다. 팀전은 팀당 1~4명이며 온라인처럼 보이는 기능은 추가하지 않았다.
- Galaxy S23 Ultra에서 최신 APK의 첫 선택·로컬 AI 대전·터치·중단/복귀·로비 복귀를 확인했다.
  접근성 설정의 실제 기기 세부 가독성·진동 확인과 사운드 검증은 남아 있다.
- Story 대화·보상·성장과 사운드의 구체 규칙은 아직 문서에서 미정이다. 따라서 Phase 6을 완료로
  처리하지 않는다.
- 온라인은 Phase 7과 accepted 네트워크 ADR 전까지 구현하지 않는다.
- Godot가 시작할 때 자동으로 준비하는 `ForestArenaResources`는 346개 논리 자산 이름을 실제 파일과 연결하며 24개 품질별 파일 차이를 처리한다. 승인된 전투 배경과 투명 지형을 포함하며 `assets/character/`와 `assets/ui/generated/`의 승인 규칙을 대신하지 않는다.

역할 목록과 요청 라우팅은 [팀 명세](team-spec.md)가 단일 원본이다. 과거 완료 작업과 당시 역할 구성은 `_workspace/` 및 Git 이력의 감사 증적에 보존한다.

## 검증 명령

- 하네스: `./scripts/verify-harness.sh`
- 전체 회귀: `./scripts/verify.sh`
- 직업 ID 독립성: `python3 tools/forest_arena/verify_job_id_independence.py`
- Godot 리소스: `python tools/forest_arena/verify_godot_resources.py --project-root .`
- Android debug export: `./scripts/export-debug-android.sh`
- Android 패키지: `./scripts/verify-android-package.sh`
- 연결된 에뮬레이터 생명주기: `./scripts/verify-android-emulator.sh`
- Android 실기기 무선 디버깅: `./scripts/android-wireless-debug.sh` (`docs/engineering/godot/android-wireless-debugging.md` 참고)

## 미확인 항목

- 최신 전체 캐릭터 모션 묶음의 물리 Android 기기 재검은 사용자 지시에 따라 나중으로
  미뤘으며 미확인이다. 이전 로컬 AI 빌드의 Galaxy S23 Ultra 결과를 최신 묶음의 통과로
  바꾸지 않는다.
- 정식 선택 UI·성장·경제·온라인은 구현 범위 밖이며, 각각의 Phase와 승인 계약 뒤에 검증한다.
