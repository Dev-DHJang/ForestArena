# JSON에서 읽은 정수값 float 허용 수정 r04

r03은 Godot JSON.parse_string이 숫자를 float로 읽는다는 사실을 놓치고 `is int`만 허용했다. 메모리에서 직접 넣은 int 검사631개가 통과해도 실제 파일의 선택 값은 거부되어 연결이 꺼진다. 이 동작을 먼저 재현한 뒤 r04 sibling 시안에서 고친다. r03 원본/로그/해시와 고정r09/제품/manifest는 보존한다.

수정 범위는 workspace helper의 숫자 확인과 실제 JSON 저장/읽기 검사다. 제품 통합과 독립 QA는 root의 후속 단계다.
