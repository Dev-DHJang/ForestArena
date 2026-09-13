extends SceneTree

var failures: Array[String] = []
var catalog: LoadoutCatalog
var rules: CombatRules


func _initialize() -> void:
	catalog = load("res://assets/loadouts/default_loadout_catalog.tres")
	rules = load("res://assets/combat/phase1_combat_rules.tres")
	_test_schema_contracts()
	_test_leaf_profiles()
	_test_atomic_failures()
	await _test_immediate_heavy()
	if failures.is_empty(): print("PHASE5_JOB_GROWTH: PASS")
	else: for failure: String in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _test_schema_contracts() -> void:
	var old_tuning := CombatTuningData.new(); old_tuning.schema_version = 2
	_check(not old_tuning.is_valid_definition(), "CombatTuningData v2 was accepted")
	var old_passive := PassiveData.new(); old_passive.schema_version = 1; old_passive.passive_id = &"old"; old_passive.value = 1.0
	_check(not old_passive.is_valid_definition(), "PassiveData v1 was accepted")
	var old_cancel := CancelRuleData.new(); old_cancel.schema_version = 1; old_cancel.rule_id = &"old"; old_cancel.from_action_id = &"attack_light"; old_cancel.to_action_id = &"attack_heavy"
	_check(not old_cancel.is_valid_definition(), "CancelRuleData v1 was accepted")
	var old_job := JobData.new(); old_job.schema_version = 4; old_job.job_id = &"old"
	_check(not old_job.is_valid_definition(), "JobData v4 was accepted")
	var old_catalog := LoadoutCatalog.new(); old_catalog.schema_version = 2
	_check(not old_catalog.is_valid_definition(), "LoadoutCatalog v2 was accepted")
	var old_profile := RuntimeCombatProfile.new(); old_profile.schema_version = 4
	_check(not old_profile.is_valid_definition(), "RuntimeCombatProfile v4 was accepted")
	var tombstone := CombatTuningModifier.new(); tombstone.field = CombatTuningModifier.Field.DEPRECATED_CHARGE_MAX_TICKS
	_check(not tombstone.is_valid_definition(), "deprecated charge modifier tombstone was accepted")
	_check(CombatTuningModifier.Field.SPECIAL_COOLDOWN_TICKS == 9 and CombatTuningModifier.Field.AERIAL_SPECIAL_IMPULSE_MULTIPLIER == 10, "Phase 4 tuning field numbers changed")


