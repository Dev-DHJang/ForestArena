extends SceneTree

const EffectControllerScript := preload("res://scripts/effect_controller.gd")
const EffectData := preload("res://scripts/data/combat_effect_data.gd")
const Presentation := preload("res://scripts/local_fighter_presentation.gd")

var failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_tag_conditions()
	_test_layer_priority_and_conflicts()
	var boxing_profile := _test_complete_move_set_replacement()
	_test_ambiguous_move_sets()
	await _test_presentation_non_authority(boxing_profile)
	if failures.is_empty():
		print("PHASE4_ACCESSORY_VALIDATION: PASS")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func _test_tag_conditions() -> void:
	var owner := FighterController.new()
	var target := FighterController.new()
	owner.runtime_profile = _profile_from_character(&"ja-hyun")
	target.runtime_profile = _profile_from_character(&"myo-ryung")
	owner.current_hp = owner.runtime_profile.stats.max_hp
	target.current_hp = target.runtime_profile.stats.max_hp
	owner.stocks = 3
	target.stocks = 3
	var effect := CombatEffectData.new()
	effect.trigger = EffectData.Trigger.ON_HIT
	effect.kind = EffectData.Kind.EXPLOSION_DAMAGE
	effect.amount = 7.0
	effect.tags = [&"FIRE"]
	effect.cause_id = &"phase4-fire-condition"
	owner.runtime_profile.combat_effects = [effect]
	var hp_before := target.current_hp
	EffectControllerScript.dispatch(EffectData.Trigger.ON_HIT, owner, target, CombatRules.new(), &"attack", 0, [&"MELEE"])
	_check(is_equal_approx(target.current_hp, hp_before), "unmet FIRE condition applied an effect")
	EffectControllerScript.dispatch(EffectData.Trigger.ON_HIT, owner, target, CombatRules.new(), &"attack", 0, [&"MELEE", &"FIRE"])
	_check(is_equal_approx(target.current_hp, hp_before - 7.0), "met FIRE condition did not apply an effect")
	var invalid_effect := effect.duplicate(true) as CombatEffectData
	invalid_effect.tags = [&"UNKNOWN"]
	_check(not invalid_effect.is_valid_definition(), "unknown effect condition tag was accepted")
	var invalid_rule := CombatRuleData.new()
	invalid_rule.kind = CombatRuleData.Kind.IMMUNE_TAG
	invalid_rule.tags = [&"UNKNOWN"]
	_check(not invalid_rule.is_valid_definition(), "unknown immunity condition tag was accepted")
	owner.free()
	target.free()


func _test_layer_priority_and_conflicts() -> void:
	var authored := load("res://assets/character/ja-hyun/character.tres") as CharacterData
	var character := authored.duplicate(true) as CharacterData
	character.job_tree_ids = [&"phase4-leaf"]
	var authored_speed := authored.base_stats.ground_speed
	var root_job := JobData.new()
	root_job.job_id = &"phase4-root"
	root_job.stat_modifiers = [_modifier(StatModifier.Field.GROUND_SPEED, StatModifier.Operation.ADD, 10.0)]
	var leaf_job := JobData.new()
	leaf_job.job_id = &"phase4-leaf"
	leaf_job.parent_job_id = root_job.job_id
	leaf_job.stat_modifiers = [_modifier(StatModifier.Field.GROUND_SPEED, StatModifier.Operation.MULTIPLY, 2.0)]
	var accessory := AccessoryData.new()
	accessory.accessory_id = &"phase4-override"
	accessory.stat_modifiers = [_modifier(StatModifier.Field.GROUND_SPEED, StatModifier.Operation.OVERRIDE, 777.0)]
	var catalog := LoadoutCatalog.new()
	catalog.characters = [character]
	catalog.jobs = [root_job, leaf_job]
	catalog.accessories = [accessory]
	var selection := LoadoutSelection.new()
	selection.character_id = character.character_id
	selection.job_id = leaf_job.job_id
	selection.accessory_id = accessory.accessory_id
	var result := LoadoutBuilder.build(selection, catalog)
	_check(result.succeeded(), "ordered character/job/accessory loadout did not build")
	if result.succeeded():
		_check(is_equal_approx(result.profile.stats.ground_speed, 777.0), "ADD -> MULTIPLY -> OVERRIDE priority drifted")
	_check(is_equal_approx(authored.base_stats.ground_speed, authored_speed), "loadout priority test mutated authored CharacterData")
	var conflict := AccessoryData.new()
	conflict.accessory_id = &"phase4-conflict"
	conflict.stat_modifiers = [
		_modifier(StatModifier.Field.WEIGHT, StatModifier.Operation.ADD, 1.0),
		_modifier(StatModifier.Field.WEIGHT, StatModifier.Operation.MULTIPLY, 2.0),
	]
	_check(not conflict.is_valid_definition(), "same accessory wrote one stat twice")


