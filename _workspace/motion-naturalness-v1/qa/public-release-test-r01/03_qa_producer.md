# 공용 표시 연결 테스트 실행

`godot --headless --path . --script res://tests/launch_release_presentation.gd` 실행 결과 `LAUNCH_RELEASE_PRESENTATION: PASS (680 checks)`, exit0, ERROR 없음. 로그는 `godot-r01.log`, 소스 확인값은 `source-hashes-r01.json`이다. verify.sh의 셸 문법도 `sh -n`으로 확인했다. 전체 verify는 root가 진행하므로 중복 실행하지 않았다.

공용 테스트는 public presentation/helper만 불러오며 기존 승인 manifest의 자현 launch와 실제 SpriteFrames를 사용한다. 별도 원화나 프레임 리소스를 만들지 않는다. 한 표현 객체의 메모리 복사에만[12,16)/4틱을 추가하고, 비교 기준 객체에는 두 필드가 없다. JSON 재로딩의 정수값float 호환도 user://PID 파일 저장/읽기/삭제로 확인한다. workspace 코드/원화/목록/JSON 또는 private report 쓰기가 없다.

r04의 정상/반전·30/60/120FPS·끝그림 반복 금지·잘못된 숫자·새 입력 실행·피격 재진입/중복 이벤트·착지/방어/회피/KO/reset·입력/경직/전체snapshot불변 검사를 유지했다. 기존 승인 entry/그림 hash/리소스 재사용과 임시 파일 삭제 확인을 더했다. 이 검사는 프레임 선택/상태 검사이며 미승인 새 연결 그림의 품질이나 실제 LAN/Android 통과를 주장하지 않는다.

제품 GDScript/Python/manifest/후보/목록은 이 한정 작업에서 수정하지 않았다. 지정된18081/17819포트도 사용하지 않았다.
