extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	_test_ai_and_practice()
	_test_solo_limits()
	_test_team_limits()
	_test_version_and_identity_failures()
	if failures.is_empty():
		print("PHASE6_LOCAL_MODE_CONTRACT: PASS")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func _test_ai_and_practice() -> void:
	var config := _config(LocalMatchConfig.Mode.AI, 2)
	_check(config.is_valid_definition(), "AI mode requires one human and one AI")
	config.mode = LocalMatchConfig.Mode.PRACTICE
	_check(config.is_valid_definition(), "Practice mode accepts a one-player local setup")
	config.participants.append(_participant(&"extra", false))
	_check(not config.is_valid_definition(), "practice accepted a third participant")


func _test_solo_limits() -> void:
	var config := _config(LocalMatchConfig.Mode.SOLO, 8)
	_check(config.is_valid_definition(), "Solo mode must accept eight participants")
	config.participants.append(_participant(&"too-many", false))
	_check(not config.is_valid_definition(), "Solo mode accepted nine participants")


func _test_team_limits() -> void:
	var config := _config(LocalMatchConfig.Mode.TEAM, 8)
	for index: int in config.participants.size():
		config.participants[index].team_id = &"alpha" if index < 4 else &"beta"
	_check(config.is_valid_definition(), "Team mode must accept four vs four")
	config.participants[7].team_id = &"alpha"
	_check(not config.is_valid_definition(), "Team mode accepted five members on one team")
	config.participants[7].team_id = &"beta"
	config.participants[6].team_id = &"gamma"
	_check(not config.is_valid_definition(), "Team mode accepted three teams")


func _test_version_and_identity_failures() -> void:
	var config := _config(LocalMatchConfig.Mode.AI, 2)
	config.schema_version = 1
	_check(not config.is_valid_definition(), "old match config schema was accepted")
	config.schema_version = LocalMatchConfig.SCHEMA_VERSION
	config.participants[1].participant_id = config.participants[0].participant_id
	_check(not config.is_valid_definition(), "duplicate participant ID was accepted")


func _config(mode: LocalMatchConfig.Mode, count: int) -> LocalMatchConfig:
	var config := LocalMatchConfig.new()
	config.mode = mode
	for index: int in count:
		config.participants.append(_participant(&"fighter-%d" % index, index == 0))
	return config


func _participant(id: StringName, human: bool) -> LocalMatchParticipant:
	var participant := LocalMatchParticipant.new()
	participant.participant_id = id
	participant.human_controlled = human
	participant.selection.character_id = &"ja-hyun"
	return participant


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
