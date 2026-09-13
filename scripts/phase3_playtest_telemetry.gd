class_name Phase3PlaytestTelemetry
extends RefCounted

## Anonymous, aggregate-only Phase 3 playtest telemetry. This service has no
## signals or callbacks into combat authority and performs no network I/O.
const SCHEMA_VERSION := 2
const OUTPUT_DIRECTORY := "user://phase3-playtests"
const OUTPUT_PATH := OUTPUT_DIRECTORY + "/matches.jsonl"

var _active := false
var _record: Dictionary = {}
var last_error := ""


func begin_match(
	scenario_id: StringName,
	seed: int,
	participants: Array[Dictionary],
	physics_ticks_per_second: int = 60,
) -> bool:
	last_error = ""
	if _active or scenario_id.is_empty() or participants.size() != 2 or physics_ticks_per_second <= 0:
		last_error = "invalid_match_metadata"
		return false
	var normalized_participants: Array[Dictionary] = []
	for participant: Dictionary in participants:
		var normalized := _normalize_participant(participant)
		if normalized.is_empty():
			last_error = "invalid_participant_metadata"
			return false
		normalized_participants.append(normalized)
	_record = {
		"schema_version": SCHEMA_VERSION,
		"recorded_at_utc": Time.get_datetime_string_from_system(true),
		"match": {
			"match_id": "phase3-%d-%d" % [Time.get_ticks_usec(), abs(seed)],
			"scenario_id": String(scenario_id),
			"seed": seed,
			"physics_ticks_per_second": physics_ticks_per_second,
			"participants": normalized_participants,
		},
		"aggregates": {
			"action_counts": {},
			"defense": {"guard_attempts": 0, "guard_successes": 0, "evade_attempts": 0, "evade_successes": 0},
			"derived_attacks": {"dash_uses": 0, "dash_hits": 0, "air_uses": 0, "air_hits": 0},
			"special_directions": {},
			"special_cooldown_violations": 0,
			"ultimate": {"gauge_gained": 0.0, "uses": 0, "hits": 0},
			"ring_outs": {},
			"passive_events": [],
			"cancel_events": [],
		},
	}
	_active = true
	return true


func record_action(action_id: StringName) -> void:
	if not _active or action_id.is_empty():
		return
	_increment(_aggregates()["action_counts"], String(action_id))


func record_passive_event(fighter_id: StringName, passive_id: StringName, event_kind: StringName, remaining_ticks: int, tick: int) -> void:
	if _active: _aggregates()["passive_events"].append({"fighter_id": String(fighter_id), "passive_id": String(passive_id), "event": String(event_kind), "remaining_ticks": remaining_ticks, "tick": tick})


func record_cancel_event(fighter_id: StringName, rule_id: StringName, result: StringName, reason: StringName, tick: int) -> void:
	if _active: _aggregates()["cancel_events"].append({"fighter_id": String(fighter_id), "rule_id": String(rule_id), "result": String(result), "reason": String(reason), "tick": tick})


func record_attack_outcome(attack: AttackData, hit: bool) -> void:
	if not _active or attack == null:
		return
	var derived: Dictionary = _aggregates()["derived_attacks"]
	if attack.requires_dash:
		derived["dash_uses"] = int(derived["dash_uses"]) + 1
		if hit: derived["dash_hits"] = int(derived["dash_hits"]) + 1
	if attack.activation_context == AttackData.ActivationContext.AIR:
		derived["air_uses"] = int(derived["air_uses"]) + 1
		if hit: derived["air_hits"] = int(derived["air_hits"]) + 1
	if attack.action_id == &"attack_special":
		_increment(_aggregates()["special_directions"], str(attack.input_direction))


func record_guard(success: bool) -> void:
	if not _active:
		return
	var defense: Dictionary = _aggregates()["defense"]
	if success:
		defense["guard_successes"] = int(defense["guard_successes"]) + 1
	else:
		defense["guard_attempts"] = int(defense["guard_attempts"]) + 1


func record_evade(success: bool) -> void:
	if not _active:
		return
	var defense: Dictionary = _aggregates()["defense"]
	if success:
		defense["evade_successes"] = int(defense["evade_successes"]) + 1
	else:
		defense["evade_attempts"] = int(defense["evade_attempts"]) + 1


func record_special_cooldown_violation() -> void:
	if _active:
		_aggregates()["special_cooldown_violations"] = int(_aggregates()["special_cooldown_violations"]) + 1


func record_ultimate_gauge_gain(amount: float) -> void:
	if not _active or amount <= 0.0:
		return
	var ultimate: Dictionary = _aggregates()["ultimate"]
	ultimate["gauge_gained"] = snappedf(float(ultimate["gauge_gained"]) + amount, 0.001)


func record_ultimate_use() -> void:
	if not _active:
		return
	var ultimate: Dictionary = _aggregates()["ultimate"]
	ultimate["uses"] = int(ultimate["uses"]) + 1


func record_ultimate_hit() -> void:
	if _active:
		var ultimate: Dictionary = _aggregates()["ultimate"]
		ultimate["hits"] = int(ultimate["hits"]) + 1


func record_ring_out(fighter_id: StringName) -> void:
	if not _active or fighter_id.is_empty():
		return
	_increment(_aggregates()["ring_outs"], String(fighter_id))


func finish_match(winner_id: StringName, duration_ticks: int, final_snapshot_hash: String = "") -> bool:
	last_error = ""
	if not _active or duration_ticks < 0:
		last_error = "no_valid_active_match"
		return false
	var tick_rate := int(_record["match"]["physics_ticks_per_second"])
	_record["result"] = {
		"winner_id": String(winner_id),
		"duration_ticks": duration_ticks,
		"duration_seconds": snappedf(float(duration_ticks) / float(tick_rate), 0.001),
		"final_snapshot_hash": final_snapshot_hash,
	}
	var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIRECTORY))
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		last_error = "create_output_directory_failed:%d" % directory_error
		return false
	var file := FileAccess.open(OUTPUT_PATH, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file == null:
		last_error = "open_output_failed:%d" % FileAccess.get_open_error()
		return false
	file.seek_end()
	file.store_line(JSON.stringify(_record, "", true))
	file.flush()
	_active = false
	_record = {}
	return true


func cancel_match() -> void:
	_active = false
	_record = {}
	last_error = ""


func is_match_active() -> bool:
	return _active


func aggregate_snapshot() -> Dictionary:
	return _record.duplicate(true) if _active else {}


func _normalize_participant(participant: Dictionary) -> Dictionary:
	var slot := StringName(participant.get("slot", ""))
	var character_id := StringName(participant.get("character_id", ""))
	if slot.is_empty() or character_id.is_empty():
		return {}
	return {
		"slot": String(slot),
		"character_id": String(character_id),
		"job_id": String(participant.get("job_id", "")),
		"job_chain_ids": participant.get("job_chain_ids", []),
		"accessory_id": String(participant.get("accessory_id", "")),
		"active_accessory_effect_ids": participant.get("active_accessory_effect_ids", []),
		"bot_profile_id": String(participant.get("bot_profile_id", "")),
	}


func _aggregates() -> Dictionary:
	return _record["aggregates"]


func _increment(counts: Dictionary, key: String) -> void:
	counts[key] = int(counts.get(key, 0)) + 1
