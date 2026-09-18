# 전투 검토

현재 `scenes/main.tscn`은 자현 대 묘령의 고정 편성이며, 나비·유란을 같은 실행 화면에서 직접 선택하는 정식 UI는 범위 밖이다. 네 캐릭터의 동일 데이터 조건 비교는 `tests/phase3_style_comparison.gd`가 보장한다.

활성 `docs/gameplay/combat.md`에 남아 있던 잡기·던지기·누적 피해율 전제는 제거하고, HP·stock·무게 기반 넉백과 네 캐릭터의 실제 MoveSet 차이로 갱신했다.
