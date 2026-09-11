# 구현 — 방어·회피

- FighterController 상태: `GUARD`, `GUARD_BREAK`, `EVADE_GROUND`, `EVADE_AIR`.
- MatchController는 dash hold intent를 fixed tick으로 전달하고, 가드 중 적중을 피해·넉백 대신 내구 소모로 해결한다.
- 기본 LoadoutBuilder 경로로 자현·묘령·나비 모두의 무패치 RuntimeCombatProfile을 확인한다.