func _test_leaf_profiles() -> void:
	var bulwark := _profile(&"ja-hyun", &"ja-hyun-bulwark-prototype")
	var guard_root := _profile(&"ja-hyun", &"ja-hyun-guard-prototype")
	_check(bulwark.job_chain_ids == [&"ja-hyun-guard-prototype", &"ja-hyun-bulwark-prototype"], "bulwark chain order changed")
	_check(is_equal_approx(bulwark.combat_tuning.guard_max_durability, guard_root.combat_tuning.guard_max_durability + 15.0), "bulwark guard maximum changed")
	_check(is_equal_approx(bulwark.combat_tuning.guard_regen_per_second, guard_root.combat_tuning.guard_regen_per_second + 3.0), "bulwark guard recovery changed")
	_check(not bulwark.move_set.attack_for_slot(&"ja-hyun-heavy-side").is_finisher, "bulwark heavy patch remains a finisher")
	_assert_passive(bulwark, &"bulwark-next-heavy", PassiveData.Trigger.ON_GUARDED_HIT, PassiveData.Effect.NEXT_ATTACK_DAMAGE_MULTIPLIER, 1.10, 120, 180)
	_assert_cancel(bulwark, &"bulwark-heavy-special", &"attack_heavy", AttackData.ActivationContext.GROUND, 0, 5, &"attack_special")
	var ribbon := _profile(&"ja-hyun", &"ja-hyun-ribbon-counter-prototype")
	_check(is_equal_approx(ribbon.stats.ground_speed, guard_root.stats.ground_speed + 12.0), "ribbon ground speed changed")
	_assert_passive(ribbon, &"ribbon-counter-next-attack", PassiveData.Trigger.ON_EVADE_END, PassiveData.Effect.NEXT_ATTACK_DAMAGE_MULTIPLIER, 1.08, 90, 150)
	_assert_cancel(ribbon, &"ribbon-light-heavy", &"attack_light", AttackData.ActivationContext.GROUND, 0, 4, &"attack_heavy")

	var aerial_root := _profile(&"myo-ryung", &"myo-ryung-aerial-prototype")
	var sky := _profile(&"myo-ryung", &"myo-ryung-sky-dancer-prototype")
	_check(is_equal_approx(sky.stats.air_speed, aerial_root.stats.air_speed + 25.0) and is_equal_approx(sky.stats.jump_velocity, aerial_root.stats.jump_velocity + 20.0), "sky dancer movement changed")
	_assert_passive(sky, &"sky-dancer-next-air-attack", PassiveData.Trigger.ON_EVADE_END, PassiveData.Effect.NEXT_ATTACK_DAMAGE_MULTIPLIER, 1.08, 90, 150)
	_check(sky.passives[0].trigger_context == AttackData.ActivationContext.AIR and sky.passives[0].consume_context == AttackData.ActivationContext.AIR, "sky dancer air filters changed")
	_assert_cancel(sky, &"sky-air-light-jump", &"attack_light", AttackData.ActivationContext.AIR, 0, 5, &"jump")
	var gale := _profile(&"myo-ryung", &"myo-ryung-gale-diver-prototype")
	var root_down := aerial_root.move_set.attack_for_slot(&"myo-ryung-special-down")
	var gale_down := gale.move_set.attack_for_slot(&"myo-ryung-special-down")
	_check(gale_down.startup_ticks == root_down.startup_ticks - 1 and is_equal_approx(gale_down.damage, root_down.damage + 1.0), "gale down-special patch changed")
	_check(not gale.move_set.attack_for_slot(&"myo-ryung-air-heavy").is_finisher, "gale air-heavy patch remains a finisher")
	_assert_passive(gale, &"gale-diver-special-cooldown", PassiveData.Trigger.ON_ATTACK_HIT, PassiveData.Effect.SPECIAL_COOLDOWN_REDUCTION, 12.0, 0, 60)
	_assert_cancel(gale, &"gale-air-heavy-special", &"attack_heavy", AttackData.ActivationContext.AIR, 0, 5, &"attack_special")

	var pressure_root := _profile(&"nabi", &"nabi-close-pressure-prototype")
	var rush := _profile(&"nabi", &"nabi-rushclaw-prototype")
	_check(is_equal_approx(rush.stats.dash_speed, pressure_root.stats.dash_speed + 30.0) and is_equal_approx(rush.stats.dash_duration_seconds, pressure_root.stats.dash_duration_seconds + 0.02), "rushclaw dash tuning changed")
	_assert_passive(rush, &"rushclaw-next-light", PassiveData.Trigger.ON_ATTACK_HIT, PassiveData.Effect.NEXT_ATTACK_DAMAGE_MULTIPLIER, 1.08, 90, 120)
	_check(rush.passives[0].requires_dash and rush.passives[0].consume_action_id == &"attack_light", "rushclaw passive filters changed")
	_assert_cancel(rush, &"rushclaw-dash-light-light", &"attack_light", AttackData.ActivationContext.GROUND, 0, 4, &"attack_light")
	_check(rush.cancel_rules[0].from_requires_dash, "rushclaw cancel lost dash filter")
	var iron := _profile(&"nabi", &"nabi-iron-pounce-prototype")
	_check(is_equal_approx(iron.stats.ground_speed, pressure_root.stats.ground_speed + 12.0), "iron pounce ground speed changed")
	for slot: StringName in [&"nabi-heavy-side", &"nabi-heavy-up", &"nabi-heavy-down", &"nabi-dash-heavy", &"nabi-air-heavy"]:
		var base_attack := pressure_root.move_set.attack_for_slot(slot)
		var patched_attack := iron.move_set.attack_for_slot(slot)
		_check(is_equal_approx(patched_attack.guard_damage_multiplier, base_attack.guard_damage_multiplier * 1.25), "iron guard damage changed: %s" % slot)
	_check(not iron.move_set.attack_for_slot(&"nabi-heavy-side").is_finisher and iron.move_set.attack_for_slot(&"nabi-heavy-up").is_finisher, "iron cancelable-heavy scope changed")
	_assert_passive(iron, &"iron-pounce-evade-cooldown", PassiveData.Trigger.ON_ATTACK_HIT, PassiveData.Effect.EVADE_COOLDOWN_REDUCTION, 6.0, 0, 90)
	_assert_cancel(iron, &"iron-heavy-dash", &"attack_heavy", AttackData.ActivationContext.GROUND, 0, 5, &"dash")


