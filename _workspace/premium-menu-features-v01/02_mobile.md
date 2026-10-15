# Android 패키지와 검사

- 기존 debug 앱 ID·서명을 유지하며 메뉴 글자는 Godot Control로 표시한다. 전투 입력·그림·터치 영역은 기존 v07 조작 설정을 따른다.
- 현재 `adb devices`에는 물리 Android가 없다. Galaxy S23 Ultra 검사를 실행한 것으로 기록하지 않는다.
- 에뮬레이터 검사는 명시한 emulator serial에서만 실행한다. QA 실행별 폴더에 프로필·DB/LAN 세션·메뉴 기록을 저장하고 일반 저장 파일의 실행 전후 해시를 비교한다.
- 새 메뉴 탐색과 기존 첫 지급·무료 구매·설정 적용·재시작 복원·일시정지 복귀를 실제 ADB 터치로 검사한다. 서버 기능은 별도 격리 DB의 Godot/API 연결 검사와 구분한다.
- APK 생성·패키지·설치·결과·해시는 수행 뒤 04_closeout과 emulator/summary에 연결한다. 미실행 항목은 통과로 처리하지 않는다.
