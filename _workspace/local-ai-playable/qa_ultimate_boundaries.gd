extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	if not condition: failures.append(label)

func run() -> void:
	var commands: Array[CombatIntent] = [
		CombatIntent.new(1, &"player", &"move", CombatIntent.Direction.DOWN, CombatIntent.Edge.PRESS, CombatIntent.Context.GROUND),
		CombatIntent.new(1, &"player", &"jump", CombatIntent.Direction.DOWN, CombatIntent.Edge.PRESS, CombatIntent.Context.GROUND),
		CombatIntent.new(1, &"player", &"ultimate", CombatIntent.Direction.NEUTRAL, CombatIntent.Edge.PRESS, CombatIntent.Context.GROUND),
	]
	var resolved := CommandResolver.resolve(commands)
	check(resolved.any(func(intent: CombatIntent) -> bool: return intent.action_id == &"drop_platform"), "DOWN+jump must retain platform drop priority")
	check(not resolved.any(func(intent: CombatIntent) -> bool: return intent.action_id in [&"ultimate", &"guard", &"jump"]), "drop must exclude other action")
	var scene := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var controller := scene.get_node("MatchController") as MatchController
	controller.set_physics_process(false)
	for direction: StringName in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		controller.reset_match()
		for tick: int in 45:
			await physics_frame
			controller.step_fixed_tick(false)
		controller.player.runtime_state.ultimate_gauge = controller.rules.ultimate_gauge_max - 1.0
		await process_frame
		Input.action_press(direction)
		Input.action_press(&"ultimate")
		controller.step_fixed_tick()
		check(controller.player.active_attack == null, "insufficient gauge rejects ultimate " + direction)
		check(controller.player.runtime_state.ultimate_gauge == controller.rules.ultimate_gauge_max - 1.0, "rejected ultimate preserves gauge " + direction)
		check(not controller.player.runtime_state.ultimate_used_this_stock, "rejected ultimate preserves stock use " + direction)
		Input.action_release(direction)
		Input.action_release(&"ultimate")
		await process_frame
	scene.queue_free()
	for failure: String in failures: push_error(failure)
	print("QA_ULTIMATE_BOUNDARIES: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
