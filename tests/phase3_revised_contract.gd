extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	var catalog: LoadoutCatalog = load("res://assets/loadouts/default_loadout_catalog.tres")
	_check(catalog != null and catalog.is_valid_definition(), "catalog is invalid")
	var rules: CombatRules = load("res://assets/combat/phase1_combat_rules.tres")
	_check(rules != null and rules.schema_version == 3 and rules.is_valid_definition(), "CombatRules v3 is invalid")
	var old_attack := AttackData.new()
	old_attack.schema_version = 2
	old_attack.attack_id = &"old"
	old_attack.action_id = &"attack_light"
	old_attack.visual_state_id = &"old"
	_check(not old_attack.is_valid_definition(), "AttackData v2 was accepted")
	for character_id: StringName in [&"ja-hyun", &"myo-ryung", &"nabi"]:
		var selection := LoadoutSelection.new()
		selection.character_id = character_id
		var result := LoadoutBuilder.build(selection, catalog, rules.combat_tuning)
		_check(result.succeeded(), "base profile failed: %s" % character_id)
		if not result.succeeded(): continue
		for direction: AttackData.InputDirection in [AttackData.InputDirection.NEUTRAL, AttackData.InputDirection.FORWARD, AttackData.InputDirection.UP, AttackData.InputDirection.DOWN]:
			_check(result.profile.move_set.attacks().filter(func(a: AttackData) -> bool: return a.action_id == &"attack_special" and a.input_direction == direction).size() == 1, "special direction missing: %s/%d" % [character_id, direction])
	var nabi := LoadoutSelection.new()
	nabi.character_id = &"nabi"
	nabi.job_id = &"nabi-close-pressure-prototype"
	var nabi_result := LoadoutBuilder.build(nabi, catalog, rules.combat_tuning)
	_check(nabi_result.succeeded() and nabi_result.profile.tags.has(&"close-pressure-specialist"), "Nabi pressure job failed")
	if failures.is_empty():
		print("PHASE3_REVISED_CONTRACT: PASS")
		quit(0)
	else:
		for failure: String in failures: push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
