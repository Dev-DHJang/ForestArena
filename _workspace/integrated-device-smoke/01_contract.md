# 통합본 검사와 수정 범위

공개 API·저장 형식·네트워크 형식·캐릭터 승인 자산·전투 판정은 변경하지 않는다.

호스트의 Android 검사 도구가 startup.json과 state.json을 독립적으로 해석한다. Android exec-out의 파일 없음 안내 문자열·부분 JSON은 아직 준비되지 않은 상태로 처리하되, 정상적으로 선택한 상태의 실행 ID·형식 버전 검증과 새 프로세스 구분은 유지한다. 기존 원본 저장 해시는 메뉴4종과 각 .bak까지 확장하고 파일 내용은 읽지 않는다.

실기기에서 추가 확인된 상점 드래그 문제는 비전투 메뉴의 장식 PanelContainer가 입력을 막는 원인으로 좁혔다. _card와 추천 배너의 장식 패널은 mouse_filter PASS, 추천 배너 이미지는 IGNORE로 바꿔 실제 ScrollContainer까지 입력을 전달한다. 구매 버튼·모달의 입력과 동작·장신구/보유·선택 의미는 유지한다. 원본 이미지·리소스 ID·배치·게임 규칙을 바꾸지 않는다.

새 headless 검사는 native PanGesture를 GUI에 전달해 목록의 실제 이동·구매 모달 미표시·보유 불변을 확인한다. headless 환경의 손가락 지원 제한 때문에 ScreenDrag 통과로 주장하지 않는다. 실제 손가락은 새 APK의 Android 검사로 별도 확인한다.
