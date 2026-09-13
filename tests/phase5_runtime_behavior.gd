extends SceneTree

var failures: Array[String] = []
var catalog: LoadoutCatalog
var rules: CombatRules
var fighter: FighterController


func _initialize() -> void:
	catalog = load("res://assets/loadouts/default_loadout_catalog.tres")
	rules = load("res://assets/combat/phase1_combat_rules.tres")
	var instance := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(instance)
	await physics_frame
	await physics_frame
	var controller := instance.get_node("MatchController") as MatchController
	controller.set_physics_process(false)
	fighter = controller.player
	_test_cancel_boundaries()
	_test_jump_and_dash_cancel_targets()
	_test_passive_filters_and_single_activation()
	instance.queue_free()
	if failures.is_empty(): print("PHASE5_RUNTIME_BEHAVIOR: PASS")
	else: for failure: String in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _test_cancel_boundaries() -> void:
	_configure(&"ja-hyun", &"ja-hyun-ribbon-counter-prototype")
	var light := _attack(&"attack_light", AttackData.ActivationContext.GROUND, false, false)
	for boundary: int in [0, 4]:
		_prepare_recovery(light, AttackData.ActivationContext.GROUND, boundary)
		fighter.consume_intent(_intent(&"attack_heavy", CombatIntent.Direction.RIGHT), rules)
		_check(fighter.state == FighterController.State.ATTACK_STARTUP and fighter.active_attack.action_id == &"attack_heavy", "cancel boundary %d was rejected" % boundary)
	_prepare_recovery(light, AttackData.ActivationContext.GROUND, 5)
	fighter.consume_intent(_intent(&"attack_heavy", CombatIntent.Direction.RIGHT), rules)
	_check(fighter.active_attack == light and fighter.state == FighterController.State.ATTACK_RECOVERY, "cancel outside end boundary was accepted")
	_prepare_recovery(light, AttackData.ActivationContext.AIR, 0)
	fighter.consume_intent(_intent(&"attack_heavy", CombatIntent.Direction.RIGHT, CombatIntent.Context.AIR), rules)
	_check(fighter.active_attack == light, "cancel with wrong source context was accepted")
	var finisher := _attack(&"attack_heavy", AttackData.ActivationContext.GROUND, false, true)
	_prepare_recovery(finisher, AttackData.ActivationContext.GROUND, 0)
	fighter.consume_intent(_intent(&"attack_heavy", CombatIntent.Direction.RIGHT), rules)
	_check(fighter.active_attack == finisher, "finisher cancel was accepted")


func _test_jump_and_dash_cancel_targets() -> void:
	_configure(&"nabi", &"nabi-iron-pounce-prototype")
	var side_heavy := fighter.runtime_profile.move_set.attack_for_slot(&"nabi-heavy-side")
	_prepare_recovery(side_heavy, AttackData.ActivationContext.GROUND, 5)
	fighter.consume_intent(_intent(&"dash", CombatIntent.Direction.RIGHT), rules)
	_check(fighter.state == FighterController.State.DASH and fighter.active_attack == null, "iron pounce dash cancel did not activate")

	_configure(&"myo-ryung", &"myo-ryung-sky-dancer-prototype")
	fighter.global_position.y -= 160.0
	fighter.move_and_slide()
	var air_light := _attack(&"attack_light", AttackData.ActivationContext.AIR, false, false)
	_prepare_recovery(air_light, AttackData.ActivationContext.AIR, 5)
	fighter.air_jumps_remaining = 1
	fighter.consume_intent(_intent(&"jump", CombatIntent.Direction.UP, CombatIntent.Context.AIR), rules)
	_check(fighter.state == FighterController.State.JUMP and fighter.active_attack == null, "sky dancer jump cancel did not activate")


func _test_passive_filters_and_single_activation() -> void:
	_configure(&"ja-hyun", &"ja-hyun-bulwark-prototype")
	var incoming := _attack(&"attack_light", AttackData.ActivationContext.GROUND, false, false)
	fighter.state = FighterController.State.GUARD
	fighter.guard_durability = fighter.runtime_profile.combat_tuning.guard_max_durability
	fighter.apply_guarded_hit(incoming, rules, incoming.damage, 10)
	_check(fighter.passive_pending_id == &"bulwark-next-heavy", "bulwark passive did not arm")
	var light := _attack(&"attack_light", AttackData.ActivationContext.GROUND, false, false)
	fighter.call("_start_attack", light, CombatIntent.Direction.NEUTRAL)
	_check(is_equal_approx(fighter.attack_damage_scale, 1.0) and not fighter.passive_pending_id.is_empty(), "bulwark passive was consumed by a light")
	fighter.active_attack = null
	var heavy := fighter.runtime_profile.move_set.attack_for_slot(&"ja-hyun-heavy-side")
	fighter.call("_start_attack", heavy, CombatIntent.Direction.RIGHT)
	_check(is_equal_approx(fighter.attack_damage_scale, 1.10) and fighter.passive_pending_id.is_empty(), "bulwark passive was not consumed by a heavy")

	_configure(&"myo-ryung", &"myo-ryung-gale-diver-prototype")
	var hit := _attack(&"attack_light", AttackData.ActivationContext.GROUND, false, false)
	fighter.active_attack = hit
	fighter.active_attack_context = AttackData.ActivationContext.GROUND
	fighter.activation_serial = 7
	fighter.special_cooldowns[&"special"] = 100
	fighter.register_landed_hit(hit)
	_check(int(fighter.special_cooldowns[&"special"]) == 88, "gale passive did not reduce special cooldown")
	fighter.passive_cooldowns[&"gale-diver-special-cooldown"] = 0
	fighter.register_landed_hit(hit)
	_check(int(fighter.special_cooldowns[&"special"]) == 88, "multi-hit activation triggered passive twice")
	fighter.reset_for_match(rules)
	_check(fighter.passive_cooldowns.is_empty() and fighter.passive_pending_id.is_empty(), "match reset retained passive runtime state")


func _configure(character_id: StringName, job_id: StringName) -> void:
	var selection := LoadoutSelection.new(); selection.character_id = character_id; selection.job_id = job_id
	var result := LoadoutBuilder.build(selection, catalog, rules.combat_tuning)
	_check(result.succeeded(), "runtime profile failed: %s" % job_id)
	fighter.fighter_id = character_id
	fighter.configure_profile(result.profile)
	fighter.reset_for_match(rules)
	for index: int in 30:
		fighter.step_tick(rules)


func _prepare_recovery(attack: AttackData, context: AttackData.ActivationContext, recovery_tick: int) -> void:
	fighter.active_attack = attack
	fighter.active_attack_context = context
	fighter.state = FighterController.State.ATTACK_RECOVERY
	fighter.attack_landed = true
	fighter.attack_phase_tick = recovery_tick
	fighter.buffered_intent = null


func _attack(action: StringName, context: AttackData.ActivationContext, requires_dash: bool, finisher: bool) -> AttackData:
	for attack: AttackData in fighter.attacks:
		if attack.action_id == action and attack.activation_context == context and attack.requires_dash == requires_dash and attack.is_finisher == finisher:
			return attack
	return null


func _intent(action: StringName, direction: CombatIntent.Direction, context := CombatIntent.Context.GROUND) -> CombatIntent:
	return CombatIntent.new(0, fighter.fighter_id, action, direction, CombatIntent.Edge.PRESS, context)


func _check(value: bool, message: String) -> void:
	if not value: failures.append(message)
