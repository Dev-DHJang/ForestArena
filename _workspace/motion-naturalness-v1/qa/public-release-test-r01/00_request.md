# 표시 연결 자동 검사의 제품 테스트 이동

r04 시안 검사를 공용 `scripts/local_fighter_presentation.gd`와 `scripts/launch_release_clock.gd`를 검증하는 `tests/launch_release_presentation.gd`로 옮긴다. 미승인 workspace 원화/JSON/스크립트 의존을 없애고 기존 승인 자현 launch manifest/SpriteFrames를 그대로 사용한다. 선택 값은 실행 중 메모리에서만 넣으며 임시 JSON은 user://의 PID별 파일을 사용한 뒤 삭제한다. 기본 verify.sh에 호출을 추가한다.
