# 전투 인수인계 R2

- 여섯 stage 2 leaf에 계획된 stat/tuning modifier, 여섯 고유 passive와 여섯 cancel rule을 등록했다.
- 보루 `ja-hyun-heavy-side`, 게일 다이버 `myo-ryung-air-heavy`, 아이언 파운스 `nabi-heavy-side`만 원본을 복제한 비피니시 patch다. 아이언 파운스의 나머지 강공격은 가드 피해만 ×1.25이며 피니시를 유지한다.
- passive trigger/consume filter는 분리됐고 activation serial로 다단 중복 발동을 막는다. match reset, stock 상실, sudden death에서 cooldown과 pending 효과를 제거한다.
- cancel은 원 공격 activation context를 고정한다. `jump`와 `dash`는 공격 lookup을 거치지 않는 명시적 목표 경로로 실제 발동한다.
- 공용 전투 코드에는 character/job ID 분기가 없다.
