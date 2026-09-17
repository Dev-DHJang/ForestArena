# 04. 기술 아키텍처

이 문서는 코드의 책임을 나누는 기준이다. 대문자 `Resource`는 일반 파일이 아니라 Godot의 데이터 객체를 뜻한다. 나머지 고유 이름은 [용어 가이드](../GLOSSARY.md#godot와-데이터-용어)에서 한 줄 설명을 확인할 수 있다.

## 기본 원칙

- Godot 4.x와 typed GDScript를 사용한다.
- 설정값은 Godot `Resource`에 저장하고, 실제 동작은 역할이 작은 컨트롤러 코드로 나눈다.
- 화면에 보이는 이름 대신 `StringName` 형식의 고유 ID를 저장용 식별자로 사용한다.
- 시작 상태와 입력, 고정 계산 단위(tick)가 같으면 전투 결과도 항상 같아야 한다.
- 원본 `Resource`는 경기 중 바꾸지 않는다. 캐릭터·직업·장신구를 복사해 한 판용 전투 데이터로 합친다.

## 데이터 계약

| Resource | 최소 책임 |
| --- | --- |
| CharacterData | ID, 기본 능력치·기술·패시브·태그·직업 트리와 시각 참조 |
| CharacterStats | 생존, 무게, 이동, 점프, 중력과 대시 값 |
| AttackData | 실제 결과를 정하는 준비·적중·회복 시간, 피해, 밀어내기, 공격 영역과 다시 맞힐 수 있는 조건 |
| MoveSetData | 기술 목록, 의미 입력·방향·지상/공중 조건, 연계 분기와 시각 상태 ID 참조 |
| JobData | 부모·단계, 능력치·기술·패시브·태그와 전투 규칙 변경 |
| AccessoryData | 기본 변경, 기술 패치, 조건 효과와 태그 시너지 |
| StageData | 경기장 ID, 발판, 시작·복귀 위치, 링아웃 영역과 배경 참조 |

캐릭터 데이터의 최종 원본은 `assets/character/<character-id>/character.tres`의 `CharacterData`다. 이 파일에는 콘셉트 이미지, 설정, 역할, 분류 태그, 기술, 항상 적용되는 효과, 직업 확장 자리와 기본 능력치가 들어간다. PNG와 애니메이션은 별도 파일로 두고 `CharacterData`가 가리킨다. 보이는 이미지가 공격 적중 시간이나 승패를 정하지는 않는다.

`docs/contracts/character-appearance-v01.json`은 승인된 캐릭터의 외형과 작은 화면에서 구분하는 방법을 정하는 최종 원본이다. `character_id`와 `concept_asset_id`로 `CharacterData` 및 자산 목록(manifest)의 승인 콘셉트를 연결한다. 이 때문에 Godot 데이터나 자산 목록의 파일 형식을 늘리지는 않는다. 외형 정보는 그림과 애니메이션을 만드는 코드만 읽으며 전투 데이터에는 복사하지 않는다.

게임은 `CharacterData → JobData → AccessoryData` 순서로 값을 합쳐 한 판용 복사본인 `RuntimeCombatProfile`을 만든다. 어떤 값이 겹칠 때 무엇을 우선할지와 잘못된 데이터 처리 방식은 Phase 2 데이터 규칙에 정해져 있다.

`docs/contracts/attack-system-v01.json`은 구현 전 공격 설계를 프로그램으로 검사할 수 있게 적은 원본이다. 게임이 이 JSON을 직접 읽지는 않는다. 실제 게임 데이터는 버전이 있는 `MoveSetData`와 `AttackData`로 나뉜다. 공통 전투 명령인 `CombatIntent`는 행동 ID, 4방향, 버튼의 누름·유지·해제와 지상·공중 여부를 담는다. 다음 입력을 미리 받는 규칙, 동작을 바꿀 수 있는 시간, 피해와 공격 영역은 실제 전투 데이터와 코드가 정하며 이 설계 JSON이나 화면 연결 코드(`VisualAdapter`)가 정하지 않는다.

## 실행 중 2D 구성과 책임

- 파이터 루트 후보는 CharacterBody2D다.
- 맞을 수 있는 영역(Hurtbox)과 공격 영역(Hitbox)은 `Area2D`와 `CollisionShape2D`로 만들고 캐릭터 이미지와 분리한다.
- 경기장 플랫폼은 StaticBody2D와 CollisionShape2D, 링아웃은 Area2D로 구성한다.
- `Camera2D`와 HUD는 전투 코드가 계산한 결과를 읽어 보여 줄 뿐 결과를 계산하지 않는다.
- `AnimatedSprite2D`와 `SpriteFrames`는 움직임을 보여 줄 뿐 공격이 맞는 시간을 정하지 않는다.

## 책임 분리

| 구성 요소 | 책임 |
| --- | --- |
| CombatCommandSource | 터치·AI·디버그 입력을 같은 의미 명령으로 변환 |
| MovementController | X/Y 이동, 점프, 중력과 대시 |
| FighterStateMachine | 전이, 행동 잠금과 취소 |
| AttackController | `AttackData` 단계 진행과 실제 공격 영역 제어 |
| ComboController | 1개 입력 예약, 연계 분기·종료, 공중 행동 한도와 기술별 취소 조건 |
| HitResolver | 적중 중복·자가 타격 방지와 결과 전달 |
| CombatMath | 피해·경직·넉백 공식의 단일 위치 |
| LoadoutBuilder | 소스 비변경 런타임 프로필 생성 |
| VisualAdapter | 의미 상태·이벤트를 애니메이션과 VFX로 표현 |

## 미래 온라인 경계

온라인 통신 규칙, 어느 기기가 최종 결과를 정할지, 재접속과 저장 형식은 Phase 7 이전에 확정하지 않는다. 그전에는 같은 입력이 같은 결과를 내고, 터치·AI·네트워크 입력을 같은 전투 명령으로 바꿔 끼울 수 있게만 유지한다.

## 개발계 데이터베이스

개발계 PostgreSQL은 실행·마이그레이션·백업 도구만 준비한다. 게임 코드가 직접 연결하지 않으며, CharacterData 같은 전투 Resource와 한 판용 `RuntimeCombatProfile`의 원본도 바꾸지 않는다. 플레이어 저장, 성장, 재화, 계정과 온라인 데이터 형식은 해당 Phase와 제품 승인이 생긴 뒤에 별도 계약으로 정한다.

개발계·검증계·운영계는 서로 다른 PostgreSQL 인스턴스와 계정을 사용한다. 현재 개발계 실행 방법과 삭제 보호 규칙은 [개발계 데이터베이스](database.md)를 기준으로 한다.
