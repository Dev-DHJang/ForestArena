extends SceneTree

const Bot = preload("res://scripts/local_ai_command_source.gd")
var failures: PackedStringArray = []


func _initialize() -> void:
	var bot := Bot.new(&"opponent", 45)
	var actor := {"id": "opponent", "position": Vector2(850, 550), "velocity": Vector2.ZERO, "state": "IDLE", "on_floor": true, "air_jumps": 1, "up_special": true, "special_cooldown_ticks": 0}
	var player := {"id": "player", "position": Vector2(430, 550), "state": "IDLE"}
	var view := {"fighters": [player, actor], "ultimate_gauge_max": 100.0}
	var before := JSON.stringify(view)
	var commands := bot.commands_for_tick(1, view)
	check(has_command(commands, &"move", CombatIntent.Direction.LEFT), "AI must approach target")
	check(bot.commands_for_tick(2, view).is_empty(), "normal reaction interval must not act every tick")
	check(JSON.stringify(view) == before, "bot must not mutate snapshot")
	actor.position = Vector2(80, 630)
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
	actor.position = Vector2(640, 550)
	actor.on_floor = true
	player.position = Vector2(640, 380)
	bot.reset()
	check(has_command(bot.commands_for_tick(1, view), &"jump"), "AI must pursue target on upper platform")
	actor.position = Vector2(640, 380)
	player.position = Vector2(640, 550)
	bot.reset()
	commands = bot.commands_for_tick(1, view)
	check(has_command(commands, &"move", CombatIntent.Direction.DOWN) and has_command(commands, &"jump", CombatIntent.Direction.DOWN), "AI must use DOWN+jump to leave platform")
	actor.position = Vector2(660, 550)
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
	var floor_shape: RectangleShape2D = scene.get_node("World/Ground/CollisionShape2D").shape
	var upper: CollisionShape2D = scene.get_node("World/Platform/CollisionShape2D")
	check(floor_shape.size.x == 1080.0 and upper.shape.size.x == 540.0, "platform must be half the 1080 ground")
	check(upper.one_way_collision, "upper platform must be one-way")
	check(scene.get_node("World/Ground").position.x == scene.get_node("World/Platform").position.x, "platform must be centered")
	match_controller.bot_source = Bot.new(match_controller.training_dummy.fighter_id, 42)
	match_controller.reset_match()
	for tick: int in range(120):
		await physics_frame
		match_controller.step_fixed_tick(false)
	check(match_controller.training_dummy.global_position.x < 820.0, "match must consume bot intents and move toward player")
	match_controller.reset_match()
	match_controller.player.global_position = Vector2(640, 380)
	match_controller.training_dummy.global_position = Vector2(780, 550)
	var reached_upper := false
	for tick: int in range(240):
		await physics_frame
		match_controller.step_fixed_tick(false)
		if match_controller.training_dummy.is_on_floor() and match_controller.training_dummy.global_position.y < 430.0:
			reached_upper = true
	check(reached_upper, "AI must actually reach upper platform using normal jump physics")
	scene.queue_free()
	if failures.is_empty():
		print("LOCAL_AI_BEHAVIOR: PASS")
		quit(0)
	else:
		for failure: String in failures: push_error(failure)
		quit(1)


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
