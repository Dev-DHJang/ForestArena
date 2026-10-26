# LAN 화면 fixture 순서 수정 r03

r02의 첫 실제 실행은 `qa/lan-launch-release-capture-r01/ja-hyun-normal/normal-report.json`에 실패로 보존돼 있다. native pose/transform/received-state 일치224건, 목표 방향 대기1건,4그림누락2건,요청방향불일치8건이 기록됐다. 이 결과를 제품 모션/전투 오류로 판단하지 않는다.

fixture의 SceneTree._process가 LanMatchClient Node._process보다 앞서 sync한 뒤 수신이 프록시 변환을 바꿨다. 또 이동RELEASE와 다음PRESS가 같은서버tick으로묶여목표방향설정이취소됐고초기SPAWNING동안의단발입력도버려질수있었다. 실패자료와r02원본을보존하고새r03에서Node relay와서버tick구간분리만고친다.

소켓/game/server/프로토콜/기술/입력계산은바꾸지않는다. 실제delta, 즉시수신apply, native marker/draw/postdraw 검사를유지한다. root검토전직접GPU/실LAN/포트를실행하지않고check-only까지만확인한다.
