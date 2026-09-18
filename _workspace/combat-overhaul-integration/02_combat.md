# 전투 구현

- `attack_special`의 옆·아래 방향을 더 이상 코드에서 거부하지 않고 MoveSet의 `ANY_HORIZONTAL`·`DOWN` 슬롯으로 해석한다.
- `ultimate`은 조건을 만족한 뒤에만 슬롯을 찾고, 슬롯을 찾은 경우에만 게이지와 stock당 사용권을 소비한다.
- 네 MoveSet에 옆 특수·아래 특수·궁극기 슬롯을 이관하는 재실행 가능 저장 도구를 둔다.
