class_name HitResolver
extends RefCounted

const EffectControllerScript = preload("res://scripts/effect_controller.gd")
const EffectData = preload("res://scripts/data/combat_effect_data.gd")

static func resolve(context: HitContext, rules: CombatRules) -> HitResult:
	var result := HitResult.new()
	if context.attacker == null or context.defender == null or context.attack == null or context.attacker == context.defender:
		return result
	var attack := context.attack
	var defender := context.defender
	if defender.runtime_state.guarding and not attack.ignore_armor_and_immunity:
		result.type = HitResult.Type.BLOCK
		result.guard_damage = attack.guard_damage if attack.guard_damage > 0.0 else attack.damage
		defender.runtime_state.guard_durability = maxf(0.0, defender.runtime_state.guard_durability - result.guard_damage)
		if defender.runtime_state.guard_durability <= 0.0:
			defender.hitstun_ticks = rules.guard_break_ticks
			defender.state = FighterController.State.HITSTUN
		EffectControllerScript.dispatch(EffectData.Trigger.ON_BLOCKED, context.attacker, defender, rules)
		return result
	if defender.invulnerability_ticks > 0 and not attack.ignore_armor_and_immunity:
		result.type = HitResult.Type.IMMUNE
		return result
	if not attack.ignore_armor_and_immunity and _has_rule(defender.runtime_profile, CombatRuleData.Kind.IMMUNE_TAG, attack.tags):
		result.type = HitResult.Type.IMMUNE
		return result
	if not attack.ignore_armor_and_immunity and _has_rule(defender.runtime_profile, CombatRuleData.Kind.SUPER_ARMOR, attack.tags):
		result.type = HitResult.Type.ARMOR
		result.damage = attack.damage
		defender.current_hp = maxf(0.0, defender.current_hp - attack.damage)
		return result
	var direction := _launch_direction(context)
	var speed := CombatMath.knockback_speed(attack, defender._stats().weight)
	result.type = HitResult.Type.HIT
	result.damage = attack.damage
	result.knockback = direction * speed
	result.hitstun_ticks = CombatMath.hitstun_ticks(attack, defender._stats().weight, rules)
	result.reaction = AttackData.HitReaction.keys()[attack.hit_reaction]
	defender.apply_hit(attack, result.knockback, result.hitstun_ticks, rules)
	# Gauge changes only after effective damage; blocked, immune and armored hits do not fill it.
	context.attacker.runtime_state.ultimate_gauge = minf(rules.ultimate_gauge_max, context.attacker.runtime_state.ultimate_gauge + result.damage * rules.ultimate_gauge_per_damage_dealt + attack.resource_gain)
	defender.runtime_state.ultimate_gauge = minf(rules.ultimate_gauge_max, defender.runtime_state.ultimate_gauge + result.damage * rules.ultimate_gauge_per_damage_taken)
	EffectControllerScript.dispatch(EffectData.Trigger.ON_HIT, context.attacker, defender, rules)
	EffectControllerScript.dispatch(EffectData.Trigger.ON_INCOMING_HIT, defender, context.attacker, rules, attack.attack_id)
	EffectControllerScript.dispatch(EffectData.Trigger.ON_DAMAGED, defender, context.attacker, rules, attack.attack_id)
	return result


static func _has_rule(profile: RuntimeCombatProfile, kind: CombatRuleData.Kind, tags: Array[StringName]) -> bool:
	if profile == null: return false
	for rule: CombatRuleData in profile.combat_rules:
		if rule.kind != kind: continue
		if kind != CombatRuleData.Kind.IMMUNE_TAG or rule.tags.any(func(tag: StringName) -> bool: return tags.has(tag)):
			return true
	return false


static func _launch_direction(context: HitContext) -> Vector2:
	var attack := context.attack
	if attack.launch_mode == AttackData.LaunchMode.TOWARD_SOURCE:
		return (context.source_position - context.target_position).normalized()
	var result := attack.launch_vector
	if attack.input_direction == AttackData.InputDirection.OMNI:
		match context.source_direction:
			CombatIntent.Direction.UP: result = Vector2(0.2, -1.0)
			CombatIntent.Direction.DOWN: result = Vector2(0.2, 1.0)
	result.x *= context.source_facing
	return result.normalized()
