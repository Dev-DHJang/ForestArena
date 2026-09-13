class_name MoveSlotPatch
extends Resource

@export var slot_id: StringName
@export var replacement: AttackData
@export var copy_from_slot_id: StringName
@export var startup_delta := 0
@export var damage_delta := 0.0
@export var guard_damage_multiplier := 1.0
@export var make_non_finisher := false


func is_valid_definition() -> bool:
	return not slot_id.is_empty() and ((replacement != null and replacement.is_valid_definition() and copy_from_slot_id.is_empty()) or (replacement == null and not copy_from_slot_id.is_empty())) and guard_damage_multiplier > 0.0


func materialize(move_set: MoveSetData) -> AttackData:
	if replacement != null:
		return replacement.duplicate(true) as AttackData
	var source := move_set.attack_for_slot(copy_from_slot_id)
	if source == null:
		return null
	var result := source.duplicate(true) as AttackData
	result.attack_id = StringName("%s-job-patch" % source.attack_id)
	result.startup_ticks += startup_delta
	result.damage += damage_delta
	result.guard_damage_multiplier *= guard_damage_multiplier
	if make_non_finisher:
		result.is_finisher = false
	return result if result.is_valid_definition() else null
