extends SceneTree

var failures: PackedStringArray = []


func _initialize() -> void:
	var instance := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(instance)
	await physics_frame
	await physics_frame
	var controller := instance.get_node("MatchController") as MatchController
	controller.set_physics_process(false)
	_test_v2_contract(controller)
	_test_archetype_resources(controller)
	_test_grab_charge_special_ultimate(controller)
	_test_bot_and_telemetry(controller)
	instance.queue_free()
	if failures.is_empty():
		print("PHASE3_COMBAT_ARCHETYPES: PASS")
		quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("PHASE3_COMBAT_ARCHETYPES: FAIL (%d)" % failures.size())
		quit(1)


func _test_v2_contract(controller: MatchController) -> void:
	_check(controller.rules.schema_version == 2 and controller.rules.is_valid_definition(), "CombatRules v2 invalid")
	var old_attack := AttackData.new()
	old_attack.schema_version = 1
	old_attack.attack_id = &"old"
	old_attack.action_id = &"attack_light"
	old_attack.visual_state_id = &"old"
	_check(not old_attack.is_valid_definition(), "AttackData v1 was not rejected")
	var old_job := JobData.new()
	old_job.schema_version = 1
	old_job.job_id = &"old"
	_check(not old_job.is_valid_definition(), "JobData v1 was not rejected")


func _test_archetype_resources(controller: MatchController) -> void:
	var catalog := controller.loadout_catalog
	var cases := [
		[&"ja-hyun", &"ja-hyun-guard-prototype", &"guard_max_durability"],
		[&"myo-ryung", &"myo-ryung-aerial-prototype", &"aerial_special_impulse_multiplier"],
		[&"nabi", &"nabi-grapple-prototype", &"grab_startup_ticks"],
	]
	for item: Array in cases:
		var base_selection := LoadoutSelection.new()
		base_selection.character_id = item[0]
		var job_selection := LoadoutSelection.new()
		job_selection.character_id = item[0]
		job_selection.job_id = item[1]
		var base_result := LoadoutBuilder.build(base_selection, catalog, controller.rules.combat_tuning)
		var job_result := LoadoutBuilder.build(job_selection, catalog, controller.rules.combat_tuning)
		_check(base_result.succeeded() and job_result.succeeded(), "archetype loadout failed: %s" % item[1])
		if not base_result.succeeded() or not job_result.succeeded(): continue
		_check(base_result.profile.combat_tuning.get(item[2]) != job_result.profile.combat_tuning.get(item[2]), "job tuning did not change specialty: %s" % item[1])
		_check(controller.rules.combat_tuning.get(item[2]) == base_result.profile.combat_tuning.get(item[2]), "loadout mutated source tuning: %s" % item[1])
		var attacks := base_result.profile.move_set.attacks()
		_check(_find(attacks, &"attack_special", AttackData.InputDirection.ANY_HORIZONTAL) != null, "missing side special: %s" % item[0])
		_check(_find(attacks, &"attack_special", AttackData.InputDirection.DOWN) != null, "missing down special: %s" % item[0])
		_check(attacks.filter(func(a: AttackData) -> bool: return a.is_grab()).size() == 3, "directional grabs incomplete: %s" % item[0])
		_check(attacks.filter(func(a: AttackData) -> bool: return a.is_ultimate()).size() == 2, "ultimate capture/followup incomplete: %s" % item[0])


