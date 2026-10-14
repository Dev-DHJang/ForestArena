extends SceneTree

const Bot = preload("res://scripts/local_ai_command_source.gd")
var failures: PackedStringArray = []


func _initialize() -> void:
	test_tactics_and_targets()
	var bot := Bot.new(&"opponent", 45)
	var actor := {"id": "opponent", "position": Vector2(850, 550), "velocity": Vector2.ZERO, "state": "IDLE", "on_floor": true, "air_jumps": 1, "up_special": true, "special_cooldown_ticks": 0}
	var player := {"id": "player", "position": Vector2(430, 550), "state": "IDLE"}
	var view := {"fighters": [player, actor], "ultimate_gauge_max": 100.0}
	var before := JSON.stringify(view)
	var commands := bot.commands_for_tick(1, view)
	check(has_command(commands, &"move", CombatIntent.Direction.LEFT), "AI must approach target")
	check(bot.commands_for_tick(2, view).is_empty(), "normal reaction interval must not act every tick")
	check(JSON.stringify(view) == before, "bot must not mutate snapshot")
	actor.position = Vector2(-430, 630)
	actor.velocity = Vector2(0, 90)
	actor.on_floor = false
	bot.reset()
	commands = bot.commands_for_tick(1, view)
	check(has_command(commands, &"move", CombatIntent.Direction.RIGHT), "left ledge recovery must steer inward")
	check(has_command(commands, &"jump"), "recovery must use available air jump")
	actor.air_jumps = 0
	bot.reset()
	commands = bot.commands_for_tick(1, view)
	check(has_command(commands, &"attack_special", CombatIntent.Direction.UP), "recovery must request UP special after jumps run out")
	actor.special_cooldown_ticks = 80
	bot.reset()
	check(not has_command(bot.commands_for_tick(1, view), &"attack_special"), "cooldown recovery must not request special")
	actor.position = Vector2(-110, 550)
	actor.on_floor = true
	player.position = Vector2(-110, 410)
	bot.reset()
	check(has_command(bot.commands_for_tick(1, view), &"jump"), "AI must pursue target on upper platform")
	actor.position = Vector2(-110, 410)
	player.position = Vector2(-110, 550)
	bot.reset()
	commands = bot.commands_for_tick(1, view)
	check(has_command(commands, &"move", CombatIntent.Direction.DOWN) and has_command(commands, &"jump", CombatIntent.Direction.DOWN), "AI must use DOWN+jump to leave platform")
	actor.position = Vector2(660, 550)
	player.position = Vector2(620, 550)
	actor.special_cooldown_ticks = 0
	actor.ultimate_gauge = 100.0
	bot.reset()
	check(has_command(bot.commands_for_tick(1, view), &"ultimate", CombatIntent.Direction.NEUTRAL), "full gauge must use the authored neutral ultimate slot")
	actor.ultimate_gauge = 0.0
	var clone := Bot.new(&"opponent", 45)
	bot.reset()
	var heavy_pending := false
	var saw_heavy := false
	for tick: int in range(1, 601):
		commands = bot.commands_for_tick(tick, view)
		check(signature(commands) == signature(clone.commands_for_tick(tick, view)), "same snapshot/seed/tick must reproduce commands")
		for command: CombatIntent in commands:
			check(command.fighter_id == &"opponent", "AI may not send player commands")
			if command.action_id == &"attack_heavy":
				if command.edge == CombatIntent.Edge.PRESS:
					heavy_pending = true
					saw_heavy = true
				elif command.edge == CombatIntent.Edge.RELEASE:
					check(heavy_pending, "heavy release must follow a press")
					heavy_pending = false
					check(commands.size() == 1, "heavy release cannot be displaced by another action")
	check(saw_heavy, "normal AI must exercise charge attacks")
	var scene := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var match_controller := scene.get_node("MatchController") as MatchController
	match_controller.set_physics_process(false)
	var stage: StageData = match_controller.stage_data
	check(stage.is_valid_definition() and stage.main_floor().rect.size.x == 2160.0, "expanded stage contract is missing")
	check(stage.surfaces.size() == 5, "stage must contain one ground and four varied platforms")
	for surface: StageSurfaceData in stage.surfaces:
		if surface != stage.main_floor(): check(surface.one_way, "upper platform must be one-way")
	match_controller.bot_source = Bot.new(match_controller.training_dummy.fighter_id, 42)
	match_controller.reset_match()
	for tick: int in range(120):
		await physics_frame
		match_controller.step_fixed_tick(false)
	check(match_controller.training_dummy.global_position.x < 1100.0, "match must consume bot intents and move toward player")
	for surface: StageSurfaceData in stage.surfaces:
		if not surface.one_way: continue
		match_controller.reset_match()
		match_controller.player.global_position = Vector2(surface.rect.get_center().x, surface.rect.position.y - 14.0)
		match_controller.player.velocity = Vector2.ZERO
		match_controller.training_dummy.global_position = Vector2(surface.rect.get_center().x, 550)
		match_controller.training_dummy.velocity = Vector2.ZERO
		var reached_upper := false
		var trace: Array[String] = []
		for tick: int in range(600):
			await physics_frame
			match_controller.step_fixed_tick(false)
			if tick % 60 == 0:
				trace.append("%d:%s floor=%s" % [tick, match_controller.training_dummy.global_position, match_controller.training_dummy.is_on_floor()])
			if match_controller.training_dummy.is_on_floor() and absf(match_controller.training_dummy.global_position.y + match_controller.training_dummy.ground_contact_offset_y() - surface.rect.position.y) < 3.0:
				reached_upper = true
				break
		check(reached_upper, "AI must reach stage surface %s using normal jump physics (trace=%s)" % [surface.surface_id, trace])
	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("LOCAL_AI_BEHAVIOR: PASS")
		quit(0)
	else:
		for failure: String in failures: push_error(failure)
		quit(1)


