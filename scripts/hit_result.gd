class_name HitResult
extends RefCounted

enum Type { HIT, BLOCK, PERFECT_GUARD, ARMOR, IMMUNE, MISS }

var type: Type = Type.MISS
var damage := 0.0
var guard_damage := 0.0
var knockback := Vector2.ZERO
var hitstun_ticks := 0
var reaction: StringName


func landed() -> bool:
	return type in [Type.HIT, Type.BLOCK, Type.PERFECT_GUARD, Type.ARMOR]
