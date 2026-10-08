class_name CombatAudio
extends Node
## 기존 전투 장면의 연결을 공통 오디오 관리자로 전달한다.
var suppress_results := false
var local_fighter_id: StringName = &"player"

func play_combat_event(event_id: StringName, payload: Dictionary) -> void:
	if event_id in [&"match_end", &"match_draw"] and not suppress_results:
		ForestArenaAudio.finish_match("draw" if event_id == &"match_draw" else ("victory" if String(payload.get("winner_id", "")) == String(local_fighter_id) else "defeat"))
	else:
		ForestArenaAudio.play_event(event_id, payload)

func apply_accessibility(_settings: Dictionary) -> void:
	pass # 시각 효과와 소리 설정은 서로 독립적이다.
