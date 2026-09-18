# 전투 검토

현재 `scenes/main.tscn`은 자현 대 묘령의 고정 편성이며, 나비·유란을 같은 실행 화면에서 직접 선택하는 정식 UI는 범위 밖이다. 네 캐릭터의 동일 데이터 조건 비교는 `tests/phase3_style_comparison.gd`가 보장한다.

활성 `docs/gameplay/combat.md`에 남아 있던 잡기·던지기·누적 피해율 전제는 제거하고, HP·stock·무게 기반 넉백과 네 캐릭터의 실제 MoveSet 차이로 갱신했다.

`scenes/debug/phase3_style_playtest.tscn`은 정식 선택 UI와 별개인 개발 전용 장면이다. 아래 명령으로 한 캐릭터를 같은 경기장과 규칙, 같은 스타일의 정지한 상대와 비교할 수 있다.

```sh
godot --path . scenes/debug/phase3_style_playtest.tscn -- --style=ja-hyun
```

`ja-hyun`, `myo-ryung`, `nabi`, `yu-ran`을 각각 넣어 실행한다. 각 실행에서 이동·점프·약/강/특·회피·궁극기와 HP/stock 복귀를 확인하고, 채택·폐기 이유는 사람의 직접 조작 뒤에만 기록한다.

상대도 같은 스타일의 데이터 복사본을 사용하지만 `playtest-rival`이라는 개발용 식별자를 받는다. 따라서 동일 캐릭터 비교에서도 자가 타격이나 같은 ID 충돌 없이 MatchController의 두 파이터 경계를 유지한다.
