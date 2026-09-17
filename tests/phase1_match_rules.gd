extends SceneTree


func _initialize() -> void:
	var failures: PackedStringArray = []
	var instance := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(instance)
	await process_frame
	var controller := instance.get_node("MatchController") as MatchController
	controller.set_physics_process(false)
	var player := controller.player
	var dummy := controller.training_dummy
	if not controller.rules.is_valid_definition(): failures.append("CombatRules contract is invalid")
	if controller.rules.physics_ticks_per_second != 60: failures.append("combat is not fixed at 60 Hz")

	# HP damage, fixed attack knockback/hitstun, and self-hit exclusion.
	controller.reset_match()
	player.global_position = Vector2(600, 520)
	dummy.global_position = Vector2(650, 520)
	player.active_attack = player.attacks[0]
	player.state = FighterController.State.ATTACK_ACTIVE
	player.locked_facing = 1
	player.activation_serial += 1
	dummy.input_direction = CombatIntent.Direction.RIGHT
	controller.call("_resolve_hits")
	var expected_speed := 120.0 / dummy.character_data.base_stats.weight
	if not is_equal_approx(dummy.current_hp, dummy.character_data.base_stats.max_hp - 4.0): failures.append("HP damage was not applied")
	if not is_equal_approx(dummy.velocity.length(), expected_speed): failures.append("knockback formula mismatch")
	if dummy.hitstun_ticks != clampi(roundi(6.0 / dummy.character_data.base_stats.weight), 6, 30): failures.append("fixed hitstun formula mismatch")
	if player.current_hp != player.character_data.base_stats.max_hp: failures.append("fighter hit itself")
	controller.call("_resolve_hits")
	if dummy.current_hp != dummy.character_data.base_stats.max_hp - 4.0: failures.append("single-hit attack hit the same target twice")

	# 45-tick respawn and 60-tick invulnerability.
	controller.reset_match()
	player.ring_out(controller.rules)
	for index: int in 44: player.step_tick(controller.rules)
	if player.state != FighterController.State.RING_OUT: failures.append("fighter respawned before tick 45")
	player.step_tick(controller.rules)
	if player.state == FighterController.State.RING_OUT or player.invulnerability_ticks != 60: failures.append("45/60 tick respawn contract failed")

	# Same-tick final losses are a draw, not sudden death.
	player.state = FighterController.State.IDLE
	dummy.state = FighterController.State.IDLE
	player.stocks = 1
	dummy.stocks = 1
	player.global_position = Vector2(controller.rules.ring_left - 1.0, 520)
	dummy.global_position = Vector2(controller.rules.ring_right + 1.0, 520)
	controller.call("_resolve_ring_outs")
	if not controller.is_draw: failures.append("simultaneous final ring-out was not a draw")
	controller.reset_match()
	player.state = FighterController.State.IDLE
	dummy.state = FighterController.State.IDLE
	player.stocks = 1
	player.global_position = Vector2(controller.rules.ring_left - 1.0, 520)
	dummy.global_position = Vector2(850, 520)
	controller.call("_resolve_ring_outs")
	if controller.winner_id != dummy.fighter_id: failures.append("single final ring-out did not select survivor")

	instance.queue_free()
	if failures.is_empty():
		print("PHASE1_MATCH_RULES: PASS")
		quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("PHASE1_MATCH_RULES: FAIL (%d)" % failures.size())
		quit(1)
