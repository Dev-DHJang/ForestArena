# Forest Arena 운영 색인

현재 개발 단계와 자주 쓰는 검사 명령만 빠르게 찾는 문서다. 낯선 프로젝트 운영·게임 용어는 [용어 가이드](../../GLOSSARY.md)를 참고한다.

## 현재 단계

- 현재는 Phase 4까지 끝났다. 같은 입력이면 같은 결과가 나오는 기본 전투·링아웃, 버전이 있는 Godot 데이터 조합, 네 전투 스타일의 실기기 직접 비교와 장신구 조건·기술 교체·태그 시너지 검증이 완료됐다.
- 로컬 AI 전용 첫 선택·상점·대전 준비·결과 화면은 구현됐다. 공식 `SCR_06`–`SCR_08`
  전체 모드 선택 UI, 성장과 경제는 미구현이다. 다음 공식 단계는 Phase 5 직업 변화
  구조 검증이다.
- 온라인은 Phase 7과 accepted 네트워크 ADR 전까지 구현하지 않는다.
- Godot가 시작할 때 자동으로 준비하는 `ForestArenaResources`는 346개 논리 자산 이름을 실제 파일과 연결하며 24개 품질별 파일 차이를 처리한다. 승인된 전투 배경과 투명 지형을 포함하며 `assets/character/`와 `assets/ui/generated/`의 승인 규칙을 대신하지 않는다.

역할 목록과 요청 라우팅은 [팀 명세](team-spec.md)가 단일 원본이다. 과거 완료 작업과 당시 역할 구성은 `_workspace/` 및 Git 이력의 감사 증적에 보존한다.

## 검증 명령

- 하네스: `./scripts/verify-harness.sh`
- 전체 회귀: `./scripts/verify.sh`
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
