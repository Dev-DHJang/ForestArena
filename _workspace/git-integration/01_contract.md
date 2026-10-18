# 기존 데이터와 승인 자산 통합 규칙

공개 API·저장·네트워크 형식·ID를 추가하거나 변경하지 않는다. 최신 develop의 타이틀 시작 장면과 메뉴 코드를 유지한다. assets/character/manifest.json의 묘령31·나비29·유란30 항목과 PNG만 2026-10-17 승인본으로 교체한다. 나비의 기존 별칭 PNG2개도 같은 승인 픽셀을 사용한다. 나머지34개 manifest 항목은 develop과 같다.

표시 크기 데이터 character_display_layout_v01.json의 기존 형식과 ID는 유지한다. 새90개 그림에는 승인된 presentation_scale 1.0·foot_pivot_y 124와 해당 PNG 해시를 기록한다. 이전 그림을 측정한 수치는 새 그림의 측정값으로 재사용하지 않는다. 자현30개 표시 데이터는 그대로 둔다. 이는 시각 표시 변경이며 전투 판정·충돌·SpriteFrames·FPS·저장에는 영향을 주지 않는다.

원본 폴더의 과거 누적 설치 검사 install_approved_yu_ran.py --check는 통과했다. 이번 통합본은 최신 develop의 전투·표시 코드를 유지하므로 과거 보호 코드 해시 검사와 구분한다. verify_integration.py는 별도 로컬 중간 이미지나 백업 없이 Git의 승인 기록·최종 검토 시트에서1440개 셀의 원본 픽셀 일치와120개 시트 연결을 확인한다.
