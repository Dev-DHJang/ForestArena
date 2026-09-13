class_name JobData
extends Resource

@export var schema_version: int = 5
@export var job_id: StringName
@export var parent_job_id: StringName
@export_range(1, 2, 1) var stage: int = 1
@export var stat_modifiers: Array[StatModifier] = []
@export var move_slot_patches: Array[MoveSlotPatch] = []
@export var combat_tuning_modifiers: Array[CombatTuningModifier] = []
@export var added_passive_ids: Array[StringName] = []
@export var added_tags: Array[StringName] = []
@export var cancel_rules: Array[CancelRuleData] = []


func is_valid_definition() -> bool:
	return schema_version == 5 and not job_id.is_empty() and stage >= 1 and _has_unique_writes()


func _has_unique_writes() -> bool:
	var stats: Dictionary = {}
	for modifier: StatModifier in stat_modifiers:
		if modifier == null or not modifier.is_valid_definition() or stats.has(modifier.field_key()): return false
		stats[modifier.field_key()] = true
	var slots: Dictionary = {}
	for patch: MoveSlotPatch in move_slot_patches:
		if patch == null or not patch.is_valid_definition() or slots.has(patch.slot_id): return false
		slots[patch.slot_id] = true
	var tuning: Dictionary = {}
	for modifier: CombatTuningModifier in combat_tuning_modifiers:
		if modifier == null or not modifier.is_valid_definition() or tuning.has(modifier.field_key()): return false
		tuning[modifier.field_key()] = true
	var rules: Dictionary = {}
	for rule: CancelRuleData in cancel_rules:
		if rule == null or not rule.is_valid_definition() or rules.has(rule.rule_id): return false
		rules[rule.rule_id] = true
	return true
