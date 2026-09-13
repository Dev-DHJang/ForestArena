extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	var participants: Array[Dictionary] = [
		{"slot": &"player", "character_id": &"ja-hyun", "job_id": &"ja-hyun-bulwark-prototype", "job_chain_ids": [&"ja-hyun-guard-prototype", &"ja-hyun-bulwark-prototype"], "accessory_id": &"bark-guard-charm", "active_accessory_effect_ids": [&"bark-guard-specialist"]},
		{"slot": &"dummy", "character_id": &"nabi", "job_chain_ids": [], "bot_profile_id": &"close"},
	]
	var first := _record_sequence(participants)
	var second := _record_sequence(participants)
	_check(first.aggregates == second.aggregates, "telemetry aggregates are not deterministic")
	_check(int(first.schema_version) == 2, "telemetry schema is not v2")
	var metadata: Dictionary = first.match.participants[0]
	_check(metadata.job_chain_ids.size() == 2 and metadata.accessory_id == "bark-guard-charm" and metadata.active_accessory_effect_ids == [&"bark-guard-specialist"], "loadout metadata was not retained")
	_check(first.aggregates.passive_events[0].tick == 17 and first.aggregates.cancel_events[0].reason == "no_matching_rule", "passive/cancel event fields changed")
	if failures.is_empty(): print("PHASE5_TELEMETRY: PASS")
	else: for failure: String in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _record_sequence(participants: Array[Dictionary]) -> Dictionary:
	var telemetry := Phase3PlaytestTelemetry.new()
	_check(telemetry.begin_match(&"phase5-r2-test", 9125, participants), "telemetry match did not start")
	telemetry.record_action(&"attack_heavy")
	telemetry.record_passive_event(&"ja-hyun", &"bulwark-next-heavy", &"activated", 120, 17)
	telemetry.record_passive_event(&"ja-hyun", &"bulwark-next-heavy", &"consumed", 0, 20)
	telemetry.record_cancel_event(&"ja-hyun", &"", &"rejected", &"no_matching_rule", 23)
	return telemetry.aggregate_snapshot()


func _check(value: bool, message: String) -> void:
	if not value: failures.append(message)
