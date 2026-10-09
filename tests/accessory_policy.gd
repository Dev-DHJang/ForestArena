extends SceneTree

var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)

func _initialize() -> void:
	var local := LocalPlayCatalog.new()
	check(local.combat.characters.size() == 4 and local.combat.accessories.size() == 6, "catalog coverage")
	var stable_ids := ["fixture-iron-armor", "fixture-boxing-gloves", "fixture-thorns", "fixture-explosive-gloves", "fixture-ultimate-charm", "fixture-phoenix-revive"]
	for accessory: AccessoryData in local.combat.accessories:
		check(stable_ids.has(String(accessory.accessory_id)), "legacy owned ID retained")
		check(accessory.is_valid_definition(), "valid sidegrade " + String(accessory.accessory_id))
		check(accessory.combat_rules.is_empty(), "no permanent armor/immunity")
		var product := local.product(String(accessory.accessory_id))
		check(not product.description.contains("반사 피해") and not product.description.contains("추가 피해") and not product.name.contains("부활"), "no obsolete shop text")
		for modifier: StatModifier in accessory.stat_modifiers:
			check(modifier.operation == StatModifier.Operation.MULTIPLY and modifier.value >= 0.95 and modifier.value <= 1.05, "authored option limited to 5 percent")
			check(modifier.field != StatModifier.Field.MAX_HP and modifier.field != StatModifier.Field.AIR_JUMP_COUNT, "no extra HP or jump count")
		for effect: Resource in accessory.combat_effects:
			check(effect is CombatEffectData and effect.kind == CombatEffectData.Kind.GAIN_ULTIMATE and effect.amount <= 4.0, "no damage/revive and modest gauge option")
		for character: CharacterData in local.combat.characters:
			var original_stats := character.base_stats.duplicate(true) as CharacterStats
			var selection := LoadoutSelection.new()
			selection.character_id = character.character_id
			selection.accessory_id = accessory.accessory_id
			var built := LoadoutBuilder.build(selection, local.combat)
			check(built.succeeded(), "all character/accessory combinations")
			if not built.succeeded(): continue
			check(built.profile.stats.max_hp == original_stats.max_hp, "no accessory HP bonus")
			var owner := FighterController.new()
			var target := FighterController.new()
			owner.runtime_profile = built.profile
			target.runtime_profile = built.profile
			owner.current_hp = 20.0
			target.current_hp = 20.0
			owner.stocks = 0
			target.stocks = 1
			for trigger: int in CombatEffectData.Trigger.values():
				EffectController.dispatch(trigger, owner, target, CombatRules.new())
			check(owner.current_hp == 20.0 and target.current_hp == 20.0 and owner.stocks == 0, "all triggers leave HP/stocks unchanged")
			check(character.base_stats.ground_speed == original_stats.ground_speed and character.base_stats.weight == original_stats.weight, "source stats unchanged")
			owner.free()
			target.free()
	for kind: int in [CombatEffectData.Kind.REFLECT_DAMAGE, CombatEffectData.Kind.EXPLOSION_DAMAGE, CombatEffectData.Kind.REVIVE]:
		var forbidden := CombatEffectData.new()
		forbidden.kind = kind
		forbidden.cause_id = &"policy-forbidden"
		forbidden.amount = 3.0
		var accessory := AccessoryData.new()
		accessory.accessory_id = &"policy-invalid"
		accessory.combat_effects = [forbidden]
		check(not accessory.is_valid_definition(), "forbidden accessory effect rejected")
		var catalog := local.combat.duplicate(true) as LoadoutCatalog
		catalog.accessories.append(accessory)
		var selection := LoadoutSelection.new()
		selection.character_id = &"ja-hyun"
		selection.accessory_id = accessory.accessory_id
		check(not LoadoutBuilder.build(selection, catalog).succeeded(), "builder rejects forbidden legacy definition")
	for failure: String in failures: push_error(failure)
	print("ACCESSORY_POLICY: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