func _test_atomic_failures() -> void:
	var missing_catalog := catalog.duplicate(true) as LoadoutCatalog
	missing_catalog.passives = missing_catalog.passives.filter(func(passive: PassiveData) -> bool: return passive.passive_id != &"bulwark-next-heavy")
	var selection := _selection(&"ja-hyun", &"ja-hyun-bulwark-prototype")
	var missing_result := LoadoutBuilder.build(selection, missing_catalog, rules.combat_tuning)
	_check(not missing_result.succeeded() and missing_result.profile == null and missing_result.error_codes.has(LoadoutBuildResult.ERR_MISSING_PASSIVE), "missing passive did not fail atomically")
	var duplicate_catalog := catalog.duplicate(true) as LoadoutCatalog
	duplicate_catalog.job_by_id(&"ja-hyun-bulwark-prototype").added_passive_ids.append(&"bulwark-next-heavy")
	var duplicate_result := LoadoutBuilder.build(selection, duplicate_catalog, rules.combat_tuning)
	_check(not duplicate_result.succeeded() and duplicate_result.profile == null, "duplicate passive did not fail atomically")
	var cycle_catalog := catalog.duplicate(true) as LoadoutCatalog
	cycle_catalog.job_by_id(&"ja-hyun-guard-prototype").parent_job_id = &"ja-hyun-bulwark-prototype"
	var cycle_result := LoadoutBuilder.build(selection, cycle_catalog, rules.combat_tuning)
	_check(not cycle_result.succeeded() and cycle_result.profile == null, "job cycle did not fail atomically")


func _test_immediate_heavy() -> void:
	var instance := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(instance)
	await physics_frame
	var controller := instance.get_node("MatchController") as MatchController
	controller.set_physics_process(false)
	controller.reset_match()
	var fighter := controller.player
	fighter.consume_intent(CombatIntent.new(0, fighter.fighter_id, &"attack_heavy", CombatIntent.Direction.RIGHT, CombatIntent.Edge.PRESS, CombatIntent.Context.GROUND), controller.rules)
	_check(fighter.state == FighterController.State.ATTACK_STARTUP and fighter.active_attack != null, "heavy PRESS did not activate immediately")
	instance.queue_free()


func _profile(character_id: StringName, job_id: StringName) -> RuntimeCombatProfile:
	var result := LoadoutBuilder.build(_selection(character_id, job_id), catalog, rules.combat_tuning)
	_check(result.succeeded(), "profile failed: %s" % job_id)
	return result.profile


func _selection(character_id: StringName, job_id: StringName) -> LoadoutSelection:
	var selection := LoadoutSelection.new(); selection.character_id = character_id; selection.job_id = job_id
	return selection


func _assert_passive(profile: RuntimeCombatProfile, passive_id: StringName, trigger: PassiveData.Trigger, effect: PassiveData.Effect, value: float, duration: int, cooldown: int) -> void:
	var found: PassiveData
	for passive: PassiveData in profile.passives:
		if passive.passive_id == passive_id: found = passive
	_check(found != null, "passive missing: %s" % passive_id)
	if found != null: _check(found.trigger == trigger and found.effect == effect and is_equal_approx(found.value, value) and found.duration_ticks == duration and found.cooldown_ticks == cooldown, "passive tuning changed: %s" % passive_id)


func _assert_cancel(profile: RuntimeCombatProfile, rule_id: StringName, from_action: StringName, context: AttackData.ActivationContext, start: int, end: int, to_action: StringName) -> void:
	var found: CancelRuleData
	for rule: CancelRuleData in profile.cancel_rules:
		if rule.rule_id == rule_id: found = rule
	_check(found != null, "cancel missing: %s" % rule_id)
	if found != null: _check(found.from_action_id == from_action and found.from_context == context and found.recovery_start_tick == start and found.recovery_end_tick == end and found.to_action_id == to_action, "cancel contract changed: %s" % rule_id)


func _check(value: bool, message: String) -> void:
	if not value: failures.append(message)
