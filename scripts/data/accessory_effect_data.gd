class_name AccessoryEffectData
extends Resource

@export var schema_version: int = 1
@export var effect_id: StringName
@export var required_all_tags: Array[StringName] = []
@export var required_any_tags: Array[StringName] = []
@export var blocked_tags: Array[StringName] = []
@export var stat_modifiers: Array[StatModifier] = []
@export var combat_tuning_modifiers: Array[CombatTuningModifier] = []
@export var move_slot_patches: Array[MoveSlotPatch] = []
@export var added_passive_ids: Array[StringName] = []


func is_valid_definition() -> bool:
	if schema_version != 1 or effect_id.is_empty():
		return false
	return _unique_writes(stat_modifiers, "field_key") and _unique_writes(combat_tuning_modifiers, "field_key") and _unique_writes(move_slot_patches, "slot_id")


func matches(tags: Array[StringName]) -> bool:
	for tag: StringName in required_all_tags:
		if not tags.has(tag): return false
	if not required_any_tags.is_empty() and not required_any_tags.any(func(tag: StringName) -> bool: return tags.has(tag)):
		return false
	for tag: StringName in blocked_tags:
		if tags.has(tag): return false
	return true


func _unique_writes(items: Array, property: String) -> bool:
	var seen: Dictionary = {}
	for item: Resource in items:
		if item == null or not item.is_valid_definition(): return false
		var key: Variant = item.get(property) if property == "slot_id" else item.call(property)
		if seen.has(key): return false
		seen[key] = true
	return true
