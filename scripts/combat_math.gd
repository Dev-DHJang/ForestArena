class_name CombatMath
extends RefCounted

static func knockback_speed(attack: AttackData, defender_weight: float, profile_multiplier := 1.0) -> float:
	return attack.knockback / maxf(defender_weight, 0.1) * profile_multiplier


static func hitstun_ticks(attack: AttackData, defender_weight: float, rules: CombatRules) -> int:
	var weighted := roundi(float(attack.fixed_hitstun_ticks) / maxf(defender_weight, 0.1))
	return clampi(weighted, rules.hitstun_min_ticks, rules.hitstun_max_ticks)
