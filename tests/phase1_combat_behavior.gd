extends SceneTree


func _initialize() -> void:
	var failures: PackedStringArray = []
	var instance := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(instance)
	await physics_frame
	await physics_frame
	var controller := instance.get_node("MatchController") as MatchController
	controller.set_physics_process(false)
	var fighter := controller.player
	controller.reset_match()
	for index: int in 30: fighter.step_tick(controller.rules)

	# Ground acceleration and dash lock use CharacterStats and fixed ticks.
	fighter.consume_intent(_intent(fighter, &"move", CombatIntent.Direction.RIGHT, CombatIntent.Edge.PRESS), controller.rules)
	for index: int in 5: fighter.step_tick(controller.rules)
	if fighter.velocity.x <= 0.0 or fighter.velocity.x > fighter.character_data.base_stats.ground_speed: failures.append("ground acceleration contract failed")
	fighter.consume_intent(_intent(fighter, &"dash", CombatIntent.Direction.RIGHT), controller.rules)
	var dash_velocity := fighter.velocity.x
	fighter.consume_intent(_intent(fighter, &"move", CombatIntent.Direction.LEFT, CombatIntent.Edge.PRESS), controller.rules)
	fighter.step_tick(controller.rules)
	if fighter.state != FighterController.State.DASH or fighter.velocity.x != dash_velocity: failures.append("dash direction was not locked")

	# Ground heavy holds a locked direction, then releases a runtime-only charged copy.
	controller.reset_match()
	for index: int in 30: fighter.step_tick(controller.rules)
	fighter.consume_intent(_intent(fighter, &"attack_heavy", CombatIntent.Direction.RIGHT), controller.rules)
	var charge_source: AttackData = fighter.charge_attack
	if fighter.state != FighterController.State.CHARGE or charge_source == null: failures.append("ground heavy did not enter charge")
	fighter.consume_intent(_intent(fighter, &"move", CombatIntent.Direction.LEFT), controller.rules)
	for index: int in 12: fighter.step_tick(controller.rules)
	fighter.consume_intent(_intent(fighter, &"attack_heavy", CombatIntent.Direction.LEFT, CombatIntent.Edge.RELEASE), controller.rules)
	if fighter.active_attack == null or fighter.active_attack.damage <= charge_source.damage or fighter.locked_direction != CombatIntent.Direction.RIGHT: failures.append("charged heavy did not preserve direction and increase runtime values")
	if charge_source.damage != _find_attack(fighter, &"attack_heavy", AttackData.InputDirection.ANY_HORIZONTAL).damage: failures.append("charge mutated authored attack data")

	# Startup/active/recovery and a single whiff light buffer.
	controller.reset_match()
	for index: int in 30: fighter.step_tick(controller.rules)
	fighter.consume_intent(_intent(fighter, &"attack_light", CombatIntent.Direction.NEUTRAL), controller.rules)
	if fighter.state != FighterController.State.ATTACK_STARTUP: failures.append("light did not enter startup")
	for index: int in 4: fighter.step_tick(controller.rules)
	if fighter.state != FighterController.State.ATTACK_ACTIVE: failures.append("light startup tick count mismatch")
	for index: int in 3: fighter.step_tick(controller.rules)
	if fighter.state != FighterController.State.ATTACK_RECOVERY: failures.append("light active tick count mismatch")
	fighter.consume_intent(_intent(fighter, &"attack_light", CombatIntent.Direction.NEUTRAL), controller.rules)
	fighter.consume_intent(_intent(fighter, &"attack_heavy", CombatIntent.Direction.RIGHT), controller.rules)
	if fighter.buffered_intent == null or fighter.buffered_intent.action_id != &"attack_light": failures.append("single whiff light buffer contract failed")
	for index: int in 7: fighter.step_tick(controller.rules)
	if fighter.active_attack == null or fighter.active_attack.attack_id != &"ja-hyun-light-02": failures.append("buffered light did not advance data combo")

	# Hit-only branch and launcher chase permission.
	controller.reset_match()
	for index: int in 30: fighter.step_tick(controller.rules)
	var up_heavy := _find_attack(fighter, &"attack_heavy", AttackData.InputDirection.UP)
	fighter.call("_start_attack", up_heavy, CombatIntent.Direction.UP)
	fighter.state = FighterController.State.ATTACK_RECOVERY
	fighter.attack_phase_tick = 0
	fighter.register_landed_hit(up_heavy)
	fighter.consume_intent(_intent(fighter, &"jump", CombatIntent.Direction.UP), controller.rules)
	if fighter.active_attack != null or fighter.state != FighterController.State.JUMP or fighter.launcher_jump_available: failures.append("up-heavy chase jump permission failed")

	# Five directional aerial inputs share one authored OMNI attack and obey the two-use limit.
	fighter.global_position = Vector2(640, 250)
	fighter.step_tick(controller.rules)
	fighter.state = FighterController.State.FALL
	fighter.active_attack = null
	fighter.aerial_attacks_remaining = 2
	for direction: CombatIntent.Direction in [CombatIntent.Direction.NEUTRAL, CombatIntent.Direction.LEFT, CombatIntent.Direction.RIGHT, CombatIntent.Direction.UP, CombatIntent.Direction.DOWN]:
		var selected: AttackData = fighter.call("_select_attack", _intent(fighter, &"attack_light", direction, CombatIntent.Edge.PRESS, CombatIntent.Context.AIR))
		if selected == null or selected.input_direction != AttackData.InputDirection.OMNI: failures.append("missing aerial direction %d" % direction)
	fighter.aerial_attacks_remaining = 0
	if fighter.call("_select_attack", _intent(fighter, &"attack_heavy", CombatIntent.Direction.DOWN, CombatIntent.Edge.PRESS, CombatIntent.Context.AIR)) != null: failures.append("aerial attack limit was not enforced")

	# Every authored directional special starts, while the aerial recovery special
	# remains once per airtime.
	fighter.aerial_attacks_remaining = 2
	fighter.up_special_available = true
	fighter.consume_intent(_intent(fighter, &"attack_special", CombatIntent.Direction.UP, CombatIntent.Edge.PRESS, CombatIntent.Context.AIR), controller.rules)
	if fighter.up_special_available or fighter.velocity.y > -400.0: failures.append("up-special use or self impulse failed")
	fighter.active_attack = null
	fighter.state = FighterController.State.FALL
	fighter.consume_intent(_intent(fighter, &"attack_special", CombatIntent.Direction.UP, CombatIntent.Edge.PRESS, CombatIntent.Context.AIR), controller.rules)
	if fighter.active_attack != null: failures.append("second airborne up special was accepted")
	fighter.runtime_state.special_cooldown_ticks = 0
	fighter.consume_intent(_intent(fighter, &"attack_special", CombatIntent.Direction.DOWN, CombatIntent.Edge.PRESS, CombatIntent.Context.AIR), controller.rules)
	if fighter.active_attack == null or fighter.active_attack.input_direction != AttackData.InputDirection.DOWN: failures.append("down special did not start from data")

	# A filled gauge starts the authored ultimate and only then consumes its stock use.
	fighter.active_attack = null
	fighter.state = FighterController.State.IDLE
	fighter.runtime_state.ultimate_gauge = controller.rules.ultimate_gauge_max
	fighter.runtime_state.ultimate_used_this_stock = false
	fighter.consume_intent(_intent(fighter, &"ultimate", CombatIntent.Direction.NEUTRAL), controller.rules)
	if fighter.active_attack == null or fighter.active_attack.action_id != &"ultimate" or not fighter.runtime_state.ultimate_used_this_stock: failures.append("authored ultimate did not start")

	instance.queue_free()
	if failures.is_empty():
		print("PHASE1_COMBAT_BEHAVIOR: PASS")
		quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("PHASE1_COMBAT_BEHAVIOR: FAIL (%d)" % failures.size())
		quit(1)


func _intent(fighter: FighterController, action: StringName, direction: CombatIntent.Direction, edge := CombatIntent.Edge.PRESS, context := CombatIntent.Context.GROUND) -> CombatIntent:
	return CombatIntent.new(0, fighter.fighter_id, action, direction, edge, context)


func _find_attack(fighter: FighterController, action: StringName, direction: AttackData.InputDirection) -> AttackData:
	for attack: AttackData in fighter.attacks:
		if attack.action_id == action and attack.input_direction == direction and not attack.requires_dash: return attack
	return null
