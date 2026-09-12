class_name PassiveData
extends Resource

enum Trigger { ON_ATTACK_HIT, ON_GUARDED_HIT, ON_EVADE_END }
enum Effect { NEXT_ATTACK_DAMAGE_MULTIPLIER, SPECIAL_COOLDOWN_REDUCTION, GUARD_RESTORE, EVADE_COOLDOWN_REDUCTION }

@export var schema_version := 1
@export var passive_id: StringName
@export var trigger: Trigger
@export var effect: Effect
@export var value := 0.0
@export var duration_ticks := 0
@export var cooldown_ticks := 0
@export var action_filter: StringName
@export var requires_dash := false


func is_valid_definition() -> bool:
	if schema_version != 1 or passive_id.is_empty() or value <= 0.0 or cooldown_ticks < 0:
		return false
	if effect == Effect.NEXT_ATTACK_DAMAGE_MULTIPLIER and (value < 1.0 or duration_ticks <= 0):
		return false
	return effect != Effect.NEXT_ATTACK_DAMAGE_MULTIPLIER or duration_ticks > 0
