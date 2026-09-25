# 공용 계약

- LocalPlayCatalog: 실제 CharacterData 4종과 AccessoryData 6종을 상품으로 연결한다. 종류, 콘텐츠 ID, 표시 이름, 설명, 정수 가격 0을 갖는다. 전투 Resource는 변경하지 않는다.
- LocalPlayerStore v1: first_granted, characters, accessories, selected_character, selected_accessory, opponent_character를 user://local_player.json에 저장한다. 구매와 첫 지급은 성공적으로 파일 교체가 끝난 뒤 메모리에 반영한다. .bak 복구와 명시적 오류를 제공하고 구버전을 추정하지 않는다.
- MatchController.bot_source: 선택적인 commands_for_tick(tick,snapshot) 제공자. 기본 null로 기존 개발 장면을 보존한다. 참가자 ID와 캐릭터 ID를 분리해 동일 캐릭터 대전을 지원한다.
- LocalAiApp: 보유 검사 뒤 LoadoutSelection을 조립하고 전투 장면에 전달한다. UI가 HP·승패를 계산하지 않는다. AI 기본 장신구는 없음, 맵은 단일 고정 맵, seed=3001이다.
- 시각은 runtime_profile.character_id와 공격 ID/단계를 읽으며 전투 상태를 변경하지 않는다. 신규 미승인 모션은 런타임에 등록하지 않는다.
