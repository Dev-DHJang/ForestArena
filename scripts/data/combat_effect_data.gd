class_name CombatEffectData
extends Resource

enum Trigger { ON_ATTACK_START, ON_ATTACK_END, ON_HIT, ON_BLOCKED, ON_INCOMING_HIT, ON_DAMAGED, ON_KNOCK_DOWN, ON_WAKE_UP, ON_JUMP, ON_LAND, ON_KILL, ON_DEATH }
enum Kind { REFLECT_DAMAGE, EXPLOSION_DAMAGE, REVIVE, GAIN_ULTIMATE }

@export var schema_version := 1
@export var trigger: Trigger = Trigger.ON_HIT
@export var kind: Kind = Kind.REFLECT_DAMAGE
@export var amount := 0.0
@export var tags: Array[StringName] = []
@export var cause_id: StringName
@export_range(0, 8, 1) var max_chain_depth := 1


func is_valid_definition() -> bool:
	return schema_version == 1 and not cause_id.is_empty() and amount >= 0.0 and max_chain_depth >= 0 and (kind != Kind.REVIVE or amount > 0.0)
