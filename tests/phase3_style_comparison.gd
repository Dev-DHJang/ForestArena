extends SceneTree

## Reproducible Phase 3 comparison evidence. This validates authored combat
## differences, not subjective play feel or an Android device run.

const CATALOG_PATH := "res://assets/loadouts/default_loadout_catalog.tres"

var failures: PackedStringArray = []


func _initialize() -> void:
	var catalog := load(CATALOG_PATH) as LoadoutCatalog
	_check(catalog != null and catalog.is_valid_definition(), "the comparison catalog is valid")
	if catalog != null:
		_check(catalog.characters.size() == 4, "four comparison characters are registered")
		var profiles: Dictionary = {}
		for character: CharacterData in catalog.characters:
			var selection := LoadoutSelection.new()
			selection.character_id = character.character_id
			var result := LoadoutBuilder.build(selection, catalog)
			_check(result.succeeded(), "%s builds a runtime profile" % character.character_id)
			if result.succeeded(): profiles[character.character_id] = result.profile
		_validate_stats(profiles)
		_validate_move_sets(profiles)
	_finish()


func _validate_stats(profiles: Dictionary) -> void:
	var ja: RuntimeCombatProfile = profiles.get(&"ja-hyun")
	var myo: RuntimeCombatProfile = profiles.get(&"myo-ryung")
	var nabi: RuntimeCombatProfile = profiles.get(&"nabi")
	var yu: RuntimeCombatProfile = profiles.get(&"yu-ran")
	_check(ja != null and myo != null and nabi != null and yu != null, "all named comparison profiles exist")
	if ja == null or myo == null or nabi == null or yu == null: return
	_check(ja.stats.weight > yu.stats.weight and yu.stats.weight > nabi.stats.weight and nabi.stats.weight > myo.stats.weight, "weight establishes a durable-to-mobile comparison")
	_check(myo.stats.ground_speed > nabi.stats.ground_speed and nabi.stats.ground_speed > yu.stats.ground_speed and yu.stats.ground_speed > ja.stats.ground_speed, "ground speed establishes a mobile-to-balanced comparison")
	_check(myo.stats.air_speed > nabi.stats.air_speed and nabi.stats.air_speed > yu.stats.air_speed and yu.stats.air_speed > ja.stats.air_speed, "air speed establishes an aerial comparison")
	_check(ja.stats.max_hp == 105.0 and myo.stats.max_hp == 95.0 and nabi.stats.max_hp == 100.0 and yu.stats.max_hp == 100.0, "HP comparison uses the approved migrated values")


func _validate_move_sets(profiles: Dictionary) -> void:
	var ja: RuntimeCombatProfile = profiles.get(&"ja-hyun")
	var myo: RuntimeCombatProfile = profiles.get(&"myo-ryung")
	var nabi: RuntimeCombatProfile = profiles.get(&"nabi")
	var yu: RuntimeCombatProfile = profiles.get(&"yu-ran")
	if ja == null or myo == null or nabi == null or yu == null: return
	_check(ja.move_set.combo_count == 3 and myo.move_set.combo_count == 4 and nabi.move_set.combo_count == 2 and yu.move_set.combo_count == 3, "light-combo lengths preserve the 3/4/2/3 comparison")
	var ja_special := _attack(ja.move_set, &"ja-hyun-special-neutral")
	var myo_special := _attack(myo.move_set, &"myo-ryung-special-neutral")
	var nabi_special := _attack(nabi.move_set, &"nabi-special-neutral")
	var yu_special := _attack(yu.move_set, &"yu-ran-special-neutral")
	_check(ja_special != null and ja_special.launch_mode == AttackData.LaunchMode.TOWARD_SOURCE, "Ja-Hyun neutral special is a pull")
	_check(myo_special != null and myo_special.max_hits_per_target == 3 and myo_special.rehit_interval_ticks == 3, "Myo-Ryung neutral special is multi-hit")
	_check(nabi_special != null and nabi_special.max_hits_per_target == 1, "Nabi neutral special remains a single close hit")
	_check(yu_special != null and yu_special.hitbox_size == Vector2(96.0, 64.0), "Yu-Ran neutral special owns the wider space-control hitbox")
	for profile: RuntimeCombatProfile in [ja, myo, nabi, yu]:
		_check(_has_action(profile.move_set, &"ultimate"), "%s has an ultimate slot" % profile.character_id)
		_check(not _has_action(profile.move_set, &"grab"), "%s exposes no grab technique" % profile.character_id)


func _attack(move_set: MoveSetData, attack_id: StringName) -> AttackData:
	for attack: AttackData in move_set.attacks():
		if attack.attack_id == attack_id: return attack
	return null


func _has_action(move_set: MoveSetData, action_id: StringName) -> bool:
	for attack: AttackData in move_set.attacks():
		if attack.action_id == action_id: return true
	return false


func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("PHASE3_STYLE_COMPARISON: PASS")
		quit(0)
		return
	for failure: String in failures: push_error(failure)
	print("PHASE3_STYLE_COMPARISON: FAIL (%d)" % failures.size())
	quit(1)
