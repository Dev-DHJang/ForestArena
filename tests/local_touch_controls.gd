extends SceneTree

var failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var touch: Control = load("res://scripts/touch_command_source.gd").new()
	touch.extended_actions = true
	root.add_child(touch)
	await process_frame
	var viewport_size := touch.get_viewport_rect().size
	var right := viewport_size * Vector2(0.43, 0.7575)
	var left := viewport_size * Vector2(0.10, 0.7575)
	var down := viewport_size * Vector2(0.275, 0.91)
	var evade := center(touch, &"evade")
	var ultimate := center(touch, &"ultimate")
	for action: StringName in touch.ACTIONS:
		check(touch._action_for(center(touch, action)) == action, "visual center must hit %s" % action)
	for dead_region: Vector2 in [Vector2(0.49, 0.76), Vector2(0.3, 0.98), Vector2(0.6, 0.7), Vector2(0.73, 0.7), Vector2(0.85, 0.97), Vector2(0.98, 0.8)]:
		check(touch._action_for(viewport_size * dead_region).is_empty(), "dead region must not trigger action: %s" % dead_region)
	press(touch, 1, right)
	press(touch, 2, evade)
	check(Input.is_action_pressed(&"move_right") and Input.is_action_pressed(&"evade"), "direction and action must coexist")
	release(touch, 2, evade)
	check(Input.is_action_pressed(&"move_right") and not Input.is_action_pressed(&"evade"), "action release must preserve direction")
	press(touch, 2, ultimate)
	press(touch, 3, ultimate)
	release(touch, 2, ultimate)
	check(Input.is_action_pressed(&"ultimate"), "one finger release must preserve another ultimate touch")
	drag(touch, 3, Vector2.ZERO)
	check(not Input.is_action_pressed(&"ultimate"), "finger leaving button must release action")
	drag(touch, 1, left)
	check(Input.is_action_pressed(&"move_left") and not Input.is_action_pressed(&"move_right"), "pad drag must replace direction")
	press(touch, 2, evade)
	touch.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(touch._touch_actions.is_empty() and not Input.is_action_pressed(&"move_left") and not Input.is_action_pressed(&"evade"), "focus loss must release all fingers")
	press(touch, 1, down)
	press(touch, 2, ultimate)
	touch.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(not Input.is_action_pressed(&"move_down") and not Input.is_action_pressed(&"ultimate"), "app pause must clear input")
	var scene := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var controller := scene.get_node("MatchController") as MatchController
	controller.set_physics_process(false)
	controller.reset_match()
	for tick: int in 45:
		await physics_frame
		controller.step_fixed_tick(false)
	controller.player.facing = 1
	await process_frame
	press(touch, 1, left)
	press(touch, 2, evade)
	controller.step_fixed_tick()
	check(controller.player.state == FighterController.State.EVADE and controller.player.velocity.x < 0.0, "same tick LEFT+action must evade left even while previously facing right")
	controller.pause_match(true)
	touch.release_all_touches()
	check(controller.player.input_direction == CombatIntent.Direction.NEUTRAL and controller.player.buffered_intent == null, "pause must clear fighter input and pending attack")
	controller.pause_match(false)
	for tick: int in 20:
		await physics_frame
		controller.step_fixed_tick(false)
	await process_frame
	press(touch, 2, evade)
	controller.step_fixed_tick()
	check(controller.player.state not in [FighterController.State.EVADE, FighterController.State.GUARD], "neutral action must not guard or perform directional evade")
	touch.release_all_touches()
	for pad_position: Vector2 in [left, right, down, viewport_size * Vector2(0.275, 0.60)]:
		controller.reset_match()
		for tick: int in 45:
			await physics_frame
			controller.step_fixed_tick(false)
		controller.player.runtime_state.ultimate_gauge = controller.rules.ultimate_gauge_max
		await process_frame
		press(touch, 1, pad_position)
		press(touch, 2, ultimate)
		controller.step_fixed_tick()
		check(controller.player.active_attack != null and controller.player.active_attack.action_id == &"ultimate", "direction + ultimate touch must start the single ultimate slot")
		check(controller.player.runtime_state.ultimate_gauge == 0.0, "valid ultimate must spend gauge")
		touch.release_all_touches()
		await process_frame
	scene.queue_free()
	touch.queue_free()
	if failures.is_empty():
		print("LOCAL_TOUCH_CONTROLS: PASS")
		quit(0)
	else:
		for failure: String in failures: push_error(failure)
		quit(1)


func center(touch: Control, action: StringName) -> Vector2:
	var visual: Control = touch._action_visuals[action]
	return visual.position + visual.size * 0.5


func press(touch: Control, index: int, position: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = true
	touch.handle_pointer_event(event)


func release(touch: Control, index: int, position: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	touch.handle_pointer_event(event)


func drag(touch: Control, index: int, position: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = position
	touch.handle_pointer_event(event)


func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
