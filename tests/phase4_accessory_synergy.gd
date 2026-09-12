extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	var catalog: LoadoutCatalog = load("res://assets/loadouts/default_loadout_catalog.tres")
	var rules: CombatRules = load("res://assets/combat/phase1_combat_rules.tres")
	_test_effect(catalog, rules, &"ja-hyun", &"ja-hyun-guard-prototype", &"bark-guard-charm", &"bark-guard-specialist")
	_test_effect(catalog, rules, &"myo-ryung", &"myo-ryung-aerial-prototype", &"sky-current-charm", &"sky-aerial-specialist")
	_test_effect(catalog, rules, &"nabi", &"nabi-close-pressure-prototype", &"pouncing-thorn-charm", &"pouncing-close-pressure")
	var missed := LoadoutSelection.new()
	missed.character_id = &"ja-hyun"
	missed.accessory_id = &"sky-current-charm"
	var missed_result := LoadoutBuilder.build(missed, catalog, rules.combat_tuning)
	_check(missed_result.succeeded() and missed_result.profile.active_accessory_effect_ids.is_empty(), "unmatched accessory should be inactive")
	var old := AccessoryData.new()
	old.schema_version = 1
	old.accessory_id = &"old"
	_check(not old.is_valid_definition(), "AccessoryData v1 was accepted")
	if failures.is_empty():
		print("PHASE4_ACCESSORY_SYNERGY: PASS")
		quit(0)
	else:
		for failure: String in failures: push_error(failure)
		quit(1)


func _test_effect(catalog: LoadoutCatalog, rules: CombatRules, character_id: StringName, job_id: StringName, accessory_id: StringName, effect_id: StringName) -> void:
	var selection := LoadoutSelection.new()
	selection.character_id = character_id
	selection.job_id = job_id
	selection.accessory_id = accessory_id
	var result := LoadoutBuilder.build(selection, catalog, rules.combat_tuning)
	_check(result.succeeded() and result.profile.active_accessory_effect_ids.has(effect_id), "accessory effect failed: %s" % accessory_id)
	if accessory_id == &"pouncing-thorn-charm" and result.succeeded():
		var patched := result.profile.move_set.attacks().filter(func(a: AttackData) -> bool: return a.attack_id == &"nabi-dash-light-pouncing-thorn")
		_check(patched.size() == 1, "thorn patch was not applied")


func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
