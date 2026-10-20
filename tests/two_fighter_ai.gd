extends SceneTree
var failures: Array[String] = []
var replay_hashes: Array[String] = []
func _initialize() -> void:
	Engine.time_scale = 10
	Engine.physics_ticks_per_second = 600
	Engine.max_physics_steps_per_frame = 64
	var index := 0
	for first: StringName in [&"ja-hyun",&"nabi"]:
		for second: StringName in [&"ja-hyun",&"nabi"]:
			await run_case(first,second,7200 + index, 1 if index == 0 else 0)
			index += 1
	await run_case(&"ja-hyun",&"ja-hyun",7200,2)
	Engine.time_scale = 1
	Engine.physics_ticks_per_second = 60
	for failure: String in failures: push_error(failure)
	print("TWO_FIGHTER_AI: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
func run_case(first: StringName, second: StringName, seed_value: int, replay := 0) -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	var controller: MatchController = scene.get_node("MatchController")
	controller.set_physics_process(false)
	controller.rules = (load("res://assets/combat/two_fighter_combat_rules.tres") as CombatRules).duplicate(true)
	controller.loadout_catalog = LocalPlayCatalog.new().combat
	var ids: Array[StringName] = [first,second]
	for index: int in 2:
		var selection := LoadoutSelection.new()
		selection.character_id = ids[index]
		if index == 0: controller.player_selection = selection
		else: controller.training_dummy_selection = selection
	root.add_child(scene)
	await process_frame
	controller.set_physics_process(false)
	controller.player.spawn_position = Vector2(430,572)
	controller.training_dummy.spawn_position = Vector2(850,572)
	controller.reset_match()
	var sources: Array[LocalAICommandSource] = []
	for fighter: FighterController in [controller.player,controller.training_dummy]:
		var reach := 105.0
		for attack: AttackData in fighter.runtime_profile.move_set.attacks():
			if attack.action_id == &"attack_heavy" and attack.activation_context == AttackData.ActivationContext.GROUND: reach = maxf(reach,attack.hitbox_offset.x + attack.hitbox_size.x * 0.5)
		sources.append(LocalAICommandSource.new(fighter.fighter_id,seed_value+sources.size(),{"simplified_combat":true,"heavy_range":reach,"stage_data":controller.stage_data}))
	var progress_tick := 0
	var previous_health := health(controller)
	for tick: int in 18000:
		await physics_frame
		if tick == 0 and not is_equal_approx(controller.get_physics_process_delta_time(),1.0/60): failures.append("acceleration changed actual combat delta")
		var observation := controller.snapshot()
		for source: LocalAICommandSource in sources:
			for command: CombatIntent in source.commands_for_tick(controller.tick+1,observation):
				if command.action_id in [&"ultimate",&"dash",&"evade"] or (command.action_id == &"attack_heavy" and command.edge == CombatIntent.Edge.RELEASE): failures.append("removed command emitted in live AI match")
				controller.submit_intent(command)
		controller.step_fixed_tick(false)
		if replay == 1: replay_hashes.append(controller.snapshot_hash())
		elif replay == 2 and (tick >= replay_hashes.size() or replay_hashes[tick] != controller.snapshot_hash()):
			failures.append("whole simplified match replay diverged at %d" % controller.tick)
			break
		var current := health(controller)
		if current != previous_health:
			progress_tick = controller.tick
			previous_health = current
		if not controller.winner_id.is_empty() or controller.is_draw: break
		if controller.tick - progress_tick > 1800:
			failures.append("%s/%s failed 30-second progress limit at tick %d" % [first,second,controller.tick])
			break
	if controller.winner_id.is_empty() and not controller.is_draw: failures.append("%s/%s did not finish in five minutes" % [first,second])
	var winner_character := first if controller.winner_id == controller.player.fighter_id else (second if controller.winner_id == controller.training_dummy.fighter_id else &"draw")
	print("TWO_FIGHTER_AI_MATCH: %s/%s tick=%d winner_character=%s" % [first,second,controller.tick,winner_character])
	if replay == 2 and controller.tick != replay_hashes.size(): failures.append("whole match replay length mismatch")
	scene.queue_free()
	await process_frame
func health(controller: MatchController) -> String:
	return "%s:%s:%s:%s" % [controller.player.current_hp,controller.player.stocks,controller.training_dummy.current_hp,controller.training_dummy.stocks]
