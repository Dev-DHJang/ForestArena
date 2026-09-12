# Forest Arena 운영 색인

## 현재 단계

- Phase 3 전투 원형 비교의 코드·자동 회귀는 구현됐다. 가드·회피·잡기·차지·방향 특수기·궁극기, 세 전문 직업, 결정론 봇, 개발 전용 런처와 로컬 JSONL 텔레메트리를 포함한다.
- Phase 3 종료는 Galaxy S23 Ultra의 18개 3-stock 매치 및 10분 60 FPS/p95 16.7ms 증적과 독립 QA가 없어 아직 미완료다. 정식 `SCR_06`–`SCR_08` 선택 UI, 성장, 경제, 복수 장신구, 태그 시너지와 온라인은 여전히 미구현이다.
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
