class_name AccessoryData
extends Resource

## Phase 2 accessories intentionally have no rarity or grade field.
@export var schema_version: int = 2
@export var accessory_id: StringName
@export var stat_modifiers: Array[StatModifier] = []
@export var move_slot_patches: Array[MoveSlotPatch] = []
@export var added_passive_ids: Array[StringName] = []
@export var added_tags: Array[StringName] = []
@export var conditional_effects: Array[AccessoryEffectData] = []


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
	var effects: Dictionary = {}
	for effect: AccessoryEffectData in conditional_effects:
		if effect == null or not effect.is_valid_definition() or effects.has(effect.effect_id): return false
		effects[effect.effect_id] = true
	return true
