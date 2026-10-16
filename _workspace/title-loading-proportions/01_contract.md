# 화면·자산 연결 변경

- `application/config/version`에 표시 버전을 둔다. Android `version/name`과 일치하는지 검사한다.
- 시작 장면은 `res://scenes/startup_title.tscn`이다. 기존 `LocalAiApp` 첫 선택·로비·오류·DB 경로는 시작 터치 뒤 이어진다.
- `SCR_01_Splash`에 시작 준비·새 터치·버전·저작권 요구를 추가한다. 기존24개 화면 ID와61개 이미지 슬롯은 유지한다.
- `fa.background.title.forest`는 새 타이틀 배경의 high·medium·low 파일을 연결한다. 기존 승인 Splash 이미지를 덮어쓰지 않는다.
- 원본·변형·해시·생성 프롬프트는 자산 기록에서 관리한다. UI 글자는 Godot 텍스트다.
- 머리 비율 수정은 시안 단계다. 기존 캐릭터 ID·모션 ID·FPS·공격 시간·판정·승인 기록을 바꾸지 않는다.
