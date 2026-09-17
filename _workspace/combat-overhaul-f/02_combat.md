# 전투 구현 기록 — 묶음 F

- 이벤트: 공격 시작·종료, 적중·방어·피격, 다운·기상, 점프·착지, 킬·사망을 RuntimeCombatProfile의 독립 효과 Resource에 전달한다.
- 효과의 `cause_id`와 `max_chain_depth`는 반사·폭발 피해가 무한히 재귀하지 않게 한다.
- 공격 태그는 `MELEE`, `PROJECTILE`, `GRAB`, `MAGIC`, `FIRE`, `SPECIAL`, `ULTIMATE`, `UNBLOCKABLE`만 허용한다.
