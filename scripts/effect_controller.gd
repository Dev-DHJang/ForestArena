class_name EffectController
extends RefCounted

const EffectData = preload("res://scripts/data/combat_effect_data.gd")

static func dispatch(trigger: int, owner: FighterController, other: FighterController, rules: CombatRules, cause_id: StringName = &"", chain_depth := 0) -> void:
	if owner == null or owner.runtime_profile == null: return
	for effect: Resource in owner.runtime_profile.combat_effects:
		if effect == null or not effect.has_method("is_valid_definition") or int(effect.get("trigger")) != trigger or chain_depth > int(effect.get("max_chain_depth")): continue
		match int(effect.get("kind")):
			EffectData.Kind.REVIVE:
				if trigger == EffectData.Trigger.ON_DEATH: owner.revive(rules, float(effect.get("amount")))
			EffectData.Kind.GAIN_ULTIMATE:
				owner.runtime_state.ultimate_gauge += float(effect.get("amount"))
			EffectData.Kind.REFLECT_DAMAGE, EffectData.Kind.EXPLOSION_DAMAGE:
				if other == null or other == owner or (not cause_id.is_empty() and cause_id == StringName(effect.get("cause_id"))): continue
				other.current_hp = maxf(0.0, other.current_hp - float(effect.get("amount")))
				if other.current_hp <= 0.0: other.lose_stock(rules)
