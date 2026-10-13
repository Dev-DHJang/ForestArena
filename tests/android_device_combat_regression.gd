extends SceneTree

var failures: PackedStringArray = []


func _initialize() -> void:
	var scene := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await physics_frame
	# This test advances hundreds of combat ticks in one headless frame. Silence
	# its presentation voices without writing the user's saved audio settings.
	root.get_node("ForestArenaAudio").call("set_levels", 0.0, 0.0, true, false)
	var controller := scene.get_node("MatchController") as MatchController
	controller.set_physics_process(false)
	var player := controller.player
	var target := controller.training_dummy
	_settle(controller)
	# A direction plus ordinary light is not a dash attack. Existing RUN momentum
	# must stop, while the held direction remains available after recovery.
	player.consume_intent(_intent(player, &"move", CombatIntent.Direction.RIGHT), controller.rules)
	for ignored: int in 5: player.step_tick(controller.rules)
	var start_x := player.global_position.x
	player.consume_intent(_intent(player, &"attack_light", CombatIntent.Direction.RIGHT), controller.rules)
	_check(player.active_attack != null and not player.active_attack.requires_dash, "ordinary directional light was rejected or selected a dash slot")
	for ignored: int in 30: player.step_tick(controller.rules)
	_check(is_equal_approx(start_x, player.global_position.x), "ordinary light retained RUN momentum: %.3f px" % (player.global_position.x - start_x))
	player.step_tick(controller.rules)
	_check(player.velocity.x > 0.0, "held direction did not resume after recovery")

	_settle(controller)
	player.consume_intent(_intent(player, &"move", CombatIntent.Direction.RIGHT), controller.rules)
	for ignored: int in 5: player.step_tick(controller.rules)
	start_x = player.global_position.x
	player.consume_intent(_intent(player, &"attack_heavy", CombatIntent.Direction.RIGHT), controller.rules)
	for ignored: int in 4: player.step_tick(controller.rules)
	_check(is_equal_approx(start_x, player.global_position.x), "ordinary heavy charge slid on the ground")

	_settle(controller)
	player.consume_intent(_intent(player, &"dash", CombatIntent.Direction.RIGHT), controller.rules)
	player.consume_intent(_intent(player, &"attack_light", CombatIntent.Direction.RIGHT), controller.rules)
	start_x = player.global_position.x
	player.step_tick(controller.rules)
	_check(player.active_attack != null and player.active_attack.requires_dash and player.global_position.x > start_x, "authored dash light lost its intentional advance")
	_settle(controller)
	player.consume_intent(_intent(player, &"dash", CombatIntent.Direction.RIGHT), controller.rules)
	player.consume_intent(_intent(player, &"attack_heavy", CombatIntent.Direction.RIGHT), controller.rules)
	_check(player.state == FighterController.State.CHARGE and is_zero_approx(player.velocity.x), "dash heavy did not stop and enter an ordinary charge")

	# Vertical light attacks are opening choices too; chained light stages are
	# never openings. Left/right chooses only the first combo facing.
	for direction: CombatIntent.Direction in [CombatIntent.Direction.UP, CombatIntent.Direction.DOWN]:
		_settle(controller)
		player.consume_intent(_intent(player, &"attack_light", direction), controller.rules)
		_check(player.active_attack != null and player.active_attack.input_direction == (AttackData.InputDirection.UP if direction == CombatIntent.Direction.UP else AttackData.InputDirection.DOWN), "vertical light was rejected as a non-opening")
	_settle(controller)
	player.facing = 1
	player.consume_intent(_intent(player, &"attack_light", CombatIntent.Direction.LEFT), controller.rules)
	_check(player.locked_facing == -1, "first left light did not choose its facing")
	for ignored: int in 10: player.step_tick(controller.rules)
	player.consume_intent(_intent(player, &"attack_light", CombatIntent.Direction.RIGHT), controller.rules)
	for ignored: int in 20: player.step_tick(controller.rules)
	_check(player.active_attack != null and player.active_attack.attack_id == &"ja-hyun-light-02" and player.locked_facing == -1, "a buffered combo stage reversed its first facing")

	# An effective hit locks every action until its data-driven stun expires. A
	# full ultimate gauge must not bypass that lock or consume a use while stunned.
	_settle(controller)
	var opening := _opening(player)
	target.apply_hit(opening, Vector2(110, -20), CombatMath.hitstun_ticks(opening, target._stats().weight, controller.rules), controller.rules)
	var expected_stun := target.hitstun_ticks
	target.runtime_state.ultimate_gauge = controller.rules.ultimate_gauge_max
	for action: StringName in [&"jump", &"dash", &"evade", &"drop_platform", &"attack_light", &"attack_heavy", &"attack_special", &"ultimate"]:
		target.consume_intent(_intent(target, action, CombatIntent.Direction.RIGHT), controller.rules)
	target.consume_intent(_intent(target, &"ultimate", CombatIntent.Direction.NEUTRAL), controller.rules)
	_check(target.state == FighterController.State.HITSTUN and target.active_attack == null and target.charge_attack == null, "an action escaped hitstun")
	_check(not target.runtime_state.ultimate_used_this_stock and target.runtime_state.ultimate_gauge == controller.rules.ultimate_gauge_max, "stunned ultimate consumed resources")
	for ignored: int in expected_stun - 1: target.step_tick(controller.rules)
	_check(target.state == FighterController.State.HITSTUN, "hitstun ended before its authored duration")
	target.step_tick(controller.rules)
	_check(target.state != FighterController.State.HITSTUN, "hitstun did not finish at its authored duration")

	# Real hit resolution and untouched attack data, at the closest non-overlapping
	# spacing. Three presses inside the documented window must reach all three
	# ja-hyun combo moves and land against a stationary practice opponent.
	_settle(controller)
	player.global_position = Vector2(600, 572)
	target.global_position = Vector2(655, 572)
	var hp_before := target.current_hp
	var total_damage := 0.0
	for attack: AttackData in player.attacks:
		if String(attack.visual_state_id).begins_with("attack_light_combo_"): total_damage += attack.damage
	player.consume_intent(_intent(player, &"attack_light", CombatIntent.Direction.RIGHT), controller.rules)
	var seen: Dictionary = {}
	for index: int in 100:
		if index in [10, 40]: controller.submit_intent(_intent(player, &"attack_light", CombatIntent.Direction.RIGHT))
		controller.step_fixed_tick(false)
		if player.active_attack != null: seen[player.active_attack.attack_id] = true
	_check(seen.has(&"ja-hyun-light-01") and seen.has(&"ja-hyun-light-02") and seen.has(&"ja-hyun-light-03"), "three presses did not execute three authored combo moves")
	_check(is_equal_approx(hp_before - target.current_hp, total_damage), "close-range practice combo did not land all hits: %.3f / %.3f" % [hp_before - target.current_hp, total_damage])
	# Neutral presses isolate knockback drift from the left/right opening bug.
	_settle(controller)
	player.global_position = Vector2(600, 572)
	target.global_position = Vector2(655, 572)
	hp_before = target.current_hp
	player.consume_intent(_intent(player, &"attack_light", CombatIntent.Direction.NEUTRAL), controller.rules)
	for index: int in 100:
		if index in [10, 40]: controller.submit_intent(_intent(player, &"attack_light", CombatIntent.Direction.NEUTRAL))
		controller.step_fixed_tick(false)
	_check(is_equal_approx(hp_before - target.current_hp, total_damage), "neutral practice combo drifted outside follow-up range: %.3f / %.3f" % [hp_before - target.current_hp, total_damage])
	_all_authored_combos(controller)

	# Eliminated participants remain eliminated across subsequent live match ticks.
	# This specifically exercises the 8-player Solo and 4v4 Team survivor paths.
	for mode: LocalMatchConfig.Mode in [LocalMatchConfig.Mode.SOLO, LocalMatchConfig.Mode.TEAM]:
		controller.additional_fighters.clear()
		controller.local_match_mode = mode
		controller.team_by_fighter_id = {player.fighter_id: &"alpha", target.fighter_id: &"beta"}
		for index: int in 6:
			var extra := FighterController.new()
			extra.fighter_id = StringName("regression-%d" % index)
			extra.character_data = player.character_data
			scene.get_node("World").add_child(extra)
			extra.configure_profile(player.runtime_profile)
			extra.spawn_position = Vector2(800 + index * 90, 572)
			controller.additional_fighters.append(extra)
			controller.team_by_fighter_id[extra.fighter_id] = &"alpha" if index < 3 else &"beta"
		controller.reset_match()
		player.stocks = 1
		player.lose_stock(controller.rules)
		for ignored: int in 10: controller.step_fixed_tick(false)
		_check(player.state == FighterController.State.DEAD and player.stocks == 0, "eliminated participant resumed movement in %s" % mode)
		player.ring_out(controller.rules)
		_check(player.stocks == 0, "eliminated participant lost a negative stock")
		for extra: FighterController in controller.additional_fighters:
			if mode == LocalMatchConfig.Mode.SOLO or controller.team_by_fighter_id[extra.fighter_id] == &"alpha":
				extra.stocks = 1
				extra.lose_stock(controller.rules)
		controller.step_fixed_tick(false)
		_check(controller.winner_id == target.fighter_id, "survivor result did not finish %s" % mode)
		if mode == LocalMatchConfig.Mode.TEAM: _check(controller.winner_team_id == &"beta", "Team did not publish the surviving team")
		for extra: FighterController in controller.additional_fighters: extra.queue_free()
	controller.additional_fighters.clear()
	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("ANDROID_DEVICE_COMBAT_REGRESSION: PASS")
		quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("ANDROID_DEVICE_COMBAT_REGRESSION: FAIL (%d)" % failures.size())
		quit(1)


