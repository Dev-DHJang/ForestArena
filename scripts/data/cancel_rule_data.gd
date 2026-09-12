class_name CancelRuleData
extends Resource

@export var schema_version := 1
@export var rule_id: StringName
@export var from_action_id: StringName
@export var from_context: AttackData.ActivationContext = AttackData.ActivationContext.BOTH
@export var recovery_start_tick := 0
@export var recovery_end_tick := 0
@export var to_action_id: StringName


func is_valid_definition() -> bool:
	return schema_version == 1 and not rule_id.is_empty() and not from_action_id.is_empty() and not to_action_id.is_empty() and recovery_start_tick >= 0 and recovery_end_tick >= recovery_start_tick and from_action_id != &"ultimate" and to_action_id != &"ultimate"
