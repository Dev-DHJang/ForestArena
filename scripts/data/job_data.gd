class_name JobData
extends Resource

@export var schema_version: int = 2
@export var job_id: StringName
@export var parent_job_id: StringName
@export var stat_modifiers: Array[StatModifier] = []
@export var move_slot_patches: Array[MoveSlotPatch] = []
@export var replacement_move_set: MoveSetData
@export var combo_link_overrides: Array[ComboLinkData] = []
@export var combat_rules: Array[CombatRuleData] = []
@export var combat_effects: Array[Resource] = []
@export var added_passive_ids: Array[StringName] = []
@export var added_tags: Array[StringName] = []


func is_valid_definition() -> bool:
	return schema_version == 2 and not job_id.is_empty() and _has_unique_writes() and (replacement_move_set == null or replacement_move_set.is_valid_definition())


func _has_unique_writes() -> bool:
	var stats: Dictionary = {}
	for modifier: StatModifier in stat_modifiers:
		if modifier == null or not modifier.is_valid_definition() or stats.has(modifier.field_key()): return false
		stats[modifier.field_key()] = true
	var slots: Dictionary = {}
	for patch: MoveSlotPatch in move_slot_patches:
		if patch == null or not patch.is_valid_definition() or slots.has(patch.slot_id): return false
		slots[patch.slot_id] = true
	return true
