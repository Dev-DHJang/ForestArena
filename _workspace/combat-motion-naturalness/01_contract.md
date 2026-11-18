# 데이터와 표시 경계

AttackData v4·CombatRules v5·LAN protocol5 형식과 공용 ID를 유지한다. 활성 두 캐릭터 기술의 중간 약공격 회복만12틱으로 바꾸고 예약 종료는 회복 기준11틱으로 맞춘다. 수평 넉백120과 무게 계산은 유지하고 지상 중간타의 위쪽 속도 성분을 없앤다.

지상 피니시 KNOCK_DOWN은 grounded 상태에서 landing_down_ticks와 hitstun_ticks를 rules.landing_down_ticks로 시작한다. 공중 피니시는 착지 다운 예약을 사용한다. 일반 공격의 다운 면역은 simplified_combat에 한정해 기존 기반 전투 계약을 보존한다. 기상 보호는 공격 유효 시작 시 해제한다.

LAN 표시 보간은 FighterController가 snapshot을 적용했음을 알리는 로컬 signal만 추가한다. 서버 메시지·피해·상태·위치·판정 계산은 바꾸지 않는다. 표시 시간은 받은 단계의 마지막 그림에서 멈추며 새 상태를 만들지 않는다. 미수신 타이머를 만들어 전투에 쓰지 않는다.

소비자: FighterController, HitResolver, LocalFighterPresentation, 활성 MoveSet, 전투 JSON·문서·회귀 검사. 원본 Resource는 경기 중 수정하지 않는다.
