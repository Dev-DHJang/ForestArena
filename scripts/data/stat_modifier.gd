class_name StatModifier
extends Resource

enum Field { MAX_HP, WEIGHT, GROUND_SPEED, AIR_SPEED, JUMP_VELOCITY, GRAVITY, DASH_SPEED, DASH_DURATION_SECONDS, AIR_JUMP_COUNT }
enum Operation { ADD, MULTIPLY, OVERRIDE }

@export var field: Field = Field.MAX_HP
@export var operation: Operation = Operation.ADD
@export var value: float = 0.0


func is_valid_definition() -> bool:
	return is_finite(value)


func field_key() -> StringName:
	return [&"max_hp", &"weight", &"ground_speed", &"air_speed", &"jump_velocity", &"gravity", &"dash_speed", &"dash_duration_seconds", &"air_jump_count"][field]


func apply_to(stats: CharacterStats) -> void:
	var key := field_key()
	var current := float(stats.get(key))
	var next := value
	match operation:
		Operation.ADD: next = current + value
		Operation.MULTIPLY: next = current * value
		Operation.OVERRIDE: pass
	stats.set(key, roundi(next) if field == Field.AIR_JUMP_COUNT else next)
