class_name LoadoutBuilder
extends RefCounted

static func build(selection: LoadoutSelection, catalog: LoadoutCatalog, base_tuning: CombatTuningData = null) -> LoadoutBuildResult:
	if selection == null or not selection.is_valid_definition(): return LoadoutBuildResult.failure(LoadoutBuildResult.ERR_INVALID_SELECTION)
	if catalog == null or catalog.schema_version != 2 or not catalog.is_valid_definition(): return LoadoutBuildResult.failure(LoadoutBuildResult.ERR_INVALID_CATALOG)
	var character := catalog.character_by_id(selection.character_id)
	if character == null: return LoadoutBuildResult.failure(LoadoutBuildResult.ERR_MISSING_CHARACTER)
	if character.schema_version != 2 or not character.is_valid_definition(): return LoadoutBuildResult.failure(LoadoutBuildResult.ERR_UNSUPPORTED_SCHEMA)
	var layers: Array[Resource] = []
	if not selection.job_id.is_empty():
		var chain_result: Variant = _job_chain(selection.job_id, catalog)
		if chain_result is LoadoutBuildResult: return chain_result
		if chain_result.is_empty() or not character.job_tree_ids.has((chain_result[0] as JobData).job_id): return LoadoutBuildResult.failure(LoadoutBuildResult.ERR_UNALLOWED_JOB)
		layers.append_array(chain_result)
	if not selection.accessory_id.is_empty():
		var accessory := catalog.accessory_by_id(selection.accessory_id)
		if accessory == null: return LoadoutBuildResult.failure(LoadoutBuildResult.ERR_MISSING_ACCESSORY)
		if accessory.schema_version != 2 or not accessory.is_valid_definition(): return LoadoutBuildResult.failure(LoadoutBuildResult.ERR_UNSUPPORTED_SCHEMA)
		layers.append(accessory)
	var profile := RuntimeCombatProfile.new()
	profile.character_id = character.character_id
	profile.job_id = selection.job_id
	profile.accessory_id = selection.accessory_id
	profile.stats = character.base_stats.duplicate(true) as CharacterStats
	profile.move_set = character.base_move_set.duplicate(true) as MoveSetData
	profile.combat_tuning = (base_tuning.duplicate(true) as CombatTuningData) if base_tuning != null else CombatTuningData.new()
	profile.tags = character.tags.duplicate()
	for layer: Resource in layers:
		var apply_result := _apply_layer(profile, layer)
		if apply_result != &"": return LoadoutBuildResult.failure(apply_result)
		if layer is AccessoryData:
			var eligibility_tags := profile.tags.duplicate()
			for effect: AccessoryEffectData in layer.conditional_effects:
				if not effect.matches(eligibility_tags): continue
				var effect_result := _apply_layer(profile, effect)
				if effect_result != &"": return LoadoutBuildResult.failure(effect_result)
				profile.active_accessory_effect_ids.append(effect.effect_id)
			profile.active_accessory_effect_ids.sort()
	for passive_id: StringName in profile.passive_ids:
		var passive := catalog.passive_by_id(passive_id)
		if passive != null: profile.passives.append(passive.duplicate(true) as PassiveData)
	profile.passives.sort_custom(func(a: PassiveData, b: PassiveData) -> bool: return a.passive_id < b.passive_id)
	if not profile.is_valid_definition(): return LoadoutBuildResult.failure(LoadoutBuildResult.ERR_INVALID_PROFILE)
	return LoadoutBuildResult.success(profile)


static func _job_chain(leaf_id: StringName, catalog: LoadoutCatalog):
	var chain: Array[Resource] = []
	var seen: Dictionary = {}
	var current := catalog.job_by_id(leaf_id)
	if current == null: return LoadoutBuildResult.failure(LoadoutBuildResult.ERR_MISSING_JOB)
	while current != null:
		if current.schema_version != 4 or not current.is_valid_definition(): return LoadoutBuildResult.failure(LoadoutBuildResult.ERR_UNSUPPORTED_SCHEMA)
		if seen.has(current.job_id): return LoadoutBuildResult.failure(LoadoutBuildResult.ERR_JOB_CYCLE)
		seen[current.job_id] = true
		chain.push_front(current)
		if current.parent_job_id.is_empty(): break
		current = catalog.job_by_id(current.parent_job_id)
		if current == null: return LoadoutBuildResult.failure(LoadoutBuildResult.ERR_INVALID_PARENT)
	for index: int in chain.size():
		var job: JobData = chain[index]
		if job.stage != index + 1: return LoadoutBuildResult.failure(LoadoutBuildResult.ERR_INVALID_PARENT)
	return chain


static func _apply_layer(profile: RuntimeCombatProfile, layer: Resource) -> StringName:
	var modifiers: Array[StatModifier] = layer.get("stat_modifiers") as Array[StatModifier]
	var patches: Array[MoveSlotPatch] = layer.get("move_slot_patches") as Array[MoveSlotPatch]
	var tuning_modifiers: Array[CombatTuningModifier] = []
	if layer is JobData or layer is AccessoryEffectData:
		tuning_modifiers = layer.combat_tuning_modifiers
	var stat_writes: Dictionary = {}
	for modifier: StatModifier in modifiers:
		if stat_writes.has(modifier.field_key()): return LoadoutBuildResult.ERR_CONFLICT
		stat_writes[modifier.field_key()] = true
		modifier.apply_to(profile.stats)
	var slot_writes: Dictionary = {}
	for patch: MoveSlotPatch in patches:
		if slot_writes.has(patch.slot_id) or not profile.move_set.replace_slot(patch.slot_id, patch.replacement.duplicate(true) as AttackData): return LoadoutBuildResult.ERR_CONFLICT
		slot_writes[patch.slot_id] = true
	var tuning_writes: Dictionary = {}
	for modifier: CombatTuningModifier in tuning_modifiers:
		if tuning_writes.has(modifier.field_key()): return LoadoutBuildResult.ERR_CONFLICT
		tuning_writes[modifier.field_key()] = true
		modifier.apply_to(profile.combat_tuning)
	if not profile.combat_tuning.is_valid_definition(): return LoadoutBuildResult.ERR_INVALID_PROFILE
	var passive_values: Array = layer.get("added_passive_ids") if _has_property(layer, &"added_passive_ids") else []
	for value: StringName in passive_values:
		if not value.is_empty() and not profile.passive_ids.has(value): profile.passive_ids.append(value)
	var tag_values: Array = layer.get("added_tags") if _has_property(layer, &"added_tags") else []
	for value: StringName in tag_values:
		if not value.is_empty() and not profile.tags.has(value): profile.tags.append(value)
	if layer is JobData:
		profile.job_chain_ids.append(layer.job_id)
		for rule: CancelRuleData in layer.cancel_rules:
			if profile.cancel_rules.any(func(existing: CancelRuleData) -> bool: return existing.rule_id == rule.rule_id): return LoadoutBuildResult.ERR_CONFLICT
			profile.cancel_rules.append(rule.duplicate(true) as CancelRuleData)
	return &""


static func _has_property(resource: Resource, property_name: StringName) -> bool:
	return resource.get_property_list().any(func(item: Dictionary) -> bool: return item.name == property_name)
