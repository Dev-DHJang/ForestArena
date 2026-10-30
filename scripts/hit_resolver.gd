class_name HitResolver
extends RefCounted

const EffectControllerScript = preload("res://scripts/effect_controller.gd")
const EffectData = preload("res://scripts/data/combat_effect_data.gd")

static func resolve(context: HitContext, rules: CombatRules) -> HitResult:
	var result := HitResult.new()
	if context.attacker == null or context.defender == null or context.attack == null or context.attacker == context.defender or context.defender.state in [FighterController.State.FALLING_OUT, FighterController.State.RING_OUT, FighterController.State.DEAD, FighterController.State.MATCH_ENDED]:
		return result
	var attack := context.attack
	var defender := context.defender
	if defender.wakeup_protection_ticks > 0 and not attack.ignore_armor_and_immunity:
		result.type = HitResult.Type.IMMUNE
		return result
	if defender.runtime_state.guarding and not attack.ignore_armor_and_immunity:
		result.type = HitResult.Type.BLOCK
		result.guard_damage = attack.guard_damage if attack.guard_damage > 0.0 else attack.damage
		defender.runtime_state.guard_durability = maxf(0.0, defender.runtime_state.guard_durability - result.guard_damage)
		if defender.runtime_state.guard_durability <= 0.0:
			defender.runtime_state.guarding = false
			defender.hitstun_ticks = rules.guard_break_ticks
			defender.state = FighterController.State.HITSTUN
		EffectControllerScript.dispatch(EffectData.Trigger.ON_BLOCKED, context.attacker, defender, rules, attack.attack_id, 0, attack.tags)
		return result
	if (defender.invulnerability_ticks > 0 or defender.wakeup_protection_ticks > 0) and not attack.ignore_armor_and_immunity:
		result.type = HitResult.Type.IMMUNE
		return result
	if not attack.ignore_armor_and_immunity and _has_rule(defender.runtime_profile, CombatRuleData.Kind.IMMUNE_TAG, attack.tags):
		result.type = HitResult.Type.IMMUNE
		return result
	if not attack.ignore_armor_and_immunity and _has_rule(defender.runtime_profile, CombatRuleData.Kind.SUPER_ARMOR, attack.tags):
		if defender.state == FighterController.State.EQUIPMENT:
			defender._stop_equipment()
			defender.state = FighterController.State.IDLE if defender.is_on_floor() else FighterController.State.FALL
		result.type = HitResult.Type.ARMOR
		result.damage = attack.damage
		defender.current_hp = maxf(0.0, defender.current_hp - attack.damage)
		if defender.current_hp <= 0.0: defender.lose_stock(rules)
		return result
	var direction := _launch_direction(context)
	var speed := CombatMath.knockback_speed(attack, defender._stats().weight)
	result.type = HitResult.Type.HIT
	result.damage = attack.damage
	result.knockback = Vector2.ZERO if _has_rule(defender.runtime_profile, CombatRuleData.Kind.IMMUNE_KNOCKBACK, attack.tags) else direction * speed
	if attack.schema_version == 4 and attack.landing_knockdown and attack.hit_reaction == AttackData.HitReaction.SLAM:
		result.knockback.y = minf(rules.max_fall_speed, maxf(result.knockback.y, attack.knockback))
	result.hitstun_ticks = 0 if _has_rule(defender.runtime_profile, CombatRuleData.Kind.IMMUNE_HITSTUN, attack.tags) else CombatMath.hitstun_ticks(attack, defender._stats().weight, rules)
	var reaction: int = attack.hit_reaction
	if _has_rule(defender.runtime_profile, CombatRuleData.Kind.IMMUNE_KNOCKDOWN, attack.tags) and reaction in [AttackData.HitReaction.KNOCK_DOWN, AttackData.HitReaction.SLAM, AttackData.HitReaction.CRUMPLE]:
		reaction = AttackData.HitReaction.NORMAL_HIT
	result.reaction = AttackData.HitReaction.keys()[reaction]
	defender.apply_hit(attack, result.knockback, result.hitstun_ticks, rules, reaction)
	if attack.pull_ticks > 0 and defender.state not in [FighterController.State.RING_OUT, FighterController.State.DEAD]:
		defender.begin_pull(context.source_position, speed, attack.pull_ticks, attack.pull_stop_distance)
	# Gauge changes only after effective damage; blocked, immune and armored hits do not fill it.
	if not rules.simplified_combat: context.attacker.runtime_state.ultimate_gauge = minf(rules.ultimate_gauge_max, context.attacker.runtime_state.ultimate_gauge + result.damage * rules.ultimate_gauge_per_damage_dealt + attack.resource_gain)
	if not rules.simplified_combat: defender.runtime_state.ultimate_gauge = minf(rules.ultimate_gauge_max, defender.runtime_state.ultimate_gauge + result.damage * rules.ultimate_gauge_per_damage_taken)
	EffectControllerScript.dispatch(EffectData.Trigger.ON_HIT, context.attacker, defender, rules, attack.attack_id, 0, attack.tags)
	EffectControllerScript.dispatch(EffectData.Trigger.ON_INCOMING_HIT, defender, context.attacker, rules, attack.attack_id, 0, attack.tags)
	EffectControllerScript.dispatch(EffectData.Trigger.ON_DAMAGED, defender, context.attacker, rules, attack.attack_id, 0, attack.tags)
	if defender.state == FighterController.State.KNOCK_DOWN: EffectControllerScript.dispatch(EffectData.Trigger.ON_KNOCK_DOWN, defender, context.attacker, rules, attack.attack_id, 0, attack.tags)
	if defender.state == FighterController.State.DEAD: EffectControllerScript.dispatch(EffectData.Trigger.ON_KILL, context.attacker, defender, rules, attack.attack_id, 0, attack.tags)
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
		var direction := context.source_position - context.target_position
		return Vector2(context.source_facing, 0) if direction.is_zero_approx() else direction.normalized()
	if attack.launch_mode == AttackData.LaunchMode.AWAY_FROM_SOURCE:
		var direction := context.target_position - context.source_position
		return Vector2(context.source_facing, 0) if direction.is_zero_approx() else direction.normalized()
	var result := attack.launch_vector
	if attack.input_direction == AttackData.InputDirection.OMNI:
		match context.source_direction:
			CombatIntent.Direction.UP: result = Vector2(0.2, -1.0)
			CombatIntent.Direction.DOWN: result = Vector2(0.2, 1.0)
	result.x *= context.source_facing
	return result.normalized()


