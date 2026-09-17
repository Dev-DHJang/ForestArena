class_name CancelRuleData
extends Resource

enum Kind { JUMP, GUARD, EVADE, SPECIAL, ULTIMATE }

@export var schema_version := 1
@export var from_attack_id: StringName
@export var kind: Kind = Kind.JUMP
@export var window_start_tick := 0
@export var window_end_tick := 0
@export var requires_hit := false


func is_valid_definition() -> bool:
	return schema_version == 1 and not from_attack_id.is_empty() and window_start_tick >= 0 and window_end_tick >= window_start_tick
