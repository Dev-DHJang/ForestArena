extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	var catalog: LoadoutCatalog = load("res://assets/loadouts/default_loadout_catalog.tres")
	var rules: CombatRules = load("res://assets/combat/phase1_combat_rules.tres")
	for item: Array in [[&"ja-hyun", &"ja-hyun-bulwark-prototype"], [&"ja-hyun", &"ja-hyun-ribbon-counter-prototype"], [&"myo-ryung", &"myo-ryung-sky-dancer-prototype"], [&"myo-ryung", &"myo-ryung-gale-diver-prototype"], [&"nabi", &"nabi-rushclaw-prototype"], [&"nabi", &"nabi-iron-pounce-prototype"]]:
		var selection := LoadoutSelection.new()
		selection.character_id = item[0]
		selection.job_id = item[1]
		var result := LoadoutBuilder.build(selection, catalog, rules.combat_tuning)
		_check(result.succeeded() and result.profile.job_chain_ids.size() == 2, "leaf did not build a two-stage chain: %s" % item[1])
	var old := JobData.new()
	old.schema_version = 4
	old.job_id = &"old"
	_check(not old.is_valid_definition(), "JobData v3 accepted")
	if failures.is_empty(): print("PHASE5_JOB_GROWTH: PASS")
	else: for failure: String in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _check(value: bool, message: String) -> void:
	if not value: failures.append(message)
