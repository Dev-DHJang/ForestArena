class_name ComboLinkData
extends Resource

@export var schema_version := 2
@export var from_attack_id: StringName
@export var input_action_id: StringName
@export var next_attack_id: StringName
## Tick relative to the start of recovery. Negative values are the final active
## ticks, zero is the first recovery tick.
@export var window_start_tick := -2
@export var window_end_tick := 10
@export var requires_hit := false


func is_valid_definition(attack_ids: Dictionary = {}) -> bool:
	return schema_version == 2 and not from_attack_id.is_empty() and not input_action_id.is_empty() and not next_attack_id.is_empty() and window_end_tick >= window_start_tick and (attack_ids.is_empty() or (attack_ids.has(from_attack_id) and attack_ids.has(next_attack_id)))
