extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_complete_inheritance_chain()
	_test_invalid_job_graphs()
	_test_invalid_job_contracts()
	if failures.is_empty():
		print("PHASE5_JOB_INHERITANCE: PASS")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func _test_complete_inheritance_chain() -> void:
	var authored := load("res://assets/character/ja-hyun/character.tres") as CharacterData
	var character := authored.duplicate(true) as CharacterData
	character.job_tree_ids = [&"phase5-leaf"]
	var source_move_set_id := authored.base_move_set.move_set_id
	var source_attack_id := authored.base_move_set.slots[0].attack.attack_id

	var root := JobData.new()
	root.job_id = &"phase5-root"
	root.stat_modifiers = [_modifier(StatModifier.Field.GROUND_SPEED, StatModifier.Operation.ADD, 10.0)]
	root.replacement_move_set = authored.base_move_set.duplicate(true) as MoveSetData
	root.replacement_move_set.move_set_id = &"phase5-root-moves"
	root.added_passive_ids = [&"phase5-root-passive"]
	root.added_tags = [&"phase5-root-tag"]
	root.combat_rules = [_rule(CombatRuleData.Kind.IMMUNE_KNOCKDOWN)]
	root.combat_effects = [_effect(&"phase5-root-effect")]

	var leaf := JobData.new()
	leaf.job_id = &"phase5-leaf"
	leaf.parent_job_id = root.job_id
	leaf.stat_modifiers = [_modifier(StatModifier.Field.GROUND_SPEED, StatModifier.Operation.MULTIPLY, 2.0)]
	var leaf_attack := root.replacement_move_set.slots[0].attack.duplicate(true) as AttackData
	leaf_attack.attack_id = &"phase5-leaf-light"
	leaf.move_slot_patches = [_patch(root.replacement_move_set.slots[0].slot_id, leaf_attack)]
	leaf.combo_link_overrides = [_link(leaf_attack.attack_id, root.replacement_move_set.slots[1].attack.attack_id)]
	leaf.added_passive_ids = [&"phase5-leaf-passive"]
	leaf.added_tags = [&"phase5-leaf-tag"]
	leaf.combat_rules = [_rule(CombatRuleData.Kind.SUPER_ARMOR)]
	leaf.combat_effects = [_effect(&"phase5-leaf-effect")]

	var accessory := AccessoryData.new()
	accessory.accessory_id = &"phase5-accessory"
	accessory.stat_modifiers = [_modifier(StatModifier.Field.GROUND_SPEED, StatModifier.Operation.OVERRIDE, 777.0)]
	accessory.added_passive_ids = [&"phase5-accessory-passive"]
	accessory.added_tags = [&"phase5-accessory-tag"]
	accessory.combat_rules = [_rule(CombatRuleData.Kind.IMMUNE_HITSTUN)]
	accessory.combat_effects = [_effect(&"phase5-accessory-effect")]

	var catalog := LoadoutCatalog.new()
	catalog.characters = [character]
	catalog.jobs = [root, leaf]
	catalog.accessories = [accessory]
	var selection := LoadoutSelection.new()
	selection.character_id = character.character_id
	selection.job_id = leaf.job_id
	selection.accessory_id = accessory.accessory_id
	var result := LoadoutBuilder.build(selection, catalog)
	_check(result.succeeded(), "complete parent/current/accessory chain did not build")
	if not result.succeeded(): return
	var profile := result.profile
	_check(is_equal_approx(profile.stats.ground_speed, 777.0), "character -> parent -> current -> accessory stat order drifted")
	_check(profile.move_set.move_set_id == root.replacement_move_set.move_set_id, "parent replacement MoveSet was not inherited")
	_check(profile.move_set.slots[0].attack.attack_id == leaf_attack.attack_id, "current job slot patch was not applied after parent replacement")
	_check(profile.move_set.combo_links.size() == 1 and profile.move_set.combo_links[0].from_attack_id == leaf_attack.attack_id, "current job combo override was not applied")
	_check(profile.passive_ids == [&"phase5-root-passive", &"phase5-leaf-passive", &"phase5-accessory-passive"], "passive inheritance order drifted")
	_check(profile.tags.has(&"phase5-root-tag") and profile.tags.has(&"phase5-leaf-tag") and profile.tags.has(&"phase5-accessory-tag"), "tags did not accumulate across all layers")
	_check(profile.combat_rules.size() == 3, "combat rules did not accumulate across all layers")
	_check(profile.combat_effects.size() == 3, "combat effects did not accumulate across all layers")
	_check(authored.base_move_set.move_set_id == source_move_set_id and authored.base_move_set.slots[0].attack.attack_id == source_attack_id, "authored CharacterData was mutated")
	_check(root.replacement_move_set.slots[0].attack.attack_id == source_attack_id, "authored parent job MoveSet was mutated by a child patch")
	_check(leaf.move_slot_patches[0].replacement.attack_id == leaf_attack.attack_id, "authored current job patch was mutated")
	_check(profile.combat_rules[0] != root.combat_rules[0] and profile.combat_effects[0] != root.combat_effects[0], "runtime profile reused authored rule or effect resources")


