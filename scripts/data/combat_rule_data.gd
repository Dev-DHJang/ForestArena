class_name CombatRuleData
extends Resource

enum Kind { IMMUNE_KNOCKBACK, IMMUNE_KNOCKDOWN, IMMUNE_HITSTUN, SUPER_ARMOR, IMMUNE_GRAB, IMMUNE_TAG }

@export var schema_version := 1
@export var kind: Kind = Kind.SUPER_ARMOR
@export var tags: Array[StringName] = []
@export var priority := 0


func is_valid_definition() -> bool:
	return schema_version == 1 and (kind != Kind.IMMUNE_TAG or not tags.is_empty())
