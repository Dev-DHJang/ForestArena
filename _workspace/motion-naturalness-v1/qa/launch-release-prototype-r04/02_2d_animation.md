# r04 JSON 숫자 수정

`release-clock.gd`의 `integral_number`는 int 또는 float만 허용하고, 유한하며 floor값과 같은 수인지 확인한다. bool·문자열·소수·NaN·Inf는 거부한다. 범위 검사 후에만 begin/end/ticks를 int로 바꾸므로 큰 float를 먼저 int로 좁혀 생길 수 있는 문제도 피한다. [begin,end) 범위,1..12틱과 그림 수 이상 시간 조건은 유지한다.

표현 상태 머신과 원래 동작은 r03과 같으며 JSON 숫자 호환만 고쳤다. `presentation-prototype.gd`는 r04 helper를 가리키는 별도 제품 복사본이다. 실제 JSON 후보 파일의 복사본에 선택 값을 넣고 이 작업 폴더에 저장한 뒤 다시 읽었다. 해당 entry를 실행 중 클론에 연결해 F13 시작과4틱 해제를 확인했다. 원래 r09 파일이나 목록은 수정하지 않았다.

`json-number-fix-r04.patch`는 r03 helper와의 좁은 차이, `integration-review-r04.patch`는 현재 제품 대비 복제 코드의 차이다. 선택 데이터는 제품에 등록하지 않았으며 r04의 저장된 JSON은 시험 자료다.
