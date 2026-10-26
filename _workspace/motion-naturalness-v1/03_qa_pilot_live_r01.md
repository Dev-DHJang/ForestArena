# 대표 모션 실제 경기 캡처 검토 r01

담당: pilot_qa. 2026-10-22. 대상은 `review/live-pilot-r01`의 진행 중 생성 PNG다. 완료된 120tick 달리기·점프를 읽어 각 tick의 플레이어 영역을 변형 없이 잘라 순서 비교판으로 만들었다. 원본 PNG와 전투·표현 코드는 수정하지 않았다.

## 결과: fix — 달리기 캡처가 중간 정지

자현 `run-stop`은 tick 29 부근에서 RUN/그림13(화면은 1부터 센 번호)이 고정된 뒤 tick 119까지 진행하지 않는다. tick72에 이동 해제가 예정돼 있으나 tick90·119에서도 RUN이 남는다. 배경과 상대 위치도 멈췄다. `qa/live-pilot-r01.log`의 `FOREST_ARENA_INPUT_RESET reason=pause`와 맞는다. 담당 root가 OS 포커스 상실에 따른 캡처 pause로 확인했고 새 회차를 준비한다. 이 자료로 반복·발 미끄러짐·정지 전환을 통과시키지 않는다.

확인 자료는 `qa/ja-hyun-run-stop-actual-allticks-r01.jpg`다. 원본 tick29·90·119의 전체 화면과 캡처 코드의12tick press/72tick release를 대조했다. 움직임이 없는 원인을 원화 불량으로 판정하지도 않았다.

## 점프 참고 관찰

같은 회차 자현 jump-land 120tick은 tick12 점프 시작, tick57 접지, tick61 압축, tick73 idle 복귀가 순서대로 보인다. 공중 끝에서 셀 이웃 조각이나 발 잘림은 보이지 않는다. `qa/ja-hyun-jump-land-actual-allticks-r01.jpg`에 전체120tick, `qa/ja-jump-transition-independent.jpg`에 전환 tick11/12·56/57·60/61·72/73을 남겼다. 다만 회차 전체가 캡처 실패이므로 최종 정상/느린 경기 재생 통과 증거로 재사용하지 않는다.

## 추가 확인

고정 catalog/timeline을 이용해 `review/independent-pilot-r01`에 별도 prepare 자료를 만들고 localhost18141에서 정상/0.25배 표현 타이밍 재생이 작동하는 것을 확인했다. 이 타임라인은 시험용 상태를 순서대로 재생하는 자료이며 실제 경기 캡처 실패를 대신하지 않는다. 새 실제 경기와 반전·소형 캡처를 받은 뒤 전체 세트를 새 회차로 판단한다.
