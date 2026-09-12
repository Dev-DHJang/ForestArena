extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	var catalog: LoadoutCatalog = load("res://assets/loadouts/default_loadout_catalog.tres")
	_check(catalog != null and catalog.is_valid_definition(), "catalog must be versioned and unique")
	var fixture: LoadoutSelection = load("res://assets/loadouts/fixture_ja_hyun_selection.tres")
	var base: LoadoutSelection = load("res://assets/loadouts/default_ja_hyun_selection.tres")
	var character: CharacterData = catalog.character_by_id(&"ja-hyun")
	_check(character != null and character.schema_version == 2 and character.base_move_set != null, "CharacterData v2 owns a MoveSetData")
	_check(character.base_move_set.attacks().size() >= 14, "Ja-Hyun external moveset preserves all Phase 1 attacks")
	var base_result := LoadoutBuilder.build(base, catalog)
	_check(base_result.succeeded(), "character-only selection builds")
	var result := LoadoutBuilder.build(fixture, catalog)
	_check(result.succeeded(), "fixture selection builds")
	if result.succeeded():
		_check(result.profile.stats.ground_speed == character.base_stats.ground_speed + 12.0, "job applies after character")
		_check(result.profile.stats.survivability == character.base_stats.survivability + 3.0, "accessory applies after job")
		_check(result.profile.move_set.attacks()[0].attack_id == &"ja-hyun-light-01-prototype", "accessory slot patch replaces external moveset slot")
		_check(character.base_stats.ground_speed == 300.0 and character.base_move_set.attacks()[0].attack_id == &"ja-hyun-light-01", "source resources remain unchanged")
	_test_parent_order_and_conflicts(character)
	_test_failures(catalog)
	if failures.is_empty():
		print("Phase 2 loadout contract passed.")
		quit(0)
	else:
		for failure: String in failures: push_error(failure)
		quit(1)


func _test_parent_order_and_conflicts(character: CharacterData) -> void:
	var root := JobData.new()
	root.job_id = &"test-root"
	root.stat_modifiers = [_modifier(StatModifier.Field.GROUND_SPEED, 10.0)]
	var leaf := JobData.new()
	leaf.job_id = &"test-leaf"
	leaf.parent_job_id = root.job_id
	leaf.stage = 2
	leaf.stat_modifiers = [_modifier(StatModifier.Field.GROUND_SPEED, 5.0)]
	var synthetic := LoadoutCatalog.new()
	synthetic.schema_version = 2
	synthetic.characters = [character]
	synthetic.jobs = [root, leaf]
	var selected := LoadoutSelection.new()
	selected.character_id = character.character_id
	selected.job_id = leaf.job_id
	var original_jobs := character.job_tree_ids
	character.job_tree_ids = [root.job_id]
	var result := LoadoutBuilder.build(selected, synthetic)
	character.job_tree_ids = original_jobs
	_check(result.succeeded() and result.profile.stats.ground_speed == character.base_stats.ground_speed + 15.0, "root-to-leaf modifiers are ordered")
	var conflict := JobData.new()
	conflict.job_id = &"test-conflict"
	conflict.stat_modifiers = [_modifier(StatModifier.Field.GROUND_SPEED, 1.0), _modifier(StatModifier.Field.GROUND_SPEED, 2.0)]
	synthetic.jobs = [conflict]
	selected.job_id = conflict.job_id
	character.job_tree_ids = [conflict.job_id]
	result = LoadoutBuilder.build(selected, synthetic)
	character.job_tree_ids = original_jobs
	_check(not result.succeeded() and result.error_codes.has(LoadoutBuildResult.ERR_INVALID_CATALOG), "same-resource writes fail atomically")


func _test_failures(catalog: LoadoutCatalog) -> void:
	var missing := LoadoutSelection.new()
	missing.character_id = &"missing"
	var result := LoadoutBuilder.build(missing, catalog)
	_check(not result.succeeded() and result.profile == null and result.error_codes.has(LoadoutBuildResult.ERR_MISSING_CHARACTER), "missing IDs have no fallback")
	var old := LoadoutSelection.new()
	old.schema_version = 0
	old.character_id = &"ja-hyun"
	result = LoadoutBuilder.build(old, catalog)
	_check(not result.succeeded() and result.profile == null and result.error_codes.has(LoadoutBuildResult.ERR_INVALID_SELECTION), "unsupported selection schema fails atomically")
	var duplicate := LoadoutCatalog.new()
	duplicate.characters = [catalog.characters[0], catalog.characters[0]]
	result = LoadoutBuilder.build(load("res://assets/loadouts/default_ja_hyun_selection.tres"), duplicate)
	_check(not result.succeeded() and result.error_codes.has(LoadoutBuildResult.ERR_INVALID_CATALOG), "duplicate catalog IDs are rejected")


func _modifier(field: StatModifier.Field, value: float) -> StatModifier:
	var modifier := StatModifier.new()
	modifier.field = field
	modifier.value = value
	return modifier


func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
