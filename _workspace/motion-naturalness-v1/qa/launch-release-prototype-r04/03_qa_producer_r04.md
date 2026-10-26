# JSON 결함 재현과 제작자 재검사

## 수정 전 실패 재현

`reproduce-r03-json.gd`는 보존된 r03 원본 helper를 직접 불러온다. `reproduce-r03-json.log`에서 같은 값을 메모리 int로 넣으면 accepted=true, JSON 저장 문자열을 다시 읽으면 ticks/index타입=float이고 accepted=false임을 확인했다. 명령의 exit0은 **결함 재현 성공**이며 제품 동작 통과가 아니다. r03의631 PASS는 이 실제 파일 경로 결함을 포함하지 않았고 완료 근거로 충분하지 않았다.

## 수정 후 결과

```sh
godot --headless --path . --script _workspace/motion-naturalness-v1/qa/launch-release-prototype-r04/check-prototype.gd
```

`check-r04.log`: **676검사 PASS, ERROR0**. r03의 상태/프레임 속도/반전/중단/입력/경직 불변 검사를 유지하고, 다음을 추가/수정했다.

- 유한한 정수값float4.0/[12.0,16.0]과int/float혼합, 실제JSON문자열 roundtrip 허용. 결과 begin/end/ticks는int로 정규화.
- bool·문자열·소수4.5/12.5·NaN·Inf·큰finite값·범위 위반은 거부.
- 실제 r09 JSON에서 읽은 candidate row를 복사해 선택 값을 넣고 `roundtrip-entry-r04.json`에 저장/재로딩했다. 로딩된 값이float이며 그림 해시가 실제 PNG와 같음을 확인했다.
- 그 파일의 row를 클론에 넣고 실제 LAN3 방식경직0 LAUNCH F5→FALL을 정상/반전으로 실행했다. F13 연결이 켜지고4표시틱 뒤jump로 돌아왔다. 숫자를int로 직접 넣는 검사만으로 통과시키지 않았다.

`source-hashes-r04.json`: r03 원본/로그 전체 목록의 해시가 그대로이며, 고정r09 인계 파일·현재제품 기준 파일도 동일하다. r04 시험/복제/helper/실제 roundtrip JSON 해시를 포함한다.

이 결과는 제작자 headless 상태/그림번호 시험이다. 실제 LAN 왕복·게임 픽셀·독립 QA·Android 실기기 검사는 완료하지 않았다. 제품과 승인 manifest는 변경하지 않았으며 전체verify는 중복 실행하지 않았다.
