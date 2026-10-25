# LAN 실행 도구 r04 독립 QA r03

판정: **PASS — 출력 경계와 실패 결과 집계 범위.** 이전 r02/r03 검토·증거는 그대로 두고 새 회차로 검사했다.

`independent-boundaries-r03.py`의 비소켓 경계21개가 모두 기대대로 동작했다. socket과 subprocess는 가짜 객체로 바꿨으며 실제 포트·서버·인증 프로세스를 사용하지 않았다. 양성 기준, 보고서 누락/실패/잘못된 mode·presentation·고정 catalog, client/server/auth 오류, nonzero 종료, 기존 폴더와 명시/기본 경로의 외부·symlink 이탈, 잘못된 presentation 경로 거부를 확인했다. 임시 기본 `runs` symlink는 제거했고 바깥에 쓰지 않았다. 로그와 결과는 `independent-boundaries-r03.json/.log`다.

기존 r03과의 차이도 직접 `diff`로 확인했다. `OUT`을 선택한 **두 분기의 전체 결과**에 `.resolve()`를 적용한 한 줄뿐이다. client fixture는 바이트 동등하다. 따라서 기본 경로의 symlink 이탈은 범위 검사에서 거부되고, 이미 명시적 절대 출력 경로를 넣은 실제 product-r04의 실행 분기 결과는 동일하다. `delta-r03.json`의 설명과 실제 파일이 일치한다.

실제 소켓 자료는 `../lan-launch-release-product-r04`의 기존 실행을 보존해 사용한다. 그 실행의 natural1581/attack1591/jump1587, 총4759개와 제품 presentation·r10 catalog·source156개 전후 동등·모든 로그 오류 없음은 직전 독립 `lan-launch-release-runner-r03/independent-R04-review-r02.json`에서 확인했다. 이번 변경은 인증/서버/전투/client fixture/제품/후보를 바꾸지 않고, 해당 실제 실행이 쓴 명시적 절대 경로도 같은 값으로 정규화한다. 같은 실제 소켓 검사를 다시 실행하거나 새 실행 통과로 기록하지 않는다.

공격·점프 수신 결과가 연결을 끊는 코드/소켓 관찰과 실제 미술·화면·Android 품질은 구분한다. 새 runner pass가 미술 승인이나 기기 통과를 뜻하지 않는다.
