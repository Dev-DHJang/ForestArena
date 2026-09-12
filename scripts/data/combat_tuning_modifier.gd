class_name CombatTuningModifier
extends Resource

enum Field {
	GUARD_MAX_DURABILITY,
	GUARD_HOLD_DRAIN_PER_SECOND,
	GUARD_REGEN_PER_SECOND,
	EVADE_TOTAL_TICKS,
	EVADE_COOLDOWN_TICKS,
	EVADE_SPEED,
	GRAB_STARTUP_TICKS,
	GRAB_FAILURE_RECOVERY_TICKS,
	CHARGE_MAX_TICKS,
	SPECIAL_COOLDOWN_TICKS,
	AERIAL_SPECIAL_IMPULSE_MULTIPLIER,
}
enum Operation { ADD, MULTIPLY, SET }

@export var field: Field = Field.GUARD_MAX_DURABILITY
@export var operation: Operation = Operation.ADD
@export var value: float = 0.0


func is_valid_definition() -> bool:
	return is_finite(value)


func field_key() -> StringName:
	return [
		&"guard_max_durability",
		&"guard_hold_drain_per_second",
		&"guard_regen_per_second",
		&"evade_total_ticks",
		&"evade_cooldown_ticks",
		&"evade_speed",
		&"grab_startup_ticks",
		&"grab_failure_recovery_ticks",
		&"charge_max_ticks",
		&"special_cooldown_ticks",
		&"aerial_special_impulse_multiplier",
	][field]


func apply_to(tuning: CombatTuningData) -> void:
	var key := field_key()
	var current := float(tuning.get(key))
	var next := value
	match operation:
		Operation.ADD: next = current + value
		Operation.MULTIPLY: next = current * value
		Operation.SET: pass
	if field in [Field.EVADE_TOTAL_TICKS, Field.EVADE_COOLDOWN_TICKS, Field.GRAB_STARTUP_TICKS, Field.GRAB_FAILURE_RECOVERY_TICKS, Field.CHARGE_MAX_TICKS, Field.SPECIAL_COOLDOWN_TICKS]:
		tuning.set(key, roundi(next))
	else:
		tuning.set(key, next)
