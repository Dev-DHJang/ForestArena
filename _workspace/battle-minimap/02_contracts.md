# 저장·LAN 연결 결과

기기 LocalPlayerStore와 API Profile을 v3으로 변경했다. 닉네임과 미니맵 설정을 별도 identity/minimap 명령으로 저장한다. 기기 v1/v2 이전·읽기 전용 DB 이전·실패 시 기존 값 유지와 백업 복구를 검사했다. DB v2는 읽을 때 v3으로 변경하되 변경 번호는 유지하며 이전 요청 기록의 v2 응답도 재시도할 수 있다.

LAN protocol_version 1은 그대로 두고 선택적 nickname, 방 준비·재접속 names만 추가했다. 생략한 이름은 참가자 1/2이며 닉네임의 제어 문자·줄바꿈 검사는 기기·DB와 동일하다. 이름은 전투 snapshot에 넣지 않으며 방 입장 시 확정해 재대전·재접속에도 유지한다.

TypeScript 단위 검사, 실제 PostgreSQL 저장·재실행·SQL 일치 검사 및 두 실제 Godot LAN 클라이언트의 이름·재접속·재대전·양쪽 미니맵 연결 검사를 실행한다. 구체적인 최종 결과는 마무리 기록과 QA 기록을 따른다.
