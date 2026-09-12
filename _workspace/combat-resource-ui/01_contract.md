# 전투 UI 리소스 계약

## 공개 논리 ID

- `fa.background.combat.training.arena`: 품질별 16:9 전투 배경 플레이스홀더.
- `fa.ui.combat.dpad.default`, `.up`, `.down`, `.left`, `.right`: D-pad 기본·방향 입력 상태.
- `fa.ui.combat.action.default`, `.pressed`: 다섯 행동 버튼이 공유하는 기본·눌림 상태.

## 불변식

- 소비자는 `res://forest_arena/assets/...` 또는 품질 디렉터리를 하드코딩하지 않는다.
- 버튼 문구와 방향 표시는 네이티브 Godot `Label`로 유지한다.
- 플레이스홀더 파일과 논리 ID는 최종 승인 자산 교체 뒤에도 소비자 호환 경계로 유지한다.
- 리소스 누락은 경고와 보이는 누락 ID로 드러내며 투명하게 실패하지 않는다.
