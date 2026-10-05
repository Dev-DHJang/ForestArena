# 멀티플레이 상태

`waiting → matched → joining → running → ended`

- 두 guest player가 모이면 고정 slot과 일회용 match ticket을 받는다.
- 두 slot이 join하면 서버가 같은 초기 상태에서 경기를 시작한다.
- 연결 해제는 `running`을 멈추지 않는다. fighter 입력만 해제하고 60초 복귀 창을 연다.
- 정상 승패·무승부·60초 이탈은 모두 단 하나의 최종 결과가 된다.
