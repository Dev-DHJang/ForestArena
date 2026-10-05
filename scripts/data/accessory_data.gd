class_name AccessoryData
extends Resource

## Phase 2 accessories intentionally have no rarity or grade field.
@export var schema_version: int = 2
@export var accessory_id: StringName
@export var stat_modifiers: Array[StatModifier] = []
@export var move_slot_patches: Array[MoveSlotPatch] = []
@export var replacement_move_set: MoveSetData
@export var combo_link_overrides: Array[ComboLinkData] = []
@export var combat_rules: Array[CombatRuleData] = []
@export var combat_effects: Array[Resource] = []
@export var added_passive_ids: Array[StringName] = []
@export var added_tags: Array[StringName] = []


func is_valid_definition() -> bool:
	if schema_version != 2 or accessory_id.is_empty(): return false
	var stats: Dictionary = {}
	for modifier: StatModifier in stat_modifiers:
		if modifier == null or not modifier.is_valid_definition() or stats.has(modifier.field_key()): return false
		stats[modifier.field_key()] = true
	var slots: Dictionary = {}
	for patch: MoveSlotPatch in move_slot_patches:
		if patch == null or not patch.is_valid_definition() or slots.has(patch.slot_id): return false
		slots[patch.slot_id] = true
	if replacement_move_set != null and not replacement_move_set.is_valid_definition(): return false
	var link_keys: Dictionary = {}
	for link: ComboLinkData in combo_link_overrides:
		if link == null or not link.is_valid_definition(): return false
		var key := "%s:%s:%d:%d:%s" % [link.from_attack_id, link.input_action_id, link.window_start_tick, link.window_end_tick, link.requires_hit]
		if link_keys.has(key): return false
		link_keys[key] = true
	for rule: CombatRuleData in combat_rules:
		if rule == null or not rule.is_valid_definition(): return false
	for effect: Resource in combat_effects:
		if effect == null or not effect.has_method("is_valid_definition") or not effect.is_valid_definition(): return false
	return _has_unique_nonempty_ids(added_passive_ids) and _has_unique_nonempty_ids(added_tags)


func _has_unique_nonempty_ids(values: Array[StringName]) -> bool:
	var seen: Dictionary = {}
	for value: StringName in values:
		if value.is_empty() or seen.has(value): return false
		seen[value] = true
	return true