func _settle(controller: MatchController) -> void:
	controller.reset_match()
	for ignored: int in 45:
		controller.player.step_tick(controller.rules)
		controller.training_dummy.step_tick(controller.rules)


func _intent(fighter: FighterController, action: StringName, direction: CombatIntent.Direction) -> CombatIntent:
	return CombatIntent.new(0, fighter.fighter_id, action, direction, CombatIntent.Edge.PRESS)


func _opening(fighter: FighterController) -> AttackData:
	for attack: AttackData in fighter.attacks:
		if attack.attack_id == &"ja-hyun-light-01": return attack
	return null


func _all_authored_combos(controller: MatchController) -> void:
	var player := controller.player
	var target := controller.training_dummy
	var original_character := player.character_data
	var original_profile := player.runtime_profile
	for character: CharacterData in controller.loadout_catalog.characters:
		var selection := LoadoutSelection.new()
		selection.character_id = character.character_id
		var result := LoadoutBuilder.build(selection, controller.loadout_catalog)
		_check(result.succeeded(), "authored character profile failed")
		if not result.succeeded(): continue
		player.character_data = character
		player.configure_profile(result.profile)
		var expected_damage := 0.0
		for attack: AttackData in player.attacks:
			if String(attack.visual_state_id).begins_with("attack_light_combo_"): expected_damage += attack.damage
		var hashes: Array[String] = []
		for repeat: int in 2:
			_settle(controller)
			player.global_position = Vector2(600, 572)
			target.global_position = Vector2(655, 572)
			var hp_before := target.current_hp
			player.consume_intent(_intent(player, &"attack_light", CombatIntent.Direction.RIGHT), controller.rules)
			var seen: Dictionary = {}
			var buffered_activations: Dictionary = {}
			for ignored: int in 150:
				if player.active_attack != null:
					seen[player.active_attack.attack_id] = true
					if not player.active_attack.is_finisher and player.state == FighterController.State.ATTACK_ACTIVE and player.attack_phase_tick == 2 and not buffered_activations.has(player.activation_serial):
						controller.submit_intent(_intent(player, &"attack_light", CombatIntent.Direction.RIGHT))
						buffered_activations[player.activation_serial] = true
				controller.step_fixed_tick(false)
			_check(seen.size() == player.runtime_profile.move_set.combo_count, "%s combo stage count: %s" % [character.character_id, seen.keys()])
			_check(is_equal_approx(hp_before - target.current_hp, expected_damage), "%s close-range combo hit damage: %.3f / %.3f" % [character.character_id, hp_before - target.current_hp, expected_damage])
			hashes.append(controller.snapshot_hash())
			print("ANDROID_DEVICE_COMBO: %s repeat=%d stages=%d damage=%.3f expected=%.3f hash=%s" % [character.character_id, repeat + 1, seen.size(), hp_before - target.current_hp, expected_damage, hashes[-1]])
		_check(hashes[0] == hashes[1], "%s combo changed with identical initial state and input ticks" % character.character_id)
	player.character_data = original_character
	player.configure_profile(original_profile)


func _check(value: bool, message: String) -> void:
	if not value: failures.append(message)
