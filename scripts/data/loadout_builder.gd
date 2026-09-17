class_name LoadoutBuilder
extends RefCounted

static func build(selection: LoadoutSelection, catalog: LoadoutCatalog) -> LoadoutBuildResult:
	if selection == null or not selection.is_valid_definition(): return LoadoutBuildResult.failure(LoadoutBuildResult.ERR_INVALID_SELECTION)
	if catalog == null or catalog.schema_version != 1 or not catalog.is_valid_definition(): return LoadoutBuildResult.failure(LoadoutBuildResult.ERR_INVALID_CATALOG)
	var character := catalog.character_by_id(selection.character_id)
	if character == null: return LoadoutBuildResult.failure(LoadoutBuildResult.ERR_MISSING_CHARACTER)
	if character.schema_version != 2 or not character.is_valid_definition(): return LoadoutBuildResult.failure(LoadoutBuildResult.ERR_UNSUPPORTED_SCHEMA)
	var layers: Array[Resource] = []
	if not selection.job_id.is_empty():
		if not character.job_tree_ids.has(selection.job_id): return LoadoutBuildResult.failure(LoadoutBuildResult.ERR_UNALLOWED_JOB)
		var chain_result: Variant = _job_chain(selection.job_id, catalog)
		if chain_result is LoadoutBuildResult: return chain_result
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
	profile.tags = character.tags.duplicate()
	for layer: Resource in layers:
		var apply_result := _apply_layer(profile, layer)
		if apply_result != &"": return LoadoutBuildResult.failure(apply_result)
	if not profile.is_valid_definition(): return LoadoutBuildResult.failure(LoadoutBuildResult.ERR_INVALID_PROFILE)
	return LoadoutBuildResult.success(profile)


static func _job_chain(leaf_id: StringName, catalog: LoadoutCatalog):
	var chain: Array[Resource] = []
	var seen: Dictionary = {}
	var current := catalog.job_by_id(leaf_id)
	if current == null: return LoadoutBuildResult.failure(LoadoutBuildResult.ERR_MISSING_JOB)
	while current != null:
		if current.schema_version != 2 or not current.is_valid_definition(): return LoadoutBuildResult.failure(LoadoutBuildResult.ERR_UNSUPPORTED_SCHEMA)
		if seen.has(current.job_id): return LoadoutBuildResult.failure(LoadoutBuildResult.ERR_JOB_CYCLE)
		seen[current.job_id] = true
		chain.push_front(current)
		if current.parent_job_id.is_empty(): break
		current = catalog.job_by_id(current.parent_job_id)
		if current == null: return LoadoutBuildResult.failure(LoadoutBuildResult.ERR_INVALID_PARENT)
	return chain


static func _apply_layer(profile: RuntimeCombatProfile, layer: Resource) -> StringName:
	var modifiers: Array[StatModifier] = layer.get("stat_modifiers") as Array[StatModifier]
	var patches: Array[MoveSlotPatch] = layer.get("move_slot_patches") as Array[MoveSlotPatch]
	var stat_writes: Dictionary = {}
	for modifier: StatModifier in modifiers:
		if stat_writes.has(modifier.field_key()): return LoadoutBuildResult.ERR_CONFLICT
		stat_writes[modifier.field_key()] = true
		modifier.apply_to(profile.stats)
	var slot_writes: Dictionary = {}
	var replacement: MoveSetData = layer.get("replacement_move_set") as MoveSetData
	if replacement != null:
		profile.move_set = replacement.duplicate(true) as MoveSetData
	for patch: MoveSlotPatch in patches:
		if slot_writes.has(patch.slot_id): return LoadoutBuildResult.ERR_CONFLICT
		var previous := _attack_in_slot(profile.move_set, patch.slot_id)
		if previous == null or not profile.move_set.replace_slot(patch.slot_id, patch.replacement.duplicate(true) as AttackData): return LoadoutBuildResult.ERR_CONFLICT
		_replace_attack_references(profile.move_set, previous.attack_id, patch.replacement.attack_id)
		slot_writes[patch.slot_id] = true
	for value: StringName in layer.get("added_passive_ids") as Array[StringName]:
		if not value.is_empty() and not profile.passive_ids.has(value): profile.passive_ids.append(value)
	for value: StringName in layer.get("added_tags") as Array[StringName]:
		if not value.is_empty() and not profile.tags.has(value): profile.tags.append(value)
	for rule: CombatRuleData in layer.get("combat_rules") as Array[CombatRuleData]:
		profile.combat_rules.append(rule.duplicate(true) as CombatRuleData)
	for effect: Resource in layer.get("combat_effects") as Array[Resource]:
		profile.combat_effects.append(effect.duplicate(true))
	var combo_overrides: Array[ComboLinkData] = layer.get("combo_link_overrides") as Array[ComboLinkData]
	if not combo_overrides.is_empty():
		profile.move_set.combo_links = combo_overrides.duplicate(true) as Array[ComboLinkData]
	return &""


static func _attack_in_slot(move_set: MoveSetData, slot_id: StringName) -> AttackData:
	for slot: MoveSlotData in move_set.slots:
		if slot.slot_id == slot_id: return slot.attack
	return null


static func _replace_attack_references(move_set: MoveSetData, previous_id: StringName, replacement_id: StringName) -> void:
	for index: int in move_set.opening_attack_ids.size():
		if move_set.opening_attack_ids[index] == previous_id: move_set.opening_attack_ids[index] = replacement_id
	for link: ComboLinkData in move_set.combo_links:
		if link.from_attack_id == previous_id: link.from_attack_id = replacement_id
		if link.next_attack_id == previous_id: link.next_attack_id = replacement_id