func test_tactics_and_targets() -> void:
	var actor := {"id": "bot", "position": Vector2(500, 572), "velocity": Vector2.ZERO, "state": "IDLE", "on_floor": true, "stocks": 3, "air_jumps": 1, "special_cooldown_ticks": 0}
	var target := {"id": "a", "position": Vector2(560, 572), "state": "IDLE", "stocks": 3}
	var challenger := {"id": "b", "position": Vector2(700, 572), "state": "IDLE", "stocks": 3}
	var bot := Bot.new(&"bot", 810)
	check(bot.reaction_interval_ticks == 18 and LocalMatchConfig.new().reaction_interval_ticks == 18, "bot and live match config must both use 18-tick reactions")
	var view := {"fighters": [actor, target, challenger]}
	bot.commands_for_tick(1, view)
	check(bot._target_id == &"a", "AI must pick nearest valid enemy")
	challenger.position = Vector2(510, 572)
	bot.commands_for_tick(90, view)
	check(bot._target_id == &"a", "closer enemy must not replace target within 90 ticks")
	bot.commands_for_tick(91, view)
	check(bot._target_id == &"b", "AI must reconsider target after 90 ticks")
	challenger.state = "DEAD"
	bot.commands_for_tick(92, view)
	check(bot._target_id == &"a", "dead target must be replaced immediately between reactions")
	target.stocks = 0
	bot.commands_for_tick(93, view)
	check(bot._target_id.is_empty(), "zero-stock target must never be selected")
	target.stocks = 3
	target.team_id = "A"
	challenger.state = "IDLE"
	challenger.team_id = "B"
	var team_bot := Bot.new(&"bot", 810, {"team_id": &"A"})
	team_bot.commands_for_tick(1, view)
	check(team_bot._target_id == &"b", "team AI must exclude teammates")
	# A held heavy always emits its release, even if the only enemy disappears.
	team_bot._heavy_release_tick = 2
	challenger.stocks = 0
	var released := team_bot.commands_for_tick(2, view)
	check(released.size() == 1 and released[0].action_id == &"attack_heavy" and released[0].edge == CombatIntent.Edge.RELEASE, "target removal must not leave heavy held")
	actor.position = Vector2(-430, 630)
	actor.on_floor = false
	team_bot.reset()
	var recovery := team_bot.commands_for_tick(1, view)
	check(has_command(recovery, &"move", CombatIntent.Direction.RIGHT) and has_command(recovery, &"jump"), "ledge recovery must continue while all opponents are unavailable")
	actor.position = Vector2(500, 572)
	actor.on_floor = true
	view.fighters = [actor, target]
	target.position = Vector2(540, 572)
	bot.reset()
	var observed: Dictionary = {}
	var actions: Dictionary = {}
	for tick: int in range(1, 3601):
		var commands := bot.commands_for_tick(tick, view)
		if not commands.is_empty():
			observed[bot._tactic] = true
			for command: CombatIntent in commands:
				if command.edge == CombatIntent.Edge.PRESS: actions[command.action_id] = true
	for tactic: int in Bot.Tactic.values(): check(observed.has(tactic), "normal AI must exercise tactic %s" % Bot.Tactic.keys()[tactic])
	for action: StringName in [&"jump", &"attack_light", &"attack_heavy", &"attack_special"]:
		check(actions.has(action), "normal AI must exercise %s" % action)
	var saw_guard := false
	var saw_evade := false
	target.state = "ATTACK_STARTUP"
	for seed_value: int in range(1, 25):
		var defender := Bot.new(&"bot", seed_value)
		var commands := defender.commands_for_tick(1, view)
		saw_guard = saw_guard or has_command(commands, &"move", CombatIntent.Direction.DOWN)
		saw_evade = saw_evade or has_command(commands, &"evade")
	check(saw_guard and saw_evade, "visible startup must elicit both guard and evade across seeds")
	target.state = "ATTACK_RECOVERY"
	bot.reset()
	check(has_command(bot.commands_for_tick(1, view), &"attack_light") or bot._heavy_release_tick > 0, "recovery opening must trigger a counterattack")
	# Retreat stays inside the actual supporting upper platform, not just the main floor.
	check(not bot._safe_retreat(Vector2(140, 366), CombatIntent.Direction.LEFT), "retreat cannot walk off upper-platform left edge")
	check(not bot._safe_retreat(Vector2(520, 366), CombatIntent.Direction.RIGHT), "retreat cannot walk off upper-platform right edge")
	check(bot._safe_retreat(Vector2(330, 366), CombatIntent.Direction.LEFT), "retreat may use safe platform interior")
	target.state = "IDLE"
	target.position = Vector2(530, 572)
	bot.reset()
	bot._target_id = &"a"
	bot._target_until_tick = 90
	bot._tactic = Bot.Tactic.KEEP_DISTANCE
	bot._tactic_until_tick = 72
	var spacing := bot.commands_for_tick(1, view)
	check(has_command(spacing, &"move", CombatIntent.Direction.LEFT) and not has_command(spacing, &"attack_light"), "distance tactic must back away when too close instead of attack overriding movement")
	# An interrupted climb cannot redirect a later unrelated jump after landing.
	bot._climb_surface = bot.stage_data.surfaces[1]
	bot._next_reaction_tick = 2
	bot.commands_for_tick(2, view)
	check(bot._climb_surface == null, "landing on any floor must clear an old climb destination")
	# Resets restore the entire decision/RNG state, including target and pending charge.
	target.state = "IDLE"
	bot.reset()
	var clone := Bot.new(&"bot", 810)
	for tick: int in range(1, 301):
		check(signature(bot.commands_for_tick(tick, view)) == signature(clone.commands_for_tick(tick, view)), "reset must reproduce tactics and target decisions")


func has_command(commands: Array[CombatIntent], action: StringName, direction: int = -1) -> bool:
	for command: CombatIntent in commands:
		if command.action_id == action and (direction < 0 or command.direction == direction): return true
	return false


func signature(commands: Array[CombatIntent]) -> String:
	var result: Array = []
	for command: CombatIntent in commands:
		result.append([command.tick, command.fighter_id, command.action_id, command.direction, command.edge, command.context])
	return JSON.stringify(result)


func check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message): failures.append(message)
