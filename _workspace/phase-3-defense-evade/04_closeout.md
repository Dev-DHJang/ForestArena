# Closeout — blocked

- 구현: CombatRules v2, guard/guard break, ground/air evade, 기존 dash 입력의 ACTION 의미, snapshot HUD 및 fixed-tick 회귀를 완료했다.
- 보존: CharacterData, MoveSetData, AttackData ID, 승인 PNG·SpriteFrames·manifest, 정식 선택 UI와 저장은 변경하지 않았다.
- 검증: 전체 자동 검사, 리소스 검사, APK export/계약 검사와 `emulator-5554` 수동 생명주기 검증은 PASS다.
- 차단: Galaxy S23 Ultra 실제 기기가 현재 ADB에 연결되지 않아 필수 실제 기기 검증이 미실행이다. 기기 연결 후 `02_mobile.md`의 절차를 실행하고 QA r02를 기록한다.
- 통합: 실제 기기 QA가 pass가 되기 전에는 feature push/PR/merge를 수행하지 않는다.
- 원래 작업 트리 보존: README, 운영 색인, project.godot, Android 무선 디버깅 문서·스크립트의 사용자 변경은 이 격리 worktree에서 수정·스테이징하지 않았다.
