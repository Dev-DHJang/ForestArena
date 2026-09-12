# Forest Arena 운영 색인

## 현재 단계

- 현재 기준은 Phase 2 종료다. Phase 1의 결정론적 전투·입력·링아웃과 Phase 2의 버전 Resource·로드아웃 조합·런타임 주입은 구현 완료다.
- 정식 `SCR_06`–`SCR_08` 선택 UI, 성장, 경제, 복수 장신구, 태그 시너지와 Phase 3 이후 전투 확장은 미구현이다.
- 온라인은 Phase 7과 accepted 네트워크 ADR 전까지 구현하지 않는다.
- `ForestArenaResources` Autoload, 345개 논리 리소스와 23개 품질 변형은 카탈로그 경계다. 전투 UI 플레이스홀더는 최종 승인 자산이 아니며 `assets/character/`와 `assets/ui/generated/`의 승인·소유권을 대체하지 않는다.

역할 목록과 요청 라우팅은 [팀 명세](team-spec.md)가 단일 원본이다. 과거 완료 작업과 당시 역할 구성은 `_workspace/` 및 Git 이력의 감사 증적에 보존한다.

## 검증 명령

- 하네스: `./scripts/verify-harness.sh`
- 전체 회귀: `./scripts/verify.sh`
- Godot 리소스: `python tools/forest_arena/verify_godot_resources.py --project-root .`
- Android debug export: `./scripts/export-debug-android.sh`
- Android 패키지: `./scripts/verify-android-package.sh`
- 연결된 에뮬레이터 생명주기: `./scripts/verify-android-emulator.sh`
- Android 실기기 무선 디버깅: `./scripts/android-wireless-debug.sh` (`docs/forest_arena/ANDROID_WIRELESS_DEBUGGING.md` 참고)

## 미확인 항목

- 실제 Galaxy S23 Ultra를 포함한 물리 Android 기기 검증은 연결·실행 권한이 없으면 미검증으로 남긴다.
- 정식 선택 UI·성장·경제·온라인은 구현 범위 밖이며, 각각의 Phase와 승인 계약 뒤에 검증한다.
