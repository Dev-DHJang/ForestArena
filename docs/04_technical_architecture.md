# 04. 기술 아키텍처

## 기본 원칙

- Godot 4.x와 typed GDScript를 사용한다.
- 데이터는 Resource, 동작은 작은 책임의 컨트롤러로 분리한다.
- 표시 이름 대신 StringName ID를 영속 식별자로 사용한다.
- 같은 초기 상태, 의미 입력과 물리 tick은 같은 전투 결과를 만든다.
- 소스 Resource는 매치 중 직접 수정하지 않고 런타임 프로필을 복제·조합한다.

## 데이터 계약

| Resource | 최소 책임 |
| --- | --- |
| CharacterData | ID, 기본 능력치·기술·패시브·태그·직업 트리와 시각 참조 |
| CharacterStats | 생존, 무게, 이동, 점프, 중력과 대시 값 |
| AttackData | 권위 있는 startup·active·recovery, 피해, 넉백, hitbox, 전달 방식과 재타격 조건 |
| MoveSetData | 기술 목록, 의미 입력·방향·지상/공중 조건, 연계 분기와 시각 상태 ID 참조 |
| JobData | 부모·단계, 능력치·기술·패시브·태그와 전투 규칙 변경 |
| AccessoryData | 기본 변경, 기술 패치, 조건 효과와 태그 시너지 |
| StageData | 경기장 ID, 플랫폼, 스폰, 링아웃 경계와 시각 참조 |

캐릭터 Resource 데이터의 단일 저작 출처는 `assets/character/<character-id>/character.tres`의 CharacterData다. 이 Resource는 콘셉트 이미지 참조·요약, 설정, 역할, 태그, 기술·패시브·직업 확장 슬롯과 기본 CharacterStats를 함께 소유한다. PNG와 이후의 애니메이션은 별도 자산 파일로 두되 CharacterData가 참조하며, 시각 자산은 판정·공격 타이밍·승패의 권위가 아니다.

`docs/character-appearance-v01.json`은 승인 로스터의 외형 경계와 작은 화면 식별 규칙을 소유한다. `character_id`와 `concept_asset_id`로 CharacterData·manifest의 승인 콘셉트와 연결하지만 Resource 또는 manifest 스키마를 확장하지 않는다. 외형 계약은 표현 소비자만 사용하며 전투 JSON과 런타임 프로필에는 복제하지 않는다.

조합 순서는 CharacterData, 누적 JobData, AccessoryData이며 결과는 RuntimeCombatProfile이다. v2는 CombatRules의 불변 CombatTuningData를 복사하고 JobData의 제한된 CombatTuningModifier만 결과 프로필에 적용한다. source Resource는 절대 변경하지 않으며 캐릭터 ID 분기로 전투 수치를 정하지 않는다.

`docs/attack-system-v01.json`은 구현 전 공격 콘셉트의 검사 가능한 원본이다. 런타임은 versioned MoveSetData·AttackData로 분리하며, v2 CombatIntent는 `action_id`, 4방향 `direction`, `press|hold|release` edge, 지상/공중 문맥을 담는다. `MatchController`는 로컬과 결정론 봇 명령 소스를 같은 intent 경로로 소비한다. 입력 예약, 취소 창, 피해와 hitbox는 이 콘셉트 JSON이나 VisualAdapter가 소유하지 않는다.

## 2D 런타임 경계

- 파이터 루트 후보는 CharacterBody2D다.
- Hurtbox와 Hitbox는 Area2D 및 CollisionShape2D로 시각 노드와 분리한다.
- 경기장 플랫폼은 StaticBody2D와 CollisionShape2D, 링아웃은 Area2D로 구성한다.
- Camera2D와 HUD는 전투 상태를 소비하며 결과를 생산하지 않는다.
- AnimatedSprite2D와 SpriteFrames는 시각 상태를 표현할 뿐 공격 활성 구간을 결정하지 않는다.

## 책임 분리

| 구성 요소 | 책임 |
| --- | --- |
| CombatCommandSource | 터치·AI·디버그 입력을 같은 의미 명령으로 변환 |
| MovementController | X/Y 이동, 점프, 중력과 대시 |
| FighterStateMachine | 전이, 행동 잠금과 취소 |
| AttackController | AttackData 단계 진행과 권위 hitbox 제어 |
| ComboController | 1개 입력 예약, 연계 분기·종료, 공중 행동 한도와 기술별 취소 조건 |
| HitResolver | 적중 중복·자가 타격 방지와 결과 전달 |
| CombatMath | 피해·경직·넉백 공식의 단일 위치 |
| LoadoutBuilder | 소스 비변경 런타임 프로필 생성 |
| VisualAdapter | 의미 상태·이벤트를 애니메이션과 VFX로 표현 |

## 미래 온라인 경계

온라인 프로토콜, 권위 모델, 재접속과 저장 형식은 Phase 7 이전에 확정하지 않는다. 그 전에는 전투의 결정론성과 명령 소스 교체 가능성만 보존한다.