func _test_grab_charge_special_ultimate(controller: MatchController) -> void:
	controller.reset_match()
	var fighter := controller.player
	for index: int in 30: fighter.step_tick(controller.rules)
	var tuning := fighter.runtime_profile.combat_tuning

	# Guard release creates the only valid neutral-grab window.
	fighter.consume_intent(_intent(fighter, &"dash", CombatIntent.Direction.NEUTRAL, CombatIntent.Edge.PRESS), controller.rules)
	for index: int in tuning.guard_hold_delay_ticks: fighter.step_tick(controller.rules)
	fighter.consume_intent(_intent(fighter, &"dash", CombatIntent.Direction.NEUTRAL, CombatIntent.Edge.RELEASE), controller.rules)
	_check(fighter.grab_grace_ticks == tuning.grab_release_window_ticks, "guard release did not open grab window")
	fighter.consume_intent(_intent(fighter, &"grab_support", CombatIntent.Direction.NEUTRAL, CombatIntent.Edge.PRESS), controller.rules)
	_check(fighter.active_attack != null and fighter.active_attack.is_grab(), "neutral grab did not select forward throw")

	# Ground heavy releases at maximum data-authored scale and locks direction.
	controller.reset_match()
	for index: int in 30: fighter.step_tick(controller.rules)
	fighter.consume_intent(_intent(fighter, &"attack_heavy", CombatIntent.Direction.RIGHT, CombatIntent.Edge.PRESS), controller.rules)
	for index: int in tuning.charge_max_ticks: fighter.step_tick(controller.rules)
	fighter.consume_intent(_intent(fighter, &"attack_heavy", CombatIntent.Direction.LEFT, CombatIntent.Edge.RELEASE), controller.rules)
	_check(fighter.active_attack != null and fighter.locked_direction == CombatIntent.Direction.RIGHT, "charge did not lock press direction")
	_check(is_equal_approx(fighter.attack_damage_scale, 1.6) and is_equal_approx(fighter.attack_knockback_scale, 1.6), "maximum charge scale drifted")

	# All special directions share one cooldown group.
	controller.reset_match()
	for index: int in 30: fighter.step_tick(controller.rules)
	fighter.consume_intent(_intent(fighter, &"attack_special", CombatIntent.Direction.NEUTRAL, CombatIntent.Edge.PRESS), controller.rules)
	_check(not fighter.special_cooldowns.is_empty(), "special did not start shared cooldown")
	fighter.active_attack = null
	fighter.state = FighterController.State.IDLE
	fighter.consume_intent(_intent(fighter, &"attack_special", CombatIntent.Direction.DOWN, CombatIntent.Edge.PRESS), controller.rules)
	_check(fighter.active_attack == null and fighter.diagnostic == "special_cooldown_active", "shared special cooldown did not reject direction")

	# Ultimate spends on activation and only a valid capture schedules followup.
	controller.reset_match()
	for index: int in 30: fighter.step_tick(controller.rules)
	fighter.ultimate_gauge = tuning.ultimate_max_gauge
	fighter.consume_intent(_intent(fighter, &"ultimate", CombatIntent.Direction.NEUTRAL, CombatIntent.Edge.PRESS), controller.rules)
	_check(fighter.ultimate_used and fighter.ultimate_gauge == 0.0 and fighter.active_attack != null, "ultimate did not spend on activation")
	var capture := fighter.active_attack
	fighter.register_landed_hit(capture)
	fighter.state = FighterController.State.ATTACK_ACTIVE
	fighter.attack_phase_tick = capture.active_ticks - 1
	fighter.step_tick(controller.rules)
	_check(fighter.active_attack != null and fighter.active_attack.ultimate_followup, "valid ultimate capture did not start followup")
	fighter.ring_out(controller.rules)
	_check(not fighter.ultimate_used and fighter.ultimate_gauge == 0.0, "stock loss did not reset ultimate")


func _test_bot_and_telemetry(controller: MatchController) -> void:
	var profile := load("res://assets/combat/bots/spacing_profile.tres") as BotCommandProfile
	var source := DeterministicBotCommandSource.new(profile, 77, controller.training_dummy.fighter_id, controller.player.fighter_id)
	var first := _intent_signature(source.commands_for_tick(120, controller.snapshot()))
	var second := _intent_signature(source.commands_for_tick(120, controller.snapshot()))
	_check(first == second, "bot commands changed for identical seed/snapshot/tick")
	var telemetry := Phase3PlaytestTelemetry.new()
	_check(telemetry.begin_match(&"contract", 77, [{"slot": &"player", "character_id": &"ja-hyun"}, {"slot": &"dummy", "character_id": &"myo-ryung", "bot_profile_id": &"spacing"}]), "telemetry match did not begin")
	telemetry.record_action(&"attack_light")
	telemetry.record_grab(true)
	var aggregate := telemetry.aggregate_snapshot()
	_check(int(aggregate.aggregates.action_counts.attack_light) == 1 and int(aggregate.aggregates.grab.successes) == 1, "telemetry aggregate drifted")
	telemetry.cancel_match()


func _find(attacks: Array[AttackData], action: StringName, direction: AttackData.InputDirection) -> AttackData:
	for attack: AttackData in attacks:
		if attack.action_id == action and attack.input_direction == direction and not attack.ultimate_followup:
			return attack
	return null


func _intent(fighter: FighterController, action: StringName, direction: CombatIntent.Direction, edge: CombatIntent.Edge) -> CombatIntent:
	return CombatIntent.new(0, fighter.fighter_id, action, direction, edge, CombatIntent.Context.GROUND)


func _intent_signature(intents: Array[CombatIntent]) -> String:
	var values: Array[String] = []
	for intent: CombatIntent in intents:
		values.append("%s:%d:%d:%d" % [intent.action_id, intent.direction, intent.edge, intent.context])
	return "|".join(values)


func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
