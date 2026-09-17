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

	# Up special is once per airtime; side/down specials are explicit no-ops.
	fighter.aerial_attacks_remaining = 2
	fighter.up_special_available = true
	fighter.consume_intent(_intent(fighter, &"attack_special", CombatIntent.Direction.UP, CombatIntent.Edge.PRESS, CombatIntent.Context.AIR), controller.rules)
	if fighter.up_special_available or fighter.velocity.y > -400.0: failures.append("up-special use or self impulse failed")
	fighter.active_attack = null
	fighter.state = FighterController.State.FALL
	fighter.consume_intent(_intent(fighter, &"attack_special", CombatIntent.Direction.UP, CombatIntent.Edge.PRESS, CombatIntent.Context.AIR), controller.rules)
	if fighter.active_attack != null: failures.append("second airborne up special was accepted")
	fighter.consume_intent(_intent(fighter, &"attack_special", CombatIntent.Direction.DOWN, CombatIntent.Edge.PRESS, CombatIntent.Context.AIR), controller.rules)
	if not fighter.diagnostic.contains("Phase 3"): failures.append("deferred special did not emit a no-op diagnostic")

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