func _test_complete_move_set_replacement() -> RuntimeCombatProfile:
	var local_catalog := LocalPlayCatalog.new().combat
	var boxing := local_catalog.accessory_by_id(&"fixture-boxing-gloves")
	var first_profile: RuntimeCombatProfile
	for character: CharacterData in local_catalog.characters:
		var selection := LoadoutSelection.new()
		selection.character_id = character.character_id
		selection.accessory_id = boxing.accessory_id
		var result := LoadoutBuilder.build(selection, local_catalog)
		_check(result.succeeded(), "%s boxing loadout did not build" % character.character_id)
		if not result.succeeded():
			continue
		_check(result.profile.move_set.move_set_id == boxing.replacement_move_set.move_set_id, "%s did not receive the complete replacement MoveSet" % character.character_id)
		_check(result.profile.move_set != boxing.replacement_move_set, "%s reused the authored replacement Resource" % character.character_id)
		_check(result.profile.move_set.combo_links.size() == boxing.replacement_move_set.combo_links.size(), "%s replacement links drifted" % character.character_id)
		_check(character.base_move_set.move_set_id != boxing.replacement_move_set.move_set_id or character.character_id == &"yu-ran", "%s source MoveSet was overwritten" % character.character_id)
		if first_profile == null:
			first_profile = result.profile
	return first_profile


func _test_ambiguous_move_sets() -> void:
	var authored := load("res://assets/combat/movesets/ja_hyun_moveset.tres") as MoveSetData
	var duplicate_link := authored.duplicate(true) as MoveSetData
	duplicate_link.combo_links.append(duplicate_link.combo_links[0].duplicate(true) as ComboLinkData)
	_check(not duplicate_link.is_valid_definition(), "duplicate combo link was accepted")
	var invalid_next := authored.duplicate(true) as MoveSetData
	invalid_next.combo_links[0].next_attack_id = &"missing-attack"
	_check(not invalid_next.is_valid_definition(), "combo link with a missing next attack was accepted")
	var duplicate_attack := authored.duplicate(true) as MoveSetData
	duplicate_attack.slots[1].attack.attack_id = duplicate_attack.slots[0].attack.attack_id
	_check(not duplicate_attack.is_valid_definition(), "duplicate attack ID was accepted")


func _test_presentation_non_authority(profile: RuntimeCombatProfile) -> void:
	_check(profile != null, "visual non-authority test lacks a boxing profile")
	if profile == null:
		return
	var fighter := FighterController.new()
	fighter.fighter_id = &"phase4-presentation"
	fighter.character_data = load("res://assets/character/ja-hyun/character.tres")
	root.add_child(fighter)
	fighter.set_physics_process(false)
	_check(fighter.configure_profile(profile), "boxing profile could not configure a fighter")
	fighter.set_physics_process(false)
	var presentation := Presentation.new()
	fighter.add_child(presentation)
	await process_frame
	var before := fighter.snapshot()
	var accessory_icon := ColorRect.new()
	accessory_icon.name = "AccessoryIcon"
	accessory_icon.color = Color.MAGENTA
	presentation.add_child(accessory_icon)
	presentation.sprite.speed_scale = 4.0
	presentation.sprite.frame = 15
	presentation.sprite.modulate = Color(0.2, 0.8, 1.0, 0.3)
	for index: int in 60:
		presentation.sync_visual(0.5 if index % 2 == 0 else 0.001)
		accessory_icon.visible = index % 3 != 0
	_check(before == fighter.snapshot(), "accessory icon or animation changed combat authority")
	fighter.queue_free()
	await process_frame


func _profile_from_character(character_id: StringName) -> RuntimeCombatProfile:
	var character := load("res://assets/character/%s/character.tres" % character_id) as CharacterData
	var profile := RuntimeCombatProfile.new()
	profile.character_id = character.character_id
	profile.stats = character.base_stats.duplicate(true) as CharacterStats
	profile.move_set = character.base_move_set.duplicate(true) as MoveSetData
	profile.tags = character.tags.duplicate()
	return profile


func _modifier(field: StatModifier.Field, operation: StatModifier.Operation, value: float) -> StatModifier:
	var modifier := StatModifier.new()
	modifier.field = field
	modifier.operation = operation
	modifier.value = value
	return modifier


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
