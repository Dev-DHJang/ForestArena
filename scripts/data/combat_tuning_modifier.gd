class_name CombatTuningModifier
extends Resource

enum Field {
	GUARD_MAX_DURABILITY = 0,
	GUARD_HOLD_DRAIN_PER_SECOND = 1,
	GUARD_REGEN_PER_SECOND = 2,
	EVADE_TOTAL_TICKS = 3,
	EVADE_COOLDOWN_TICKS = 4,
	EVADE_SPEED = 5,
	DEPRECATED_CHARGE_MAX_TICKS = 8,
	SPECIAL_COOLDOWN_TICKS = 9,
	AERIAL_SPECIAL_IMPULSE_MULTIPLIER = 10,
}
enum Operation { ADD, MULTIPLY, SET }

@export var field: Field = Field.GUARD_MAX_DURABILITY
@export var operation: Operation = Operation.ADD
@export var value: float = 0.0


func is_valid_definition() -> bool:
	return field != Field.DEPRECATED_CHARGE_MAX_TICKS and is_finite(value)


func field_key() -> StringName:
	return [
		&"guard_max_durability",
		&"guard_hold_drain_per_second",
		&"guard_regen_per_second",
		&"evade_total_ticks",
		&"evade_cooldown_ticks",
		&"evade_speed",
		&"", &"", &"", &"special_cooldown_ticks", &"aerial_special_impulse_multiplier",
	][field]


func apply_to(tuning: CombatTuningData) -> void:
	var key := field_key()
	var current := float(tuning.get(key))
	var next := value
	match operation:
		Operation.ADD: next = current + value
		Operation.MULTIPLY: next = current * value
		Operation.SET: pass
	if field in [Field.EVADE_TOTAL_TICKS, Field.EVADE_COOLDOWN_TICKS, Field.SPECIAL_COOLDOWN_TICKS]:
		tuning.set(key, roundi(next))
	else:
		tuning.set(key, next)
