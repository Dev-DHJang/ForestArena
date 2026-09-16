# 전투 데이터 대조 기록

## 확인한 실제 데이터

- `assets/character/ja-hyun/character.tres`
- `assets/character/myo-ryung/character.tres`
- `assets/character/nabi/character.tres`
- `assets/combat/movesets/ja_hyun_moveset.tres`
- `assets/combat/movesets/myo_ryung_moveset.tres`
- `assets/combat/movesets/nabi_moveset.tres`
- `scripts/fighter_controller.gd`
- `scripts/match_controller.gd`
- `scenes/main.tscn`

## 현재 구현으로 분류한 항목

- 공통 이동, 지상·공중 점프와 대시
- 캐릭터별 2~4단 약공격
- 위·아래 약공격과 세 방향 강공격
- 대시 약·강공격
- 방향을 선택하는 공중 약·강공격
- 캐릭터별 중립 특수기
- 공통 위 특수기와 공중 1회 제한
- 3회 링아웃, 복귀, 복귀 무적과 동시 마지막 링아웃 재승부

## 미구현으로 분류한 항목

- 옆·아래 특수기
- 힘을 모으는 강공격
- 막기, 회피, 잡기와 가드 내구도
- 특수기 재사용 대기시간
- 궁극기와 궁극기 게이지
- 정식 캐릭터 선택 화면

## 캐릭터별 현재 차이

- 자현: 가장 무겁고 가장 느리며, 3단 약공격과 상대를 당기는 중립 특수기를 가진다.
- 묘령: 가장 빠르고 가장 가벼우며, 4단 약공격과 최대 3회 맞는 중립 특수기를 가진다.
- 나비: 이동·무게가 두 캐릭터의 중간이며, 2단 약공격과 한 번 맞는 중립 특수기를 가진다.

## 주의해서 기록한 점

- 현재 모든 공격 영역 크기가 같으므로 콘셉트의 리본·발차기·발톱 거리를 실제 차이로 쓰지 않았다.
- `survivability`는 현재 전투 계산에 사용되지 않으므로 체력이나 생존 보너스로 쓰지 않았다.
- 기본 실행 화면은 자현 입력과 정지한 묘령 훈련 상대만 사용하며 나비는 연결되지 않았다.
- 승인된 애니메이션 파일이 있어도 현재 전투 장면에 `AnimatedSprite2D` 연결이 없으므로 표시 완료로 쓰지 않았다.