func _test_invalid_job_graphs() -> void:
	var authored := load("res://assets/character/ja-hyun/character.tres") as CharacterData
	var character := authored.duplicate(true) as CharacterData
	var missing_parent := JobData.new()
	missing_parent.job_id = &"phase5-missing-parent-leaf"
	missing_parent.parent_job_id = &"phase5-absent-parent"
	character.job_tree_ids = [missing_parent.job_id]
	var catalog := LoadoutCatalog.new()
	catalog.characters = [character]
	catalog.jobs = [missing_parent]
	var selection := LoadoutSelection.new()
	selection.character_id = character.character_id
	selection.job_id = missing_parent.job_id
	var result := LoadoutBuilder.build(selection, catalog)
	_check(not result.succeeded() and result.error_codes.has(LoadoutBuildResult.ERR_INVALID_PARENT), "missing job parent was not rejected explicitly")

	var cycle_a := JobData.new()
	cycle_a.job_id = &"phase5-cycle-a"
	cycle_a.parent_job_id = &"phase5-cycle-b"
	var cycle_b := JobData.new()
	cycle_b.job_id = &"phase5-cycle-b"
	cycle_b.parent_job_id = cycle_a.job_id
	character.job_tree_ids = [cycle_a.job_id]
	catalog.jobs = [cycle_a, cycle_b]
	selection.job_id = cycle_a.job_id
	result = LoadoutBuilder.build(selection, catalog)
	_check(not result.succeeded() and result.error_codes.has(LoadoutBuildResult.ERR_JOB_CYCLE), "cyclic job inheritance was not rejected explicitly")


func _test_invalid_job_contracts() -> void:
	var duplicate_passive := JobData.new()
	duplicate_passive.job_id = &"phase5-duplicate-passive"
	duplicate_passive.added_passive_ids = [&"same", &"same"]
	_check(not duplicate_passive.is_valid_definition(), "duplicate passive IDs were accepted")
	var empty_tag := JobData.new()
	empty_tag.job_id = &"phase5-empty-tag"
	empty_tag.added_tags = [&""]
	_check(not empty_tag.is_valid_definition(), "empty job tag was accepted")
	var malformed_link := JobData.new()
	malformed_link.job_id = &"phase5-malformed-link"
	malformed_link.combo_link_overrides = [ComboLinkData.new()]
	_check(not malformed_link.is_valid_definition(), "malformed combo override was accepted")
	var malformed_rule := JobData.new()
	malformed_rule.job_id = &"phase5-malformed-rule"
	var invalid_rule := CombatRuleData.new()
	invalid_rule.kind = CombatRuleData.Kind.IMMUNE_TAG
	malformed_rule.combat_rules = [invalid_rule]
	_check(not malformed_rule.is_valid_definition(), "malformed combat rule was accepted")
	var malformed_effect := JobData.new()
	malformed_effect.job_id = &"phase5-malformed-effect"
	malformed_effect.combat_effects = [CombatEffectData.new()]
	_check(not malformed_effect.is_valid_definition(), "malformed combat effect was accepted")


func _modifier(field: StatModifier.Field, operation: StatModifier.Operation, value: float) -> StatModifier:
	var modifier := StatModifier.new()
	modifier.field = field
	modifier.operation = operation
	modifier.value = value
	return modifier


func _patch(slot_id: StringName, attack: AttackData) -> MoveSlotPatch:
	var patch := MoveSlotPatch.new()
	patch.slot_id = slot_id
	patch.replacement = attack
	return patch


func _link(from_id: StringName, next_id: StringName) -> ComboLinkData:
	var link := ComboLinkData.new()
	link.from_attack_id = from_id
	link.input_action_id = &"light_attack"
	link.next_attack_id = next_id
	link.window_start_tick = 1
	link.window_end_tick = 5
	return link


func _rule(kind: CombatRuleData.Kind) -> CombatRuleData:
	var rule := CombatRuleData.new()
	rule.kind = kind
	return rule


func _effect(cause_id: StringName) -> CombatEffectData:
	var effect := CombatEffectData.new()
	effect.kind = CombatEffectData.Kind.GAIN_ULTIMATE
	effect.trigger = CombatEffectData.Trigger.ON_ATTACK_START
	effect.amount = 1.0
	effect.cause_id = cause_id
	return effect


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
