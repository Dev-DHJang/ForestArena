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
	controller.reset_match()
	for index: int in 30:
		player.step_tick(controller.rules)
		_dummy_step(dummy, controller.rules)
	if not controller.rules.is_valid_definition() or controller.rules.schema_version != 2:
		failures.append("CombatRules v2 definition is invalid")
	if controller.rules.guard_max_durability != 100.0 or controller.rules.evade_speed != 480.0:
		failures.append("Phase 3 tuning defaults drifted")

	# Neutral action guards, drains, blocks normal attacks, and cleanly releases.
	player.consume_intent(_intent(player, &"dash", CombatIntent.Direction.NEUTRAL, CombatIntent.Edge.PRESS), controller.rules)
	if player.state != FighterController.State.GUARD:
		failures.append("neutral action did not enter guard")
	var before_hold := player.guard_durability
	player.step_tick(controller.rules)
	if not is_equal_approx(player.guard_durability, before_hold - controller.rules.guard_hold_drain_per_tick):
		failures.append("guard hold drain mismatch")
	player.global_position = Vector2(640, 520)
	dummy.global_position = Vector2(680, 520)
	dummy.active_attack = dummy.attacks[0]
	dummy.state = FighterController.State.ATTACK_ACTIVE
	dummy.locked_facing = -1
	dummy.activation_serial += 1
	var before_guard_hit := player.guard_durability
	controller.call("_resolve_hits")
	if player.damage_percent != 0.0 or player.state != FighterController.State.GUARD:
		failures.append("guarded normal hit dealt damage or knockback")
	if not is_equal_approx(player.guard_durability, before_guard_hit - dummy.active_attack.damage * controller.rules.guard_hit_drain_damage_multiplier):
		failures.append("guard hit durability cost mismatch")
	player.consume_intent(_intent(player, &"dash", CombatIntent.Direction.NEUTRAL, CombatIntent.Edge.RELEASE), controller.rules)
	player.step_tick(controller.rules)
	if player.state == FighterController.State.GUARD:
		failures.append("guard release remained locked")

	# Guard break blocks re-entry until its fixed recovery completes.
	controller.reset_match()
	for index: int in 30: player.step_tick(controller.rules)
	player.consume_intent(_intent(player, &"dash", CombatIntent.Direction.NEUTRAL), controller.rules)
	player.guard_durability = dummy.attacks[0].damage * controller.rules.guard_hit_drain_damage_multiplier
	player.apply_guarded_hit(dummy.attacks[0], controller.rules)
	if player.state != FighterController.State.GUARD_BREAK:
		failures.append("empty guard did not break")
	player.consume_intent(_intent(player, &"dash", CombatIntent.Direction.NEUTRAL), controller.rules)
	if player.state != FighterController.State.GUARD_BREAK:
		failures.append("guard re-entered during guard break")
	for index: int in controller.rules.guard_break_ticks: player.step_tick(controller.rules)
	if player.state == FighterController.State.GUARD_BREAK or player.guard_durability != controller.rules.guard_max_durability:
		failures.append("guard break recovery mismatch")

	# Side action evades with a lock, then holding it becomes the legacy dash.
	controller.reset_match()
	for index: int in 30: player.step_tick(controller.rules)
	player.consume_intent(_intent(player, &"dash", CombatIntent.Direction.RIGHT), controller.rules)
	player.consume_intent(_intent(player, &"dash", CombatIntent.Direction.RIGHT, CombatIntent.Edge.HOLD), controller.rules)
	if player.state != FighterController.State.EVADE_GROUND or player.invulnerability_ticks != controller.rules.evade_invulnerability_ticks:
		failures.append("ground evade did not initialize")
	player.consume_intent(_intent(player, &"move", CombatIntent.Direction.LEFT), controller.rules)
	for index: int in controller.rules.ground_evade_ticks: player.step_tick(controller.rules)
	if player.state != FighterController.State.DASH or player.velocity.x <= 0.0:
		failures.append("held side action did not become locked dash")

	# One aerial evade is available per airtime and landing restores it.
	controller.reset_match()
	player.global_position = Vector2(640, 250)
	player.state = FighterController.State.FALL
	player.aerial_evades_remaining = 1
	player.consume_intent(_intent(player, &"dash", CombatIntent.Direction.LEFT), controller.rules)
	if player.state != FighterController.State.EVADE_AIR or player.aerial_evades_remaining != 0:
		failures.append("air evade availability mismatch")
	player.consume_intent(_intent(player, &"dash", CombatIntent.Direction.RIGHT), controller.rules)
	if player.evade_direction != -1:
		failures.append("second aerial evade replaced the first")

	# Every stable base character can build a default profile without job/accessory patches.
	for fighter_scene_path: String in ["res://scenes/fighters/ja_hyun_fighter.tscn", "res://scenes/fighters/myo_ryung_fighter.tscn", "res://scenes/fighters/nabi_fighter.tscn"]:
		var fighter := (load(fighter_scene_path) as PackedScene).instantiate() as FighterController
		var selection := LoadoutSelection.new()
		selection.character_id = fighter.fighter_id
		var result := LoadoutBuilder.build(selection, controller.loadout_catalog)
		if not result.succeeded() or not fighter.configure_profile(result.profile):
			failures.append("base comparison profile failed: %s" % fighter.fighter_id)
		fighter.queue_free()
	for config_path: String in ["res://assets/combat/debug/ja_hyun_vs_myo_ryung.tres", "res://assets/combat/debug/myo_ryung_vs_nabi.tres", "res://assets/combat/debug/nabi_vs_ja_hyun.tres"]:
		var config := load(config_path) as Phase3DebugMatchConfig
		if config == null or not config.is_valid_definition():
			failures.append("debug comparison config failed: %s" % config_path)
	# The config is developer-only and swaps scenes before profile construction;
	# it never creates a saved selection or a release UI path.
	controller.phase3_debug_match = load("res://assets/combat/debug/nabi_vs_ja_hyun.tres") as Phase3DebugMatchConfig
	controller.call("_apply_phase3_debug_match")
	if controller.player.fighter_id != &"nabi" or controller.training_dummy.fighter_id != &"ja-hyun" or not controller.call("_configure_fighters"):
		failures.append("debug comparison config did not configure Nabi versus Ja-hyun")

	instance.queue_free()
	if failures.is_empty():
		print("PHASE3_DEFENSE_EVADE: PASS")
		quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("PHASE3_DEFENSE_EVADE: FAIL (%d)" % failures.size())
		quit(1)


func _intent(fighter: FighterController, action: StringName, direction: CombatIntent.Direction, edge := CombatIntent.Edge.PRESS) -> CombatIntent:
	return CombatIntent.new(0, fighter.fighter_id, action, direction, edge, CombatIntent.Context.GROUND)


func _dummy_step(fighter: FighterController, rules: CombatRules) -> void:
	fighter.step_tick(rules)