static func resolve_equipment(attacker: FighterController, defender: FighterController, ability: AccessoryAbilityData) -> HitResult:
	var result := HitResult.new()
	if attacker == null or defender == null or attacker == defender or ability == null: return result
	if defender.state in [FighterController.State.SPAWNING, FighterController.State.FALLING_OUT, FighterController.State.RING_OUT, FighterController.State.DEAD, FighterController.State.MATCH_ENDED, FighterController.State.KNOCK_DOWN, FighterController.State.WAKE_UP] or defender.landing_down_ticks > 0: return result
	if defender.invulnerability_ticks > 0 or defender.wakeup_protection_ticks > 0 or _has_rule(defender.runtime_profile, CombatRuleData.Kind.IMMUNE_TAG, ability.tags):
		result.type = HitResult.Type.IMMUNE
		return result
	if defender.runtime_state.guarding:
		result.type = HitResult.Type.BLOCK
		return result
	if _has_rule(defender.runtime_profile, CombatRuleData.Kind.SUPER_ARMOR, ability.tags) or _has_rule(defender.runtime_profile, CombatRuleData.Kind.IMMUNE_HITSTUN, ability.tags):
		result.type = HitResult.Type.IMMUNE
		return result
	result.type = HitResult.Type.HIT
	result.hitstun_ticks = ability.stun_ticks
	result.reaction = &"LIGHT_STAGGER"
	defender.apply_equipment_stun(ability.stun_ticks)
	return result
