extends SceneTree

const Bot = preload("res://scripts/local_ai_command_source.gd")
const MAX_MATCH_TICKS := 18000 # Five minutes of actual 60 Hz gameplay.
const MAX_NO_DAMAGE_TICKS := 1800 # Thirty seconds without damage/stock progress.
var failures: PackedStringArray = []
var replay_hashes: Array[String] = []


func _initialize() -> void:
	# Both settings change together: CharacterBody2D still receives 1/60 delta.
	Engine.time_scale = 10.0
	Engine.physics_ticks_per_second = 600
	Engine.max_physics_steps_per_frame = 64
	var cases := [
		[&"ja-hyun", &"myo-ryung", Vector2(430, 520), Vector2(850, 520)],
		[&"myo-ryung", &"nabi", Vector2(430, 380), Vector2(850, 520)],
		[&"nabi", &"yu-ran", Vector2(100, 520), Vector2(850, 520)],
		[&"yu-ran", &"ja-hyun", Vector2(430, 520), Vector2(1180, 520)],
	]
	for index: int in cases.size():
		await run_case(cases[index], 9100 + index, 1 if index == 0 else 0)
	# Replay an entire match, including physics, bot RNG and stock resets.
	await run_case(cases[0], 9100, 2)
	var roster: Array[StringName] = [&"ja-hyun", &"myo-ryung", &"nabi", &"yu-ran"]
	for first: StringName in roster:
		for second: StringName in roster:
			if cases.any(func(item: Array) -> bool: return item[0] == first and item[1] == second): continue
			await run_case([first, second, Vector2(430, 520), Vector2(850, 520)], 9200 + roster.find(first) * 4 + roster.find(second))
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60
	if failures.is_empty():
		print("LOCAL_AI_SOAK: PASS")
		quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("LOCAL_AI_SOAK: FAIL (%d)" % failures.size())
		quit(1)


func run_case(test_case: Array, seed_value: int, replay_mode := 0) -> void:
	var scene := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	var controller := scene.get_node("MatchController") as MatchController
	controller.set_physics_process(false)
	root.add_child(scene)
	await process_frame
	controller.set_physics_process(false)
	var label := "%s/%s seed=%d" % [test_case[0], test_case[1], seed_value]
	var fighters: Array[FighterController] = [controller.player, controller.training_dummy]
	for index: int in 2:
		var selection := LoadoutSelection.new()
		selection.character_id = test_case[index]
		var built := LoadoutBuilder.build(selection, controller.loadout_catalog)
		if not built.succeeded() or not fighters[index].configure_profile(built.profile):
			failures.append("%s profile setup failed" % label)
			scene.queue_free()
			return
		fighters[index].spawn_position = test_case[index + 2]
	controller.bot_source = Bot.new(controller.training_dummy.fighter_id, seed_value + 1)
	controller.reset_match()
	var player_source := Bot.new(controller.player.fighter_id, seed_value)
	var last_progress := 0
	var previous_health := health_signature(controller)
	for ignored_tick: int in MAX_MATCH_TICKS:
		await physics_frame
		if ignored_tick == 0 and not is_equal_approx(controller.get_physics_process_delta_time(), 1.0 / 60.0):
			failures.append("%s accelerated test changed combat physics delta" % label)
			break
		# Exactly the next controller tick, using the same pre-step observation as
		# its internal opponent source; no actions are added after simulation.
		for command: CombatIntent in player_source.commands_for_tick(controller.tick + 1, controller.snapshot()):
			controller.submit_intent(command)
		controller.step_fixed_tick(false)
		if replay_mode == 1:
			replay_hashes.append(controller.snapshot_hash())
		elif replay_mode == 2:
			if ignored_tick >= replay_hashes.size() or controller.snapshot_hash() != replay_hashes[ignored_tick]:
				failures.append("%s replay snapshot diverged at tick %d" % [label, controller.tick])
				break
		var health := health_signature(controller)
		if health != previous_health:
			last_progress = controller.tick
			previous_health = health
		if not controller.winner_id.is_empty() or controller.is_draw: break
		if controller.tick - last_progress > MAX_NO_DAMAGE_TICKS:
			failures.append("%s no damage/stock progress for 30s: %s" % [label, controller.snapshot()])
			break
	if controller.winner_id.is_empty() and not controller.is_draw:
		failures.append("%s did not finish at tick %d" % [label, controller.tick])
	else:
		var winner_character := &"DRAW"
		for fighter: FighterController in fighters:
			if fighter.fighter_id == controller.winner_id: winner_character = fighter.runtime_profile.character_id
		print("LOCAL_AI_SOAK_MATCH: %s ticks=%d winner_character=%s draw=%s" % [label, controller.tick, winner_character, controller.is_draw])
	if replay_mode == 2 and controller.tick != replay_hashes.size():
		failures.append("%s replay length differs" % label)
	scene.queue_free()
	await process_frame


func health_signature(controller: MatchController) -> String:
	return "%s:%s:%s:%s" % [controller.player.current_hp, controller.player.stocks, controller.training_dummy.current_hp, controller.training_dummy.stocks]
